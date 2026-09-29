import QtQuick
import Quickshell
import Quickshell.Io
import "WatchSource.js" as WatchSource

Item {
  id: root

  property string pluginDir: ""
  property string targetScreen: ""
  property var media: null
  property var browserBridge: null
  property string state: "idle"
  property string notice: ""
  property var source: null
  property bool sourcePausedByUs: false
  property bool sourceClosed: false
  property bool focused: false
  property bool videoPlaying: false
  property real videoPosition: 0
  property real pendingSeekPosition: -1
  property real returnSeekTarget: -1
  property real videoDuration: 0
  property bool captionsEnabled: false
  property bool captionsAvailable: false
  property real lastReturnRequested: -1
  property real lastReturnConfirmed: -1
  property bool awaitingReturnSnapshot: false
  property bool returnSeekPending: false
  property bool returnResumeSent: false
  property int returnStableSamples: 0
  property var videoRect: ({ left: 0, top: 0, width: 0, height: 0 })
  property bool launchPending: false
  property bool closing: false
  property int pendingPauseRequest: -1
  property int pendingReturnRequest: -1
  property bool hostAvailable: false
  // Chi presents its own video (the original tab's player) in videoRect.
  property bool chiDeck: false
  readonly property var chi: browserBridge && browserBridge.chiBridge ? browserBridge.chiBridge : null
  readonly property bool shuttingDown: closing && hostProcess.running
  property string lastHostSocketPath: ""
  readonly property bool active: state === "launching" || state === "loading" || state === "pausing"
    || state === "playing" || state === "returning"
  readonly property string executable: pluginDir + "/native/bin/omadeck-watch-host"

  function refreshAvailability() {
    if (pluginDir) hostProbe.running = true
    else hostAvailable = false
  }

  function sourcePlayer() {
    if (!source || !media || typeof media.playerForKey !== "function") return null
    var player = media.playerForKey(source.sourceKey)
    if (!player) return null
    if (source.sourceKind === "extension")
      return browserBridge && browserBridge.connectedSource(source) ? player : null
    if (WatchSource.youtubeVideoId(player.metadata
        ? player.metadata["xesam:url"] : "") !== source.videoId) return null
    return player
  }

  // Chi places visible, hidden (shelved) and PiP tabs alike.
  function canPresentInChi(candidate) {
    return !!(candidate && candidate.browser === "chi" && chi && chi.connectedSource(candidate))
  }

  function begin(candidate, rectangle) {
    if (!active && !hostProcess.running && canPresentInChi(candidate)) return beginChiDeck(candidate, rectangle)
    return beginEmbedded(candidate, rectangle)
  }

  function beginEmbedded(candidate, rectangle) {
    if (active || hostProcess.running || !hostAvailable || !candidate || !rectangle || !media) return false
    var player = typeof media.playerForKey === "function"
      ? media.playerForKey(candidate.sourceKey) : null
    var extension = candidate.sourceKind === "extension"
    if (!player || (extension
        ? !browserBridge || !browserBridge.matches(candidate)
        : !player.metadata
          || WatchSource.youtubeVideoId(player.metadata["xesam:url"]) !== candidate.videoId
          || (candidate.sourceWasPlaying && !player.canPause))) return false
    var rect = {
      left: Math.floor(Number(rectangle.left)),
      top: Math.floor(Number(rectangle.top)),
      width: Math.floor(Number(rectangle.width)),
      height: Math.floor(Number(rectangle.height))
    }
    if (!isFinite(rect.left) || !isFinite(rect.top) || !isFinite(rect.width)
        || !isFinite(rect.height) || rect.width < 480 || rect.height < 270) return false
    source = {
      sourceKey: candidate.sourceKey, videoId: candidate.videoId,
      seconds: candidate.seconds, sourceWasPlaying: candidate.sourceWasPlaying,
      sourceKind: extension ? "extension" : "mpris",
      connectionId: extension ? candidate.connectionId : -1,
      tabId: extension ? candidate.tabId : -1,
      mediaId: candidate.mediaId || "", epoch: candidate.epoch,
      browser: extension ? candidate.browser : ""
    }
    focused = false
    videoRect = rect
    videoPosition = candidate.seconds
    clearPendingSeek()
    returnSeekTarget = -1
    videoDuration = 0
    captionsEnabled = false
    captionsAvailable = false
    videoPlaying = false
    sourcePausedByUs = false
    sourceClosed = false
    pendingPauseRequest = -1
    pendingReturnRequest = -1
    notice = ""
    state = "launching"
    launchPending = true
    closing = false
    hostProcess.command = [executable, "--screen", targetScreen]
    hostProcess.running = true
    startupDeadline.restart()
    return true
  }

  function beginChiDeck(candidate, rectangle) {
    var rect = {
      left: Math.floor(Number(rectangle.left)), top: Math.floor(Number(rectangle.top)),
      width: Math.floor(Number(rectangle.width)), height: Math.floor(Number(rectangle.height))
    }
    if (!isFinite(rect.left) || !isFinite(rect.top) || !isFinite(rect.width)
        || !isFinite(rect.height) || rect.width < 480 || rect.height < 270) return false
    var tabMedia = chi.tabs[candidate.tabId] || {}
    source = {
      sourceKey: candidate.sourceKey, videoId: candidate.videoId, seconds: candidate.seconds,
      sourceWasPlaying: candidate.sourceWasPlaying, sourceKind: "extension",
      connectionId: candidate.connectionId, tabId: candidate.tabId,
      mediaId: candidate.mediaId || "", epoch: candidate.epoch, browser: "chi"
    }
    chiDeck = true
    focused = false
    videoRect = rect
    videoPosition = Number(tabMedia.position_ms) / 1000 || candidate.seconds
    videoDuration = Number(tabMedia.duration_ms) / 1000 || 0
    videoPlaying = tabMedia.playing === true
    clearPendingSeek()
    returnSeekTarget = -1
    captionsEnabled = false
    captionsAvailable = false
    sourcePausedByUs = false
    sourceClosed = false
    pendingPauseRequest = -1
    pendingReturnRequest = -1
    notice = ""
    closing = false
    state = "launching"
    startupDeadline.restart()
    var placed = chi.place(source, rect, targetScreen, function(reply) {
      if (!root.chiDeck || root.state !== "launching") return
      if (reply.status === "ok") { root.chiDeckPresented(); return }
      // Chi refused (for example another PiP is open): use the embedded player.
      root.finishChiDeck("")
      if (!root.hostAvailable || !root.beginEmbedded(candidate, rect))
        root.notice = "Chi could not show this video here"
    })
    if (!placed) { chiDeck = false; state = "idle"; source = null; startupDeadline.stop(); return false }
    return true
  }

  // The engine confirms presentation asynchronously; follow Chi's tab state.
  function chiDeckPresented() {
    if (!chiDeck || state !== "launching" || !source) return
    if (chi.states[source.tabId] !== "picture-in-picture") return
    startupDeadline.stop()
    state = "playing"
  }

  function chiMediaUpdated(tabId, m) {
    if (!chiDeck || !source || tabId !== source.tabId) return
    if (!m || m.media_id !== source.mediaId) { finishChiDeck("Video changed in Chi"); return }
    videoPlaying = m.playing === true
    var duration = Number(m.duration_ms) / 1000
    if (isFinite(duration) && duration > 0) videoDuration = duration
    var position = Number(m.position_ms) / 1000
    if (!isFinite(position) || position < 0) return
    if (pendingSeekPosition >= 0) {
      if (Math.abs(position - pendingSeekPosition) > 2) return
      clearPendingSeek()
    }
    videoPosition = position
  }

  function chiTabStateChanged(tabId, from, to) {
    if (!chiDeck || !source || tabId !== source.tabId) return
    if (to === "picture-in-picture") { chiDeckPresented(); return }
    // Escape, Ctrl+Alt+P, the sidebar or navigation took the video back.
    if (from === "picture-in-picture" && state !== "returning") finishChiDeck("Video returned to Chi")
  }

  // Leave Watch without sending Chi anything; its video is already elsewhere.
  function finishChiDeck(reason) {
    if (!chiDeck) return
    chiDeck = false
    notice = reason || ""
    stopHost()
  }

  function releaseChiDeck(pause) {
    var candidate = source
    if (pause) chi.control(candidate, { action: "pause" })
    state = "returning"
    returnDeadline.restart()
    if (!chi.release(candidate, function(reply) {
      if (!root.chiDeck || root.state !== "returning") return
      returnDeadline.stop()
      root.finishChiDeck(reply.status === "ok" ? ""
        : "Chi did not take the video back. Select its tab in Chi.")
    })) finishChiDeck("Chi disconnected")
  }

  function hostAnnouncement(line) {
    if (state !== "launching" || !String(line).startsWith("SOCKET ")) return
    var path = String(line).slice(7).trim()
    var runtime = String(Quickshell.env("XDG_RUNTIME_DIR") || "")
    var name = path.slice(runtime.length + 1)
    if (!runtime || path.slice(0, runtime.length + 1) !== runtime + "/"
        || !/^omadeck-watch-[0-9]+-[0-9a-f]+\.sock$/.test(name)) {
      fail("Watch host socket unavailable")
      return
    }
    hostSocket.path = path
    lastHostSocketPath = path
    hostSocket.connected = true
  }

  function send(message) {
    if (!hostSocket.connected) return false
    hostSocket.write(JSON.stringify(message) + "\n")
    hostSocket.flush()
    return true
  }

  function handleMessage(line) {
    var message
    try { message = JSON.parse(String(line)) } catch (error) { return }
    if (!message || typeof message !== "object") return
    if (message.event === "returnSnapshot" && state === "returning" && awaitingReturnSnapshot) {
      var latest = Number(message.seconds)
      if (!isFinite(latest) || latest < 0 || latest > 604800) { returnFailed(false); return }
      awaitingReturnSnapshot = false
      // A tap followed immediately by Return owns the requested seek, even if
      // YouTube has not yet reflected it in its asynchronous playhead report.
      videoPosition = returnSeekTarget >= 0 ? returnSeekTarget : latest
      returnSeekTarget = -1
      lastReturnRequested = videoPosition
      lastReturnConfirmed = -1
      videoPlaying = false
      resumeBrowserAtCurrentPosition()
    } else if (message.event === "captions" && active) {
      captionsEnabled = message.enabled === true
      captionsAvailable = message.available === true
    } else if (message.event === "connected" && state === "launching") {
      state = "loading"
      if (!send({ action: "load", videoId: source.videoId, seconds: source.seconds,
        left: videoRect.left, top: videoRect.top,
        width: videoRect.width, height: videoRect.height })) fail("Watch host disconnected")
    } else if (message.event === "primed" && state === "loading") {
      var player = sourcePlayer()
      if (!player) { fail("Source video changed"); return }
      videoPosition = Number(message.seconds) || source.seconds
      if (source.sourceKind === "extension") {
        pendingPauseRequest = browserBridge.command(source, "pause", videoPosition, false)
        if (pendingPauseRequest < 0) { fail("Browser tab unavailable"); return }
        state = "pausing"
        pauseDeadline.restart()
        return
      }
      if (source.sourceWasPlaying && player.isPlaying) {
        if (typeof media.runAction !== "function"
            || !media.runAction("playPause", false, source.sourceKey)) {
          fail("Could not pause source video")
          return
        }
        sourcePausedByUs = true
        state = "pausing"
        pauseDeadline.restart()
        finishPause()
        return
      }
      commitWatch()
    } else if (message.event === "position" && state === "playing") {
      var position = Number(message.seconds)
      if (isFinite(position) && position >= 0) {
        if (pendingSeekPosition >= 0) {
          if (Math.abs(position - pendingSeekPosition) > 2) return
          clearPendingSeek()
        }
        videoPosition = position
      }
    } else if (message.event === "duration" && active) {
      var duration = Number(message.seconds)
      if (isFinite(duration) && duration > 0) videoDuration = duration
    } else if (message.event === "state" && state === "playing") {
      videoPlaying = Number(message.state) === 1
    } else if (message.event === "error" && active) {
      var code = Number(message.code)
      if (code === 101 || code === 150)
        fail("This video cannot play inside OmaDeck. Keep watching in your browser.")
      else if (code === 100)
        fail("This video is unavailable or private. Keep watching in your browser.")
      else fail("Video could not start" + (isFinite(code) ? " (" + code + ")" : ""))
    }
  }

  function finishPause() {
    if (state !== "pausing") return
    if (source && source.sourceKind === "extension") return
    var player = sourcePlayer()
    if (!player) { fail("Source video changed"); return }
    if (player.isPlaying) return
    if (player.positionSupported && isFinite(player.position)) videoPosition = player.position
    pauseDeadline.stop()
    commitWatch()
  }

  function commitWatch() {
    if (!send({ action: "commit", seconds: Math.floor(videoPosition) })) {
      fail("Watch host disconnected"); return
    }
    startupDeadline.stop()
    state = "playing"
    videoPlaying = true
  }

  function setVideoGeometry(rectangle) {
    if (!active || !rectangle) return false
    var rect = { left: Math.floor(Number(rectangle.left)), top: Math.floor(Number(rectangle.top)),
      width: Math.floor(Number(rectangle.width)), height: Math.floor(Number(rectangle.height)) }
    if (!isFinite(rect.left) || !isFinite(rect.top) || !isFinite(rect.width) || !isFinite(rect.height)
        || rect.left < 0 || rect.left > 5000 || rect.top < 0 || rect.top > 3000
        || rect.width < 160 || rect.width > 3000 || rect.height < 90 || rect.height > 1200) return false
    if (rect.left === videoRect.left && rect.top === videoRect.top
        && rect.width === videoRect.width && rect.height === videoRect.height) return true
    if (chiDeck) {
      if (!chi.place(source, rect, targetScreen)) return false
    } else if (state !== "launching" && !send({ action: "geometry", left: rect.left, top: rect.top,
        width: rect.width, height: rect.height })) return false
    videoRect = rect
    return true
  }

  function setFocus(nextFocused, rectangle) {
    if (state !== "playing" || !setVideoGeometry(rectangle)) return false
    focused = nextFocused
    return true
  }

  function togglePlayback() {
    if (state !== "playing") return
    if (chiDeck) { chi.control(source, { action: videoPlaying ? "pause" : "play" }); return }
    send({ action: videoPlaying ? "pause" : "play" })
  }

  function seekBy(delta) {
    if (state !== "playing" || !isFinite(Number(delta))) return
    seekTo((pendingSeekPosition >= 0 ? pendingSeekPosition : videoPosition) + Number(delta))
  }

  function seekTo(seconds) {
    if (state !== "playing") return
    if (!isFinite(Number(seconds))) return
    var maximum = videoDuration > 0 ? Math.min(604800, videoDuration) : 604800
    var next = Math.max(0, Math.min(maximum, Math.floor(Number(seconds))))
    if (!isFinite(next)) return
    if (chiDeck ? !chi.control(source, { action: "seek", position_ms: next * 1000 })
        : !send({ action: "seek", seconds: next })) return
    pendingSeekPosition = next
    videoPosition = next
    seekDeadline.restart()
  }

  function clearPendingSeek() {
    pendingSeekPosition = -1
    seekDeadline.stop()
  }

  function toggleCaptions() {
    if (state === "playing") send({ action: captionsEnabled ? "captionsOff" : "captionsOn" })
  }

  function restoreSource(resume) {
    if (source && source.sourceKind === "extension") {
      if (resume && browserBridge) {
        var requestId = browserBridge.command(source, "resume", videoPosition, source.sourceWasPlaying)
        browserBridge.forgetRequest(requestId)
      }
      return
    }
    var player = sourcePlayer()
    if (!player) return
    if (player.canSeek && player.positionSupported && isFinite(videoPosition))
      player.seek(Math.max(0, videoPosition) - player.position)
    if (resume && sourcePausedByUs && !player.isPlaying
        && typeof media.runAction === "function")
      media.runAction("playPause", false, source.sourceKey)
  }

  function returnToSource() {
    if (!active) return
    if (chiDeck) { if (state !== "returning") releaseChiDeck(false); return }
    if (sourceClosed) { stopHost(); return }
    if (state === "returning") return
    if (!source) { stopHost(); return }
    returnSeekTarget = pendingSeekPosition
    clearPendingSeek()
    state = "returning"
    awaitingReturnSnapshot = true
    returnDeadline.restart()
    if (!send({ action: "returnSnapshot" })) returnFailed(false)
  }

  function resumeBrowserAtCurrentPosition() {
    if (source && source.sourceKind === "extension") {
      pendingReturnRequest = browserBridge
        ? browserBridge.command(source, "resume", videoPosition, source.sourceWasPlaying) : -1
      if (pendingReturnRequest < 0) { returnFailed(); return }
      returnDeadline.restart()
      return
    }
    var player = sourcePlayer()
    if (!player || !player.canSeek || !player.positionSupported) { returnFailed(false); return }
    returnSeekPending = true
    returnResumeSent = false
    returnStableSamples = 0
    player.seek(Math.max(0, videoPosition) - player.position)
    returnSeekCheck.restart()
  }

  function checkBrowserReturn() {
    if (state !== "returning" || !returnSeekPending) return
    var player = sourcePlayer()
    if (!player) { returnFailed(false); return }
    // Firefox/Zen can report zero and the old playhead during an async seek.
    // Require two matching samples before resuming, then verify again afterward.
    if (Math.abs(player.position - videoPosition) > 2) { returnStableSamples = 0; return }
    returnStableSamples++
    if (returnStableSamples < 2) return
    if (source.sourceWasPlaying && !returnResumeSent) {
      if (!player.isPlaying && !media.runAction("playPause", false, source.sourceKey)) {
        returnFailed(false); return
      }
      returnResumeSent = true
      returnStableSamples = 0
      return
    }
    if (source.sourceWasPlaying && !player.isPlaying) return
    stopHost()
  }

  function returnFailed(resumeHost) {
    if (browserBridge) browserBridge.cancelRequest(pendingReturnRequest)
    pendingReturnRequest = -1
    returnDeadline.stop()
    returnSeekCheck.stop()
    returnSeekPending = false
    awaitingReturnSnapshot = false
    returnSeekTarget = -1
    notice = resumeHost === false ? "Browser did not confirm. Retry Return or close the video."
      : "Browser tab unavailable; video remains here"
    state = "playing"
    videoPlaying = false
    if (resumeHost !== false) send({ action: "play" })
  }

  function abort() {
    if (!active) return
    // Close, lock and monitor removal pause Chi's video and give it back.
    if (chiDeck) { if (state !== "returning") releaseChiDeck(true); return }
    // Lock and monitor removal do not restart browser audio behind the owner.
    stopHost()
  }

  function fail(reason) {
    if (chiDeck) {
      // Never leave the video parked in an unowned rectangle.
      if (source && chi) chi.release(source)
      finishChiDeck(reason)
      return
    }
    // Before the pause request the browser is still playing independently.
    // Do not seek it back to the initial timestamp on a destination load error.
    if (!sourceClosed && (sourcePausedByUs || pendingPauseRequest > 0)) restoreSource(true)
    notice = reason
    stopHost()
  }

  function stopHost() {
    clearPendingSeek()
    returnSeekTarget = -1
    startupDeadline.stop()
    pauseDeadline.stop()
    returnDeadline.stop()
    returnSeekCheck.stop()
    returnSeekPending = false
    awaitingReturnSnapshot = false
    closing = true
    launchPending = false
    var wasConnected = hostSocket.connected
    send({ action: "close" })
    hostSocket.connected = false
    hostSocket.path = ""
    if (hostProcess.running) {
      if (wasConnected) shutdownDeadline.restart()
      else hostProcess.running = false
    }
    if (browserBridge) {
      browserBridge.cancelRequest(pendingPauseRequest)
      browserBridge.cancelRequest(pendingReturnRequest)
    }
    if (browserBridge) browserBridge.releaseSource(source)
    source = null
    chiDeck = false
    sourcePausedByUs = false
    sourceClosed = false
    pendingPauseRequest = -1
    pendingReturnRequest = -1
    videoPlaying = false
    state = "idle"
    focused = false
  }

  onPluginDirChanged: refreshAvailability()
  Component.onCompleted: refreshAvailability()
  Component.onDestruction: stopHost()

  Timer {
    id: seekDeadline
    interval: 4000
    // If the player rejects a seek, resume reporting its real position rather
    // than leaving the timeline stuck indefinitely at an optimistic target.
    onTriggered: root.clearPendingSeek()
  }

  Process {
    id: hostProbe
    command: ["/usr/bin/test", "-x", root.executable]
    onExited: function(exitCode) { root.hostAvailable = exitCode === 0 }
  }

  Process {
    id: hostProcess
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => root.hostAnnouncement(data)
    }
    onStarted: root.launchPending = false
    onRunningChanged: {
      if (!running && root.launchPending && root.active && !root.closing)
        root.fail("Watch host did not start")
    }
    onExited: function(exitCode) {
      shutdownDeadline.stop()
      root.launchPending = false
      if (root.active && !root.closing) root.fail("Watch host exited")
      if (root.lastHostSocketPath) {
        socketCleanup.command = ["/usr/bin/rm", "-f", "--", root.lastHostSocketPath]
        socketCleanup.running = true
        root.lastHostSocketPath = ""
      }
    }
  }

  Socket {
    id: hostSocket
    objectName: "watchHostSocket"
    parser: SplitParser {
      splitMarker: "\n"
      onRead: data => root.handleMessage(data)
    }
    onConnectionStateChanged: {
      if (!connected && root.active && !root.closing) root.fail("Watch host disconnected")
    }
  }

  Process { id: socketCleanup }

  Timer {
    id: returnSeekCheck
    interval: 250
    repeat: true
    onTriggered: root.checkBrowserReturn()
  }

  Timer {
    id: shutdownDeadline
    interval: 1500
    onTriggered: hostProcess.running = false
  }

  Connections {
    target: root.sourcePlayer()
    function onIsPlayingChanged() { root.finishPause() }
  }

  Connections {
    target: root.browserBridge
    function onSourcePlaying(connectionId, tabId) {
      if (root.state === "playing" && root.source && root.sourcePausedByUs
          && root.source.connectionId === connectionId && root.source.tabId === tabId) {
        root.notice = "Playback resumed in Chi"
        root.stopHost()
      }
    }
    function onSourceClosed(connectionId, tabId) {
      if (root.chiDeck) return // Chi ends its own presentation; see chiMediaUpdated.
      if (!root.active || !root.source || root.source.sourceKind !== "extension"
          || root.source.connectionId !== connectionId || root.source.tabId !== tabId) return
      root.sourceClosed = true
      if (root.state === "launching" || root.state === "loading" || root.state === "pausing"
          || root.state === "returning") {
        // Return already asks to leave Watch. If navigation/autoplay replaces
        // the source during that handshake, close without touching its successor.
        root.stopHost()
        return
      }
      root.notice = "Original tab closed. Close the video when finished."
    }
    function onPauseResult(requestId, ok, seconds) {
      if (root.state === "returning" && requestId === root.pendingReturnRequest) {
        root.lastReturnConfirmed = seconds
        // An acknowledgement without the measured playhead is not a seek proof.
        if (ok && seconds >= 0 && Math.abs(seconds - root.videoPosition) <= 3) root.stopHost()
        else root.returnFailed(false)
        return
      }
      if (root.state !== "pausing" || requestId !== root.pendingPauseRequest) return
      root.pendingPauseRequest = -1
      if (!ok || seconds < 0) { root.fail("Browser tab did not pause"); return }
      root.videoPosition = seconds
      root.sourcePausedByUs = true
      pauseDeadline.stop()
      root.commitWatch()
    }
    function onConnectionDropped(connectionId) {
      if (root.chiDeck) return
      if (root.active && root.source && root.source.sourceKind === "extension"
          && root.source.connectionId === connectionId) root.abort()
    }
  }

  Connections {
    target: root.chi
    function onMediaUpdated(tabId, media) { root.chiMediaUpdated(tabId, media) }
    function onTabStateChanged(tabId, from, to) { root.chiTabStateChanged(tabId, from, to) }
    function onDropped() { if (root.chiDeck) root.finishChiDeck("Chi disconnected") }
  }

  Timer {
    id: startupDeadline
    interval: 15000
    onTriggered: if (root.active) root.fail("Video startup timed out")
  }

  Timer {
    id: pauseDeadline
    interval: 3000
    onTriggered: if (root.state === "pausing") root.fail("Source did not pause")
  }

  Timer {
    id: returnDeadline
    interval: 10000
    onTriggered: {
      if (root.state !== "returning") return
      if (root.chiDeck) root.finishChiDeck("Chi did not take the video back. Select its tab in Chi.")
      else root.returnFailed(false)
    }
  }
}
