import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "WatchSource.js" as WatchSource

// A client of Chi's existing control API. Discovery never evaluates page JS,
// focuses a window or wakes a tab. Media discovery is event driven; no extra player or daemon.
Item {
  id: root
  objectName: "chiWatchBridge"
  property bool enabled: true
  property string socketPath: String(Quickshell.env("XDG_RUNTIME_DIR") || "") + "/chi.sock"
  property var tabs: ({})
  property var tasks: ({})
  property var held: null
  property var queue: []
  property var inFlight: null
  property bool ready: false
  property int epoch: 0
  property int serial: 0
  property int retryMs: 1000
  readonly property bool wantsConnection: enabled && (ready || !!held
    || players.some(function(p) { return String(p.identity) === "Chi" }))
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property string clientId: "omadeck-" + Date.now() + "-" + Math.random().toString(36).slice(2)
  signal result(int requestId, bool ok, real seconds)
  signal sourceClosed(int tabId)
  signal dropped()
  signal sourcePlaying(int tabId)

  function reset() {
    var hadConnection = ready || Object.keys(tasks).length > 0
    ready = false
    epoch++
    tabs = ({})
    tasks = ({})
    held = null
    queue = []
    inFlight = null
    if (hadConnection) dropped()
  }

  function update(tabId, media) {
    var previous = tabs[tabId]
    if (previous && (!media || previous.media_id !== media.media_id)) sourceClosed(Number(tabId))
    var next = Object.assign({}, tabs)
    if (media && media.media_id && media.has_video) next[tabId] = media
    else delete next[tabId]
    tabs = next
    if (media && media.playing) sourcePlaying(Number(tabId))
  }

  function playerMatches(player, m) {
    // WebKit has no xesam:url. Require its native Chi identity and both exact
    // metadata fields; refuse duplicate tabs/players instead of guessing.
    return !!(player && String(player.identity) === "Chi" && m && m.title && m.artwork
      && String(player.trackTitle) === m.title && String(player.trackArtUrl) === m.artwork)
  }

  function candidateForPlayer(key, player) {
    if (!ready || !key || !player) return null
    var matches = []
    for (var tabId in tabs) {
      var m = tabs[tabId]
      var videoId = WatchSource.youtubeVideoId(m.page_url)
      if (videoId && playerMatches(player, m)) matches.push({ id: Number(tabId), media: m, videoId: videoId })
    }
    if (matches.length !== 1) return null
    var match = matches[0]
    if (players.filter(function(p) { return root.playerMatches(p, match.media) }).length !== 1) return null
    return { sourceKind: "extension", browser: "chi", connectionId: 0,
      tabId: match.id, mediaId: match.media.media_id, epoch: epoch,
      videoId: match.videoId, seconds: Math.floor(match.media.position_ms / 1000),
      sourceWasPlaying: match.media.playing, sourceKey: key }
  }

  function connectedSource(candidate) {
    var m = candidate ? tabs[candidate.tabId] : null
    return !!(ready && candidate && candidate.epoch === epoch && m
      && m.media_id === candidate.mediaId && WatchSource.youtubeVideoId(m.page_url) === candidate.videoId)
  }

  function enqueue(message, taskId) {
    queue = queue.concat([{ message: message, taskId: taskId }])
    pump()
  }

  function pump() {
    if (inFlight || !queue.length) return
    if (!commands.connected) { commands.connected = true; return }
    inFlight = queue[0]
    queue = queue.slice(1)
    if (inFlight.taskId > 0 && !tasks[inFlight.taskId]) { inFlight = null; pump(); return }
    commands.write(JSON.stringify(inFlight.message) + "\n")
    commands.flush()
  }

  function step(requestId) {
    requestId = Number(requestId)
    var task = tasks[requestId]
    if (!task) return
    if (!connectedSource(task.source)) { finish(requestId, false, -1); return }
    if (!task.actions.length) { finish(requestId, true, task.seconds); return }
    task.token = clientId + ":" + (++serial)
    var action = task.actions.shift()
    enqueue({ cmd: "media", tab: task.source.tabId,
      action: { action: "guarded", media_id: task.source.mediaId,
        request: task.token, control: action } }, requestId)
  }

  function command(candidate, action, seconds, playing, requestId) {
    if (!connectedSource(candidate) || (action !== "pause" && action !== "resume")) return false
    var actions = [{ action: "pause" }]
    if (action === "resume") {
      actions.push({ action: "seek", position_ms: Math.round(seconds * 1000) })
      if (playing) actions.push({ action: "play" })
    }
    tasks[requestId] = { source: candidate, actions: actions, seconds: -1, token: "", deadline: Date.now() + 8000 }
    tasks = Object.assign({}, tasks)
    held = candidate
    enqueue({ cmd: "media-hold", tab: candidate.tabId, media_id: candidate.mediaId,
      owner: clientId, seconds: 90 }, requestId)
    step(requestId)
    return true
  }

  function finish(requestId, ok, seconds) {
    requestId = Number(requestId)
    if (!tasks[requestId]) return
    delete tasks[requestId]
    tasks = Object.assign({}, tasks)
    result(Number(requestId), ok, seconds)
  }

  function forget(requestId) {
    requestId = Number(requestId)
    var task = tasks[requestId]
    if (!task) return
    delete tasks[requestId]
    tasks = Object.assign({}, tasks)
    queue = queue.filter(function(entry) { return entry.taskId !== requestId })
    // Supersede a timed-out return before its asynchronous play can finish.
    if (connectedSource(task.source)) enqueue({ cmd: "media", tab: task.source.tabId,
      action: { action: "guarded", media_id: task.source.mediaId,
        request: clientId + ":cancel:" + (++serial), control: { action: "pause" } } }, -1)
  }

  function releaseSource(candidate) {
    if (!candidate || candidate.browser !== "chi" || !held || candidate.mediaId !== held.mediaId) return
    held = null
    enqueue({ cmd: "media-hold", tab: candidate.tabId, media_id: candidate.mediaId,
      owner: clientId, seconds: 0 }, -1)
  }

  Timer {
    interval: 30000
    running: root.ready && !!root.held
    repeat: true
    onTriggered: {
      if (!root.connectedSource(root.held)) { root.held = null; return }
      root.enqueue({ cmd: "media-hold", tab: root.held.tabId, media_id: root.held.mediaId,
        owner: root.clientId, seconds: 90 }, -1)
    }
  }

  Timer {
    interval: 1000
    running: Object.keys(root.tasks).length > 0
    repeat: true
    onTriggered: {
      for (var requestId in root.tasks) {
        if (root.tasks[requestId].deadline > Date.now()) continue
        root.result(Number(requestId), false, -1)
        root.forget(Number(requestId))
      }
    }
  }

  function receiveEvent(line) {
    var m
    try { m = JSON.parse(line) } catch (_) { return }
    if (m.status === "ok") { enqueue({ cmd: "media-list" }, -1); return }
    if (m.event === "media-changed") update(m.tab, m.media)
    else if (m.event === "tab-closed" || (m.event === "tab-state-changed" && m.to === "asleep")) update(m.id, null)
    else if (m.event === "media-action-finished") {
      for (var requestId in tasks) {
        var task = tasks[requestId]
        if (task.token !== m.request || task.source.tabId !== m.tab || task.source.mediaId !== m.media_id) continue
        if (!m.ok) { finish(requestId, false, m.position_ms / 1000); return }
        task.seconds = m.position_ms / 1000
        step(requestId)
        return
      }
    }
  }

  Socket {
    id: events
    path: root.socketPath
    onConnectedChanged: {
      if (connected) { root.retryMs = 1000; write('{"cmd":"subscribe"}\n'); flush() }
      else { commands.connected = false; root.reset() }
    }
    parser: SplitParser { splitMarker: "\n"; onRead: line => root.receiveEvent(line) }
  }
  Socket {
    id: commands
    objectName: "chiWatchCommands"
    path: root.socketPath
    onConnectedChanged: {
      if (connected) root.pump()
      else if (root.inFlight) {
        var failed = root.inFlight
        root.inFlight = null
        root.finish(failed.taskId, false, -1)
      }
    }
    parser: SplitParser {
      splitMarker: "\n"
      onRead: line => {
        var request = root.inFlight
        root.inFlight = null
        var reply
        try { reply = JSON.parse(line) } catch (_) { reply = { status: "error" } }
        if (request && request.message.cmd === "media-list" && reply.status === "ok") {
          var next = ({})
          for (var tab of reply.data || []) if (tab.media && tab.media.media_id && tab.media.has_video) next[tab.id] = tab.media
          root.tabs = next
          root.ready = true
        } else if (request && reply.status !== "ok") root.finish(request.taskId, false, -1)
        if (root.queue.length) root.pump()
        else commands.connected = false
      }
    }
  }
  Timer {
    interval: root.retryMs
    running: root.wantsConnection && !events.connected
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      events.connected = true
      if (!events.connected) root.retryMs = Math.min(root.retryMs * 2, 30000)
    }
  }
  onEnabledChanged: if (!enabled) { events.connected = false; commands.connected = false; reset() }
}
