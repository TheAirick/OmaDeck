import QtQuick
import Quickshell
import Quickshell.Io
import "MonitorInputPolicy.js" as Policy

Item {
  id: root
  property string pluginDir: ""
  readonly property string configDir: Quickshell.env("HOME") + "/.config/omadeck"
  readonly property string settingsPath: configDir + "/monitors.json"
  property var settings: Policy.defaults()
  property bool loaded: false
  property bool directoryReady: false
  property bool saved: false
  property string confirmedText: ""
  property string notice: ""
  property string switchStatus: ""
  property var detectedMonitors: []
  property bool scanned: false
  property string operation: ""
  property bool launchPending: false
  property var setupStatus: null
  property bool setupWindowOpened: false
  readonly property bool busy: worker.running || launchPending
  readonly property bool showControls: loaded && settings.enabled && settings.monitors.length > 0
  readonly property var monitors: settings.monitors
  readonly property var selectedMonitor: monitors.find(function(row) { return row.id === root.settings.selectedId }) || null

  function snapshot() { return Policy.normalize(settings) }
  function commit(next) {
    if (!loaded || !directoryReady || busy) return false
    var normalized = Policy.normalize(next)
    if (!normalized) { notice = "Choose one to four inputs per monitor"; return false }
    var text = JSON.stringify(normalized, null, 2) + "\n"
    saved = text === confirmedText
    if (!saved) {
      try { settingsFile.setText(text) } catch (error) { saved = false }
    }
    if (!saved) { notice = "Could not save monitor settings"; return false }
    confirmedText = text
    settings = normalized
    notice = "Saved"
    return true
  }
  function setShown(value) { var next = snapshot(); next.enabled = value; return commit(next) }
  function selectMonitor(id) {
    if (!monitors.some(function(row) { return row.id === id })) return false
    var next = snapshot(); next.selectedId = id; return commit(next)
  }
  function cycleMonitor(delta) {
    if (!monitors.length) return false
    var index = monitors.findIndex(function(row) { return row.id === root.settings.selectedId })
    return selectMonitor(monitors[(index + delta + monitors.length) % monitors.length].id)
  }
  function addMonitor(id) {
    var detected = detectedMonitors.find(function(row) { return row.id === id })
    if (!detected || detected.error || !detected.inputs.length || monitors.some(function(row) { return row.id === id })) return false
    var next = snapshot()
    next.monitors.push({ id: id, label: detected.label, sources: detected.inputs.slice(0, 2) })
    next.selectedId = id
    return commit(next)
  }
  function removeMonitor(id) {
    var next = snapshot(); next.monitors = next.monitors.filter(function(row) { return row.id !== id }); return commit(next)
  }
  function setSource(id, code, shown, name) {
    var next = snapshot(), monitor = next.monitors.find(function(row) { return row.id === id })
    if (!monitor) return false
    var source = monitor.sources.find(function(row) { return row.code === code })
    if (shown) {
      var detected = detectedMonitors.find(function(row) { return row.id === id })
      var candidate = detected ? detected.inputs.find(function(row) { return row.code === code }) : null
      if (!source && !candidate) return false
      if (source) source.label = name || source.label
      else monitor.sources.push({ code: candidate.code, label: name || candidate.label })
    } else monitor.sources = monitor.sources.filter(function(row) { return row.code !== code })
    return commit(next)
  }
  function scan() { return start("scan", []) }
  function checkSetup() { return start("check", []) }
  function openSetup() {
    if (busy || !pluginDir || !setupStatus || !setupStatus.canPrepare || setupStatus.state === "ready") return false
    Quickshell.execDetached(["/usr/bin/omarchy", "launch", "terminal", "/usr/bin/python3", pluginDir + "/scripts/monitor_setup.py", "prepare"])
    setupWindowOpened = true
    notice = "Finish the setup window on your desktop, then tap Check again"
    return true
  }
  function switchInput(id, code) {
    var monitor = monitors.find(function(row) { return row.id === id })
    if (!showControls || !monitor || !monitor.sources.some(function(row) { return row.code === code })) return false
    return start("switch", [id, code])
  }
  function start(kind, extraArgs) {
    if (busy || !pluginDir) return false
    operation = kind
    notice = kind === "check" ? "Checking this computer…" : kind === "scan" ? "Finding monitors…" : "Switching input…"
    if (kind === "scan") { scanned = false; detectedMonitors = [] }
    if (kind === "check") { setupStatus = null; setupWindowOpened = false }
    if (kind === "switch") { statusClear.stop(); switchStatus = notice }
    worker.command = ["/usr/bin/timeout", "--kill-after=1s", "22s", "/usr/bin/python3",
      pluginDir + (kind === "check" ? "/scripts/monitor_setup.py" : "/scripts/monitor_inputs.py"), kind].concat(extraArgs)
    launchPending = true
    worker.running = true
    return true
  }
  function finish(code) {
    if (!launchPending && operation === "") return
    launchPending = false
    var result
    try { result = JSON.parse(output.text) } catch (error) { result = null }
    if (code === 0 && result && result.ok) {
      if (operation === "check") {
        setupStatus = result
        setupWindowOpened = false
        notice = result.state === "ready" ? "Computer ready" : "Computer setup needed"
      } else if (operation === "scan") {
        detectedMonitors = result.monitors || []
        scanned = true
        notice = detectedMonitors.length ? "Choose your monitor" : "No controllable monitors found"
      } else notice = "Input switch requested"
    } else notice = result && result.error ? result.error
      : operation === "check" ? "Could not check this computer. Try again." : "Monitor request failed or timed out"
    if (operation === "switch") { switchStatus = notice; statusClear.restart() }
    operation = ""
  }
  Timer { id: statusClear; interval: 6000; onTriggered: root.switchStatus = "" }
  Process {
    id: worker
    onStarted: root.launchPending = false
    onRunningChanged: if (!running && root.launchPending) root.finish(-1)
    onExited: function(code) { root.finish(code) }
    stdout: StdioCollector { id: output }
  }
  Process {
    id: mkdirProcess
    command: ["/usr/bin/mkdir", "-p", root.configDir]
    onExited: function(code) { root.directoryReady = code === 0; settingsFile.reload() }
  }
  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    blockWrites: true
    printErrors: false
    onSaved: root.saved = true
    onSaveFailed: { root.saved = false; root.confirmedText = "" }
    onLoaded: {
      var parsed = Policy.parse(text())
      root.settings = parsed || Policy.defaults()
      root.confirmedText = parsed ? text() : ""
      root.loaded = true
      if (!parsed) root.notice = "Monitor settings could not be read; switching is disabled"
    }
    onLoadFailed: { root.settings = Policy.defaults(); root.confirmedText = ""; root.loaded = true }
    onFileChanged: reload()
  }
  Component.onCompleted: mkdirProcess.running = true
  Component.onDestruction: worker.running = false
}
