// Runs only on YouTube watch pages. Page scripts cannot send these extension
// messages or receive the native host's tab-targeted commands.
const watchApi = globalThis.browser || globalThis.chrome
const videoPattern = /^[A-Za-z0-9_-]{11}$/
let lastReportAt = 0
let pagePort = null
let portVideoId = ''

function connectPage(videoId) {
  if (pagePort && portVideoId === videoId) return pagePort
  if (pagePort) pagePort.disconnect()
  const port = watchApi.runtime.connect({ name: 'omadeck-watch-page' })
  pagePort = port
  portVideoId = videoId
  port.onDisconnect.addListener(() => { if (pagePort === port) pagePort = null })
  port.onMessage.addListener(message => {
    applyCommand(message).then(result => {
      try { port.postMessage({ type: 'ack', requestId: message.requestId, ...result }) } catch {}
    })
  })
  return port
}

function currentVideoId() {
  try {
    const url = new URL(location.href)
    if (url.protocol !== 'https:'
        || !['youtube.com', 'www.youtube.com', 'm.youtube.com'].includes(url.hostname)
        || url.pathname !== '/watch') return ''
    const id = url.searchParams.get('v') || ''
    return videoPattern.test(id) ? id : ''
  } catch { return '' }
}

function currentVideo() {
  return document.querySelector('video.html5-main-video') || document.querySelector('video')
}

function reportCandidate(force = false) {
  if (!force && Date.now() - lastReportAt < 900) return
  const videoId = currentVideoId()
  const video = currentVideo()
  if (!videoId || !video) {
    if (pagePort) pagePort.disconnect()
    pagePort = null
    portVideoId = ''
    return
  }
  const seconds = Number(video.currentTime)
  if (!Number.isFinite(seconds) || seconds < 0 || seconds > 604800) return
  lastReportAt = Date.now()
  try {
    connectPage(videoId).postMessage({ type: 'candidate', videoId, seconds,
      playing: !video.paused && !video.ended, visible: document.visibilityState === 'visible' })
  } catch { pagePort = null }
}

async function applyCommand(message) {
  if (!message || message.type !== 'command'
      || currentVideoId() !== message.videoId) return { ok: false }
  const video = currentVideo()
  if (!video) return { ok: false }
  if (message.action === 'pause') {
    video.pause()
    reportCandidate(true)
    return { ok: video.paused, seconds: video.currentTime }
  }
  if (message.action === 'resume') {
    const seconds = Number(message.seconds)
    if (!Number.isFinite(seconds) || seconds < 0 || seconds > 604800)
      return { ok: false }
    let deadline
    let seekDone
    let cancelled = false
    const checkSource = () => {
      if (cancelled || currentVideoId() !== message.videoId || currentVideo() !== video)
        throw new Error('Video changed or Return expired')
    }
    try {
      await Promise.race([
        (async () => {
          // YouTube may restore its previous playhead as play() resolves.
          // Verify several settled samples, retrying the seek once if it jumps.
          for (let attempt = 0; attempt < 2; attempt++) {
            checkSource()
            video.pause()
            video.currentTime = seconds
            if (video.seeking) await new Promise(resolve => {
              seekDone = resolve
              video.addEventListener('seeked', resolve, { once: true })
            })
            checkSource()
            if (message.wasPlaying) await video.play()
            else video.pause()
            checkSource()
            const startedAt = Date.now()
            let stable = true
            for (let sample = 0; sample < 5; sample++) {
              await new Promise(resolve => setTimeout(resolve, 150))
              checkSource()
              const elapsed = message.wasPlaying ? (Date.now() - startedAt) / 1000 : 0
              const rate = Number(video.playbackRate) || 1
              if (video.seeking || video.paused === message.wasPlaying
                  || video.currentTime < seconds - 1
                  || video.currentTime > seconds + elapsed * rate + 2) {
                stable = false
                break
              }
            }
            if (stable) return
          }
          throw new Error('Browser did not retain the returned position')
        })(),
        new Promise((resolve, reject) => {
          deadline = setTimeout(() => reject(new Error('Playback timed out')), 6000)
        })
      ])
    } catch {
      video.pause()
      return { ok: false, seconds: video.currentTime }
    } finally {
      cancelled = true
      clearTimeout(deadline)
      if (seekDone) video.removeEventListener('seeked', seekDone)
    }
    reportCandidate(true)
    return { ok: true, seconds: video.currentTime }
  }
  return { ok: false }
}

watchApi.runtime.onMessage.addListener((message, sender, respond) => {
  if (!message || message.type !== 'command') return false
  applyCommand(message).then(respond, () => respond({ ok: false }))
  return true
})

document.addEventListener('play', () => reportCandidate(true), true)
document.addEventListener('pause', () => reportCandidate(true), true)
document.addEventListener('timeupdate', () => reportCandidate(), true)
document.addEventListener('seeked', () => reportCandidate(true), true)
document.addEventListener('yt-navigate-finish', () => reportCandidate(true), true)
document.addEventListener('visibilitychange', () => reportCandidate(true))
setInterval(reportCandidate, 2000)
reportCandidate()
