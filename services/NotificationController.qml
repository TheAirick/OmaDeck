import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../modules/NotificationHistory.js" as NotificationHistory

Item {
  id: root
  property var shell: null
  property string pluginDir: ""
  property bool active: false
  property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy"
  readonly property string historyDir: stateDir + "/notifications/history"
  readonly property string popupDir: stateDir + "/notifications"
  readonly property var notificationService: shell && typeof shell.firstPartyServiceFor === "function"
    ? shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var nightlightService: shell && typeof shell.firstPartyServiceFor === "function"
    ? shell.firstPartyServiceFor("omarchy.nightlight") : null
  property var historyEntries: []
  property var controlState: ({ dndAvailable: false, nightAvailable: false, dnd: false, night: false })
  property string notice: ""
  property string historyError: ""
  property bool historyLoaded: false
  property bool reloadPending: false
  property int historyEpoch: 0
  property int liveRevision: 0
  readonly property bool loading: historyReader.running
  readonly property bool busy: commandRunner.running
  readonly property bool dndAvailable: !!notificationService || controlState.dndAvailable === true
  readonly property bool nightAvailable: !!nightlightService || controlState.nightAvailable === true
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : controlState.dnd === true
  readonly property bool night: nightlightService ? nightlightService.enabled : controlState.night === true
  readonly property var entries: {
    var revision = liveRevision
    var count = notificationService && notificationService.popupModel ? notificationService.popupModel.count : 0
    return NotificationHistory.merge(liveRows(), historyEntries, 12)
  }
  signal appOpened()

  function liveRows() {
    var rows = [], model = notificationService ? notificationService.popupModel : null
    if (!model) return rows
    for (var i = 0; i < model.count; i++) {
      var row = model.get(i)
      rows.push({ app: row.app, appIcon: row.appIcon, summary: row.summary, body: row.body,
        glyph: row.glyph, urgency: row.urgency, timestamp: row.timestamp,
        originalId: row.originalId, sourceIndex: i })
    }
    return rows
  }

  function refresh() {
    reloadHistory()
    if (!notificationService || !nightlightService) request("status", "")
  }
  function reloadHistory() {
    if (!active || pluginDir === "") return
    if (historyReader.running) { reloadPending = true; return }
    reloadPending = false
    historyReader.epoch = historyEpoch
    historyReader.launchPending = true
    historyReader.running = true
  }
  function scheduleReload() { if (active) refreshDelay.restart() }
  function applyHistory(raw) {
    historyEntries = NotificationHistory.parseHistory(raw, 12)
    historyLoaded = true
    historyError = ""
  }
  function stopHistoryReader() {
    historyLifecycleBackstop.stop()
    historyEpoch++
    if (historyReader.running) {
      historyReader.running = false
      historyForceStopDelay.restart()
    }
  }
  function request(action, value) {
    if (commandRunner.running || pluginDir === "") return false
    notice = ""
    commandRunner.action = action
    commandRunner.value = value || ""
    commandRunner.launchPending = true
    commandRunner.running = true
    return true
  }
  function toggleDnd() {
    if (!active || busy || !dndAvailable) return
    if (notificationService) notificationService.setDoNotDisturb(!dnd)
    else request("dnd", dnd ? "off" : "on")
  }
  function toggleNightlight() {
    if (!active || busy || !nightAvailable) return
    if (nightlightService) nightlightService.setNightlight(!night)
    else request("night", night ? "off" : "on")
  }
  function clearAll() {
    if (!active || busy || !dndAvailable) return
    if (notificationService) {
      notificationService.clearPopups()
      notificationService.clearHistory()
      historyEpoch++
      historyEntries = []
      scheduleReload()
    } else request("clear", "")
  }
  function openApp(entry) {
    if (!active || busy || !entry) return
    // Native indices change when other notifications arrive or expire. Resolve
    // by identity at the moment of activation, never reuse a displayed index.
    var model = notificationService ? notificationService.popupModel : null
    if (entry.live && model) {
      for (var i = 0; i < model.count; i++) {
        if (NotificationHistory.entryKey(model.get(i)) !== NotificationHistory.entryKey(entry)) continue
        notificationService.invokePopupDefault(i)
        appOpened()
        scheduleReload()
        return
      }
    }
    if (notificationService) { notificationService.focusApp(entry); appOpened() }
    else request("focus", entry.app)
  }

  onActiveChanged: {
    if (active) { notice = ""; refresh() }
    else { refreshDelay.stop(); reloadPending = false; stopHistoryReader() }
  }
  onPluginDirChanged: if (active && pluginDir !== "") Qt.callLater(refresh)
  Connections {
    target: root.notificationService && root.notificationService.popupModel ? root.notificationService.popupModel : null
    ignoreUnknownSignals: true
    function onDataChanged() { root.liveRevision++; root.scheduleReload() }
    function onCountChanged() { root.liveRevision++; root.scheduleReload() }
  }

  // Qt watches only while the drawer is open. Content is read by the bounded
  // helper; folder entries never become notification rows or action arguments.
  Loader {
    active: root.active && root.pluginDir !== "" && Quickshell.env("HOME") !== ""
    sourceComponent: Component {
      Item {
        FileView {
          path: root.historyDir
          preload: false
          watchChanges: true
          printErrors: false
          onFileChanged: root.scheduleReload()
        }
        FileView {
          path: root.popupDir
          preload: false
          watchChanges: true
          printErrors: false
          onFileChanged: root.scheduleReload()
        }
        Repeater {
          model: root.historyEntries
          delegate: Item {
            required property var modelData
            FileView {
              // Names come from the validated helper, never a sender-supplied
              // path. Watch only: the bounded helper owns every content read.
              path: modelData.fileName ? (modelData.live ? root.popupDir : root.historyDir) + "/" + modelData.fileName : ""
              preload: false
              watchChanges: true
              printErrors: false
              onFileChanged: root.scheduleReload()
            }
          }
        }
      }
    }
  }

  FileView {
    path: root.active && !root.notificationService && root.pluginDir !== "" ? root.stateDir + "/notifications.json" : ""
    watchChanges: true
    preload: false
    printErrors: false
    onFileChanged: if (root.active) root.request("status", "")
  }
  Timer { id: refreshDelay; interval: 150; onTriggered: root.reloadHistory() }

  Process {
    id: historyReader
    objectName: "notificationHistoryReader"
    property bool launchPending: false
    property int epoch: 0
    command: ["/usr/bin/timeout", "--signal=TERM", "--kill-after=1s", "2s",
      root.pluginDir + "/scripts/notification-history", root.historyDir, root.popupDir]
    stdout: BoundedOutputParser { id: historyOutput; maxBytes: 128 * 1024 }
    onStarted: { launchPending = false; historyOutput.reset(); historyLifecycleBackstop.restart() }
    onRunningChanged: if (!running && launchPending) finish(-1)
    onExited: function(exitCode) { finish(exitCode) }
    function finish(exitCode) {
      launchPending = false
      historyLifecycleBackstop.stop()
      historyForceStopDelay.stop()
      if (root.active && epoch === root.historyEpoch) {
        if (exitCode === 0 && !historyOutput.truncated) root.applyHistory(historyOutput.text)
        else { root.historyLoaded = true; root.historyError = "Couldn’t refresh notifications. Try again." }
      }
      if (root.active && root.reloadPending) Qt.callLater(root.reloadHistory)
    }
  }
  Timer {
    id: historyLifecycleBackstop; interval: 3000
    onTriggered: {
      root.historyLoaded = true
      root.historyError = "Couldn’t refresh notifications. Try again."
      root.stopHistoryReader()
    }
  }
  Timer { id: historyForceStopDelay; interval: 500; onTriggered: if (historyReader.running) historyReader.signal(9) }

  Process {
    id: commandRunner
    objectName: "notificationCommandRunner"
    property string action: ""
    property string value: ""
    property bool launchPending: false
    command: ["/usr/bin/timeout", "--signal=TERM", "--kill-after=1s", "10s",
      "/usr/bin/python3", root.pluginDir + "/scripts/notification_control.py", action, value]
    stdout: BoundedOutputParser { id: commandOutput; maxBytes: 8192 }
    onStarted: { launchPending = false; commandOutput.reset(); commandBackstop.restart() }
    onRunningChanged: if (!running && launchPending) finish(-1)
    onExited: function(exitCode) { finish(exitCode) }
    function finish(exitCode) {
      launchPending = false
      commandBackstop.stop()
      commandKillDelay.stop()
      var result = null
      try { result = JSON.parse(commandOutput.text) } catch (_) {}
      if (exitCode !== 0 || commandOutput.truncated || !result || result.ok !== true) {
        if (action === "status") root.controlState = { dndAvailable: false, nightAvailable: false, dnd: false, night: false }
        else root.notice = action === "focus" ? "No open window found for this app." : "That change didn’t finish. Try again."
        return
      }
      if (action === "status") root.controlState = result
      else if (action === "clear") { root.historyEpoch++; root.historyEntries = []; root.scheduleReload() }
      else if (action === "focus" && root.active) root.appOpened()
      else {
        var updated = Object.assign({}, root.controlState)
        updated[action] = value === "on"
        root.controlState = updated
      }
    }
  }
  Timer {
    id: commandBackstop; interval: 11000
    onTriggered: { commandRunner.running = false; commandKillDelay.restart() }
  }
  Timer { id: commandKillDelay; interval: 500; onTriggered: if (commandRunner.running) commandRunner.signal(9) }
  Component.onCompleted: if (active) refresh()
  Component.onDestruction: { stopHistoryReader(); commandRunner.running = false }
}
