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

  function begin(candidate, rectangle) {
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
      browser: extension ? candidate.browser : ""
    }
    focused = false
    videoRect = rect
    videoPosition = candidate.seconds
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
      videoPosition = latest
      lastReturnRequested = latest
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
      if (isFinite(position) && position >= 0) videoPosition = position
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
    if (state !== "launching" && !send({ action: "geometry", left: rect.left, top: rect.top,
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
    send({ action: videoPlaying ? "pause" : "play" })
  }

  function seekBy(delta) {
    if (state !== "playing") return
    var next = Math.max(0, Math.min(604800, Math.floor(videoPosition + delta)))
    send({ action: "seek", seconds: next })
  }

  function seekTo(seconds) {
    if (state !== "playing") return
    var next = Math.max(0, Math.min(604800, Math.floor(Number(seconds))))
    if (isFinite(next)) send({ action: "seek", seconds: next })
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
    if (sourceClosed) { stopHost(); return }
    if (state === "returning") return
    if (!source) { stopHost(); return }
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
    if (browserBridge) browserBridge.forgetRequest(pendingReturnRequest)
    pendingReturnRequest = -1
    returnDeadline.stop()
    returnSeekCheck.stop()
    returnSeekPending = false
    awaitingReturnSnapshot = false
    notice = resumeHost === false ? "Browser did not confirm. Retry Return or close the video."
      : "Browser tab unavailable; video remains here"
    state = "playing"
    videoPlaying = false
    if (resumeHost !== false) send({ action: "play" })
  }

  function abort() {
    if (!active) return
    // Lock and monitor removal do not restart browser audio behind the owner.
    stopHost()
  }

  function fail(reason) {
    // Before the pause request the browser is still playing independently.
    // Do not seek it back to the initial timestamp on a destination load error.
    if (!sourceClosed && (sourcePausedByUs || pendingPauseRequest > 0)) restoreSource(true)
    notice = reason
    stopHost()
  }

  function stopHost() {
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
      browserBridge.forgetRequest(pendingPauseRequest)
      browserBridge.forgetRequest(pendingReturnRequest)
    }
    source = null
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
    function onSourceClosed(connectionId, tabId) {
      if (!root.active || !root.source || root.source.sourceKind !== "extension"
          || root.source.connectionId !== connectionId || root.source.tabId !== tabId) return
      root.sourceClosed = true
      if (root.state === "launching" || root.state === "loading" || root.state === "pausing") {
        root.stopHost()
        return
      }
      if (root.state === "returning") root.returnFailed(false)
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
      if (root.active && root.source && root.source.sourceKind === "extension"
          && root.source.connectionId === connectionId) root.abort()
    }
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
    onTriggered: if (root.state === "returning") root.returnFailed(false)
  }
}
