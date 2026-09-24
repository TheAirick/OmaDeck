import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property bool enabled: true
  readonly property string runtimeDir: String(Quickshell.env("XDG_RUNTIME_DIR") || "")
  readonly property string socketPath: runtimeDir ? runtimeDir + "/omadeck-browser-watch.sock" : ""
  property var connections: []
  property int nextConnectionId: 1
  property int nextRequestId: 1
  property var pendingRequests: ({})

  signal pauseResult(int requestId, bool ok, real seconds)
  signal connectionDropped(int connectionId)
  signal sourceClosed(int connectionId, int tabId)

  function register(socket) {
    if (!socket) return
    socket.connectionId = nextConnectionId++
    connections = connections.concat([{ id: socket.connectionId, socket: socket,
      browser: "", candidate: null, seenMs: 0 }])
  }

  function drop(socket) {
    if (!socket) return
    if (socket.connectionId > 0) connectionDropped(socket.connectionId)
    for (var requestId in pendingRequests) {
      if (pendingRequests[requestId] === socket.connectionId)
        delete pendingRequests[requestId]
    }
    connections = connections.filter(function(entry) { return entry.socket !== socket })
  }

  function connection(id) {
    for (var i = 0; i < connections.length; i++)
      if (connections[i].id === id) return connections[i]
    return null
  }

  function validVideoId(id) { return /^[A-Za-z0-9_-]{11}$/.test(String(id || "")) }
  function validBrowser(value) { return value === "firefox" || value === "chromium" }

  function receive(socket, line) {
    if (!socket || String(line).length > 1024) return
    var message
    try { message = JSON.parse(String(line)) } catch (error) { return }
    if (!message || typeof message !== "object") return
    var entry = connection(socket.connectionId)
    if (!entry || entry.socket !== socket) return

    if (message.type === "hello" && validBrowser(message.browser)) {
      entry.browser = message.browser
      connections = connections.slice()
      return
    }
    if (message.type === "candidate" && validBrowser(entry.browser)
        && validVideoId(message.videoId)
        && Number.isInteger(message.tabId) && message.tabId >= 0
        && message.tabId <= 2147483647
        && isFinite(Number(message.seconds)) && Number(message.seconds) >= 0
        && Number(message.seconds) <= 604800) {
      entry.candidate = {
        videoId: String(message.videoId), seconds: Math.floor(Number(message.seconds)),
        tabId: message.tabId, sourceWasPlaying: message.playing === true,
        browser: entry.browser, connectionId: entry.id, sourceKind: "extension"
      }
      entry.seenMs = Date.now()
      connections = connections.slice()
      return
    }
    if (message.type === "clear") {
      entry.candidate = null
      entry.seenMs = 0
      connections = connections.slice()
      return
    }
    if (message.type === "sourceClosed" && validBrowser(entry.browser)
        && Number.isInteger(message.tabId) && message.tabId >= 0
        && message.tabId <= 2147483647) {
      sourceClosed(entry.id, message.tabId)
      return
    }
    if (message.type === "ack" && Number.isInteger(message.requestId)
        && typeof message.ok === "boolean"
        && pendingRequests[message.requestId] === entry.id) {
      delete pendingRequests[message.requestId]
      var seconds = Number(message.seconds)
      pauseResult(message.requestId, message.ok,
        message.seconds !== undefined && isFinite(seconds) && seconds >= 0
          && seconds <= 604800 ? seconds : -1)
    }
  }

  function browserForPlayerKey(key) {
    var value = String(key || "").toLowerCase()
    if (value.indexOf("firefox") !== -1 || value.indexOf("zen") !== -1) return "firefox"
    if (value.indexOf("chromium") !== -1 || value.indexOf("chrome") !== -1) return "chromium"
    return ""
  }

  function candidateForPlayer(key) {
    var browser = browserForPlayerKey(key)
    if (!browser) return null
    var selected = null
    for (var i = 0; i < connections.length; i++) {
      var entry = connections[i]
      // Browser selection lives until clear/disconnect. Background page timers
      // may be suspended; pause still validates the exact video before transfer.
      if (entry.browser !== browser || !entry.socket.connected || !entry.candidate) continue
      if (!selected || entry.seenMs > selected.seenMs) selected = entry
    }
    if (!selected) return null
    var candidate = Object.assign({}, selected.candidate)
    candidate.sourceKey = String(key)
    return candidate
  }

  function connectedSource(candidate) {
    if (!candidate || candidate.sourceKind !== "extension") return false
    var entry = connection(candidate.connectionId)
    return !!(entry && entry.socket.connected && entry.browser === candidate.browser
      && validVideoId(candidate.videoId) && Number.isInteger(candidate.tabId)
      && candidate.tabId >= 0 && candidate.tabId <= 2147483647)
  }

  function matches(candidate) {
    if (!connectedSource(candidate)) return false
    var entry = connection(candidate.connectionId)
    return !!(entry.candidate
      && entry.candidate.tabId === candidate.tabId
      && entry.candidate.videoId === candidate.videoId
      && entry.browser === candidate.browser)
  }

  function command(candidate, action, seconds, wasPlaying) {
    // A session keeps its exact source tab even after selection changes or
    // background timers are throttled. The content script revalidates the video.
    if (!connectedSource(candidate)) return -1
    var entry = connection(candidate.connectionId)
    var requestId = nextRequestId
    nextRequestId = nextRequestId >= 2147483647 ? 1 : nextRequestId + 1
    pendingRequests[requestId] = entry.id
    entry.socket.write(JSON.stringify({ type: "command", action: action,
      requestId: requestId, tabId: candidate.tabId, videoId: candidate.videoId,
      seconds: Math.max(0, Math.min(604800, Math.floor(Number(seconds) || 0))),
      wasPlaying: wasPlaying === true }) + "\n")
    entry.socket.flush()
    return requestId
  }

  function forgetRequest(requestId) {
    if (requestId > 0) delete pendingRequests[requestId]
  }

  SocketServer {
    id: server
    active: root.enabled && root.socketPath !== ""
    path: root.socketPath
    handler: Socket {
      id: client
      property int connectionId: 0
      onConnectedChanged: {
        if (connected) root.register(client)
        else root.drop(client)
      }
      parser: SplitParser {
        splitMarker: "\n"
        onRead: data => root.receive(client, data)
      }
    }
  }

}
