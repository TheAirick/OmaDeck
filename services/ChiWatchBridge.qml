import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "WatchSource.js" as WatchSource

// A client of Chi's existing control API. Discovery never evaluates page JS,
// focuses a window or wakes a tab. Media discovery is event driven; no extra player or daemon.
// The source is Chi's own now-playing tab. WebKit's MPRIS player can stick to an
// older video, so MPRIS only says the displayed card belongs to Chi.
Item {
  id: root
  objectName: "chiWatchBridge"
  property bool enabled: true
  property string socketPath: String(Quickshell.env("XDG_RUNTIME_DIR") || "") + "/chi.sock"
  property var tabs: ({})
  // Chi tab states, so Watch can follow its own PiP presentation.
  property var states: ({})
  // Chi's tab whose unmuted media most recently started playing; -1 for none.
  property int nowPlaying: -1
  // Chi tabs whose media started with sound, most recent first (nowPlaying
  // leads). A pause never reorders it.
  property var recent: []
  property int nowPlayingEvents: 0
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
  signal mediaUpdated(int tabId, var media)
  signal tabStateChanged(int tabId, string from, string to)

  function reset() {
    var hadConnection = ready || Object.keys(tasks).length > 0
    ready = false
    epoch++
    tabs = ({})
    states = ({})
    nowPlaying = -1
    recent = []
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
    mediaUpdated(Number(tabId), media || null)
  }

  function setState(tabId, from, to) {
    var next = Object.assign({}, states)
    next[tabId] = to
    states = next
    tabStateChanged(Number(tabId), String(from), String(to))
  }

  // Chi's own video on the deck: its picture-in-picture presentation in the
  // Watch rectangle. No second player, page evaluation or focus change.
  function send(message, onReply) {
    queue = queue.concat([{ message: message, taskId: -1, onReply: onReply || null }])
    pump()
  }

  function place(candidate, rect, monitor, onReply) {
    if (!connectedSource(candidate) || !monitor || !rect) return false
    send({ cmd: "pip-place", tab: candidate.tabId, placement: { monitor: String(monitor),
      x: rect.left, y: rect.top, width: rect.width, height: rect.height } }, onReply)
    return true
  }

  function release(candidate, onReply) {
    if (!ready || !candidate) return false
    send({ cmd: "pip-release", tab: candidate.tabId }, onReply)
    return true
  }

  function control(candidate, action) {
    if (!connectedSource(candidate)) return false
    send({ cmd: "media", tab: candidate.tabId, action: { action: "guarded",
      media_id: candidate.mediaId, request: clientId + ":deck:" + (++serial), control: action } })
    return true
  }

  // The Now Playing card's transport for Chi's now-playing tab. Guarded by
  // the shown media identity, so a control never reaches a different video.
  function controlNowPlaying(action, tab) {
    var id = tab === undefined || tab === null || tab < 0 ? nowPlaying : Number(tab)
    var media = ready && id >= 0 ? tabs[id] : null
    if (!media || !media.media_id) return false
    send({ cmd: "media", tab: id, action: { action: "guarded", media_id: media.media_id,
      request: clientId + ":card:" + (++serial), control: action } })
    return true
  }

  function setNowPlaying(tabId, recentTabs) {
    var id = Number(tabId)
    nowPlaying = tabId === null || tabId === undefined || !isFinite(id) ? -1 : id
    var list = Array.isArray(recentTabs) ? recentTabs.map(Number).filter(isFinite) : []
    // An older daemon sends no list: keep at least the now-playing tab.
    recent = list.length ? list : (nowPlaying >= 0 ? [nowPlaying] : [])
  }

  // `tab` picks one of Chi's sources (the card's selection); by default the
  // tab Chi reports as now playing, whatever title MPRIS shows.
  function candidateForPlayer(key, player, tab) {
    if (!ready || !key || !player || String(player.identity) !== "Chi") return null
    var id = tab === undefined || tab === null || tab < 0 ? nowPlaying : Number(tab)
    var m = tabs[id]
    var videoId = m ? WatchSource.youtubeVideoId(m.page_url) : ""
    if (!m || !videoId) return null
    return { sourceKind: "extension", browser: "chi", connectionId: 0,
      tabId: id, mediaId: m.media_id, epoch: epoch,
      videoId: videoId, seconds: Math.floor(m.position_ms / 1000),
      sourceWasPlaying: m.playing, sourceKey: key }
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
    if (!commands.connected) {
      if (commandsFailed) { commandsFailed = false; renew(commandsLoader) }
      commands.connected = true
      return
    }
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
    if (m.status === "ok") {
      enqueue({ cmd: "media-list" }, -1)
      // An event that arrives first is newer than this snapshot.
      var seen = nowPlayingEvents
      send({ cmd: "status" }, function(reply) {
        if (reply.status === "ok" && root.nowPlayingEvents === seen)
          root.setNowPlaying(reply.data ? reply.data.now_playing : null, reply.data ? reply.data.recent_media : null)
      })
      return
    }
    if (m.event === "now-playing-changed") { nowPlayingEvents++; setNowPlaying(m.tab, m.recent); return }
    if (m.event === "media-changed") update(m.tab, m.media)
    else if (m.event === "tab-closed" || (m.event === "tab-state-changed" && m.to === "asleep")) update(m.id, null)
    if (m.event === "tab-state-changed") setState(m.id, m.from, m.to)
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

  // A Quickshell Socket that has failed (Chi restarting, its socket briefly
  // gone) never connects again, even after Chi is back; that hid Watch here
  // until the shell restarted. A failed socket is replaced before reuse.
  readonly property var events: eventsLoader.item
  readonly property var commands: commandsLoader.item
  property bool eventsFailed: false
  property bool commandsFailed: false
  function renew(loader) { loader.active = false; loader.active = true }

  Loader {
    id: eventsLoader
    sourceComponent: Socket {
      objectName: "chiWatchEvents"
      path: root.socketPath
      onError: root.eventsFailed = true
      onConnectedChanged: {
        if (connected) { root.retryMs = 1000; write('{"cmd":"subscribe"}\n'); flush() }
        else { if (root.commands) root.commands.connected = false; root.reset() }
      }
      parser: SplitParser { splitMarker: "\n"; onRead: line => root.receiveEvent(line) }
    }
  }
  Loader {
    id: commandsLoader
    sourceComponent: Socket {
      objectName: "chiWatchCommands"
      path: root.socketPath
      onError: root.commandsFailed = true
      onConnectedChanged: {
        if (connected) root.pump()
        else if (root.inFlight) {
          var failed = root.inFlight
          root.inFlight = null
          root.finish(failed.taskId, false, -1)
          if (failed.onReply) failed.onReply({ status: "error", message: "Chi disconnected" })
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
            var states = ({})
            for (var tab of reply.data || []) {
              states[tab.id] = tab.state
              if (tab.media && tab.media.media_id && tab.media.has_video) next[tab.id] = tab.media
            }
            root.tabs = next
            root.states = states
            root.ready = true
          } else if (request && reply.status !== "ok") root.finish(request.taskId, false, -1)
          if (request && request.onReply) request.onReply(reply)
          if (root.queue.length) root.pump()
          else root.commands.connected = false
        }
      }
    }
  }
  // Retry until Chi has answered, not merely until the socket says connected.
  Timer {
    objectName: "chiWatchRetry"
    interval: root.retryMs
    running: root.wantsConnection && !root.ready
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      // Back off first: a connect succeeds synchronously and resets it.
      root.retryMs = Math.min(root.retryMs * 2, 30000)
      if (root.eventsFailed) { root.eventsFailed = false; root.renew(eventsLoader) }
      else if (root.events.connected) root.events.connected = false
      root.events.connected = true
    }
  }
  onEnabledChanged: if (!enabled) { if (events) events.connected = false; if (commands) commands.connected = false; reset() }
}
