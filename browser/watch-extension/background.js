const watchApi = globalThis.browser || globalThis.chrome
const family = watchApi.runtime.getManifest().browser_specific_settings ? 'firefox' : 'chromium'
const videoPattern = /^[A-Za-z0-9_-]{11}$/
let nativePort = null
let reconnectTimer = null
let lastCandidate = null
let nextPageId = 1000000
const pages = new Map()
const pendingPageCommands = new Map()

// The browser-owned port identifies an exact document even on Zen versions
// that omit sender.tab. No tab enumeration or extra browsing permission needed.
watchApi.runtime.onConnect.addListener(port => {
  if (port.name !== 'omadeck-watch-page') return
  const pageId = nextPageId++
  const sender = port.sender || {}
  pages.set(pageId, port)
  port.onMessage.addListener(message => {
    if (!message) return
    if (message.type === 'ack') {
      const pending = pendingPageCommands.get(message.requestId)
      if (pending && pending.pageId === pageId) pending.resolve(message)
      return
    }
    if (message.type !== 'candidate' || !senderMatchesVideo(sender, message.videoId)
        || !Number.isFinite(message.seconds) || message.seconds < 0 || message.seconds > 604800) return
    // Media selection survives focus and tab changes. A playing background
    // video can become the source, but an unrelated hidden paused page cannot.
    const retained = lastCandidate && lastCandidate.tabId === pageId
    if (!message.visible && !message.playing && !retained) return
    const publish = () => {
      if (!pages.has(pageId)) return
      lastCandidate = { type: 'candidate', tabId: pageId, videoId: message.videoId,
        seconds: message.seconds, playing: message.playing === true }
      post(lastCandidate)
    }
    if (!retained && !message.playing && Number.isInteger(sender.tab?.id)) {
      Promise.resolve(watchApi.tabs.query({ active: true, windowId: sender.tab.windowId }))
        .then(tabs => { if (tabs.some(tab => tab.id === sender.tab.id)) publish() })
        .catch(() => {})
    } else publish()
  })
  port.onDisconnect.addListener(() => {
    pages.delete(pageId)
    clearTab(pageId)
    // This exact document is gone even if another tab became the candidate.
    post({ type: 'sourceClosed', tabId: pageId })
    for (const pending of pendingPageCommands.values())
      if (pending.pageId === pageId) pending.resolve({ ok: false })
  })
})

function commandPage(port, message) {
  return new Promise(resolve => {
    const timer = setTimeout(() => finish({ ok: false }), 8000)
    function finish(result) {
      clearTimeout(timer)
      pendingPageCommands.delete(message.requestId)
      resolve(result)
    }
    pendingPageCommands.set(message.requestId, { pageId: message.tabId, resolve: finish })
    try { port.postMessage(message) } catch { finish({ ok: false }) }
  })
}

function senderMatchesVideo(sender, videoId) {
  try {
    const url = new URL(sender.url || '')
    return url.protocol === 'https:'
      && ['youtube.com', 'www.youtube.com', 'm.youtube.com'].includes(url.hostname)
      && url.pathname === '/watch' && url.searchParams.get('v') === videoId
  } catch { return false }
}

function post(message) {
  if (!nativePort) return
  try { nativePort.postMessage(message) } catch { scheduleReconnect() }
}

function scheduleReconnect() {
  nativePort = null
  if (reconnectTimer) return
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null
    connect()
  }, 2000)
}

async function handleNativeCommand(message) {
  if (!message || message.type !== 'command'
      || !['pause', 'resume'].includes(message.action)
      || !Number.isInteger(message.tabId) || message.tabId < 0
      || !Number.isInteger(message.requestId) || message.requestId < 0
      || !videoPattern.test(String(message.videoId || '')))
    return
  let ok = false
  let seconds = null
  try {
    const port = pages.get(message.tabId)
    if (!port && message.tabId >= 1000000 && message.tabId < nextPageId) throw new Error('Page closed')
    const response = port ? await commandPage(port, message)
      : await watchApi.tabs.sendMessage(message.tabId, message)
    ok = response && response.ok === true
    if (response && Number.isFinite(response.seconds) && response.seconds >= 0
        && response.seconds <= 604800) seconds = response.seconds
  } catch { /* Closed or navigated tab: fail without touching another one. */ }
  const reply = { type: 'ack', requestId: message.requestId, ok }
  if (seconds !== null) reply.seconds = seconds
  post(reply)
}

function connect() {
  try {
    const port = watchApi.runtime.connectNative('pretty.omadeck.watch')
    nativePort = port
    port.onMessage.addListener(handleNativeCommand)
    port.onDisconnect.addListener(() => {
      if (nativePort === port) scheduleReconnect()
    })
    post({ type: 'hello', browser: family })
    // Hidden pages can throttle their timers for much longer than three seconds.
    // A live document port retains selection across a shell/native-host restart;
    // the pause command revalidates the video and captures its actual timestamp.
    if (lastCandidate && pages.has(lastCandidate.tabId)) post(lastCandidate)
  } catch { scheduleReconnect() }
}

watchApi.runtime.onMessage.addListener((message, sender) => {
  if (!message || message.type !== 'candidate' || !sender || !sender.tab
      || !Number.isInteger(sender.tab.id)
      || !videoPattern.test(String(message.videoId || ''))
      || !senderMatchesVideo(sender, message.videoId))
    return
  const seconds = Number(message.seconds)
  if (!Number.isFinite(seconds) || seconds < 0 || seconds > 604800) return
  // Legacy reports follow the same media-selection rule as document ports.
  Promise.resolve(watchApi.tabs.query({ active: true })).then(tabs => {
    if (!message.playing && lastCandidate?.tabId !== sender.tab.id
        && !tabs.some(tab => tab.id === sender.tab.id)) return
    lastCandidate = { type: 'candidate', tabId: sender.tab.id,
      videoId: message.videoId, seconds, playing: message.playing === true }
    if (!nativePort && !reconnectTimer) connect()
    post(lastCandidate)
  }).catch(() => {})
})

function clearTab(tabId) {
  if (!lastCandidate || lastCandidate.tabId !== tabId) return
  lastCandidate = null
  post({ type: 'clear' })
}

function clearBrowserTab(tabId) {
  if (!lastCandidate) return
  const port = pages.get(lastCandidate.tabId)
  if ((port ? port.sender?.tab?.id : lastCandidate.tabId) === tabId)
    clearTab(lastCandidate.tabId)
}
watchApi.tabs.onRemoved.addListener(clearBrowserTab)
watchApi.tabs.onUpdated.addListener((tabId, change) => {
  if (change.url && lastCandidate && !senderMatchesVideo({ url: change.url }, lastCandidate.videoId))
    clearBrowserTab(tabId)
})

connect()
