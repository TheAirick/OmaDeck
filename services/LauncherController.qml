import QtQuick
import Quickshell
import Quickshell.Io
import "LauncherPolicy.js" as LauncherPolicy

Item {
  id: root

  readonly property string configDir: Quickshell.env("HOME") + "/.config/omadeck"
  readonly property string settingsPath: configDir + "/launcher-v2.json"

  property var customEntries: []
  property string actionNotice: ""
  property string pluginDir: ""
  readonly property bool launching: launchProcess.running

  property var entryIds: LauncherPolicy.DEFAULT_IDS.slice()
  property int revision: 0
  property bool loaded: false
  property bool directoryReady: false
  // Pending includes debounce, in-flight writes and failed unsaved edits.
  property bool savePending: false
  property string saveError: ""
  property bool saveInFlight: false
  property int savingRevision: -1
  property string savedText: ""
  property string savingText: ""

  function entries() { return LauncherPolicy.entries(entryIds, customEntries) }
  function availableEntries() { return LauncherPolicy.available(entryIds, customEntries) }
  function entryForId(id) { return LauncherPolicy.entryForId(id, customEntries) }

  function load(raw) {
    if (savePending || saveInFlight) return
    savedText = raw
    var parsed = LauncherPolicy.parseData(raw)
    if (parsed === null) {
      console.warn("OmaDeck: invalid launcher settings, using defaults")
      customEntries = []
      entryIds = LauncherPolicy.DEFAULT_IDS.slice()
      loaded = true
      revision++
      scheduleSave()
      return
    }
    customEntries = parsed.custom
    entryIds = parsed.entries
    loaded = true
    revision++
  }

  function commit(nextIds) {
    entryIds = nextIds
    revision++
    scheduleSave()
  }

  function add(id) { commit(LauncherPolicy.add(entryIds, id, customEntries)) }
  function remove(id) {
    var next = LauncherPolicy.remove(entryIds, id, customEntries)
    customEntries = customEntries.filter(function(entry) { return entry.id !== id })
    commit(next)
  }
  function saveCommand(draft, id) {
    var error = LauncherPolicy.commandError(draft)
    if (error) return error
    if (!id && entryIds.length >= LauncherPolicy.MAX_ENTRIES) return "Remove a button before adding another."
    if (id && !customEntries.some(function(entry) { return entry.id === id })) return "This button no longer exists."
    var key = id || "custom:" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 10)
    var next = customEntries.filter(function(entry) { return entry.id !== key })
    next.push(Object.assign({}, draft, { id: key }))
    customEntries = LauncherPolicy.normalizeCommands(next)
    commit(LauncherPolicy.add(entryIds, key, customEntries))
    return ""
  }
  function runCommand(id) {
    if (launching || pluginDir === "") return false
    if (savePending || saveInFlight || saveError) { actionNotice = "Save your changes before running this button."; return false }
    var entry = entryForId(id)
    if (!entry || entry.kind !== "command") return false
    actionNotice = "Starting…"
    launchProcess.command = ["/usr/bin/timeout", "--signal=TERM", "--kill-after=1s", "3s", "/usr/bin/python3",
      pluginDir + "/scripts/launcher-command", settingsPath, id]
    launchProcess.launchPending = true
    launchProcess.running = true
    return true
  }
  function move(id, delta) { commit(LauncherPolicy.move(entryIds, id, delta, customEntries)) }

  function scheduleSave() {
    savePending = true
    if (directoryReady) saveDelay.restart()
  }

  function persist() {
    if (!directoryReady) {
      if (!mkdirProcess.running) {
        mkdirProcess.launchPending = true
        mkdirProcess.running = true
      }
      return
    }
    if (!savePending || saveInFlight) return
    saveDelay.stop()
    savingText = JSON.stringify(LauncherPolicy.snapshot(entryIds, customEntries), null, 2) + "\n"
    if (saveError === "" && savingText === savedText) {
      savePending = false
      return
    }
    savingRevision = revision
    saveInFlight = true
    // Failed writes remain cached by FileView 0.3.1; an identical retry would
    // otherwise silently do nothing. Unload before retrying the same payload.
    if (saveError !== "") {
      settingsFile.path = ""
      settingsFile.path = settingsPath
    }
    try {
      settingsFile.setText(savingText)
    } catch (error) {
      saveInFlight = false
      saveError = String(error)
    }
  }

  Process {
    id: mkdirProcess
    command: ["/usr/bin/mkdir", "-p", root.configDir]
    property bool launchPending: true
    onStarted: launchPending = false
    onRunningChanged: {
      if (!running && launchPending) finishDirectory(-1)
    }
    onExited: function(exitCode) { finishDirectory(exitCode) }
    function finishDirectory(exitCode) {
      launchPending = false
      root.directoryReady = exitCode === 0
      if (!root.directoryReady) {
        root.loaded = true
        root.saveError = "Settings directory unavailable"
        return
      }
      if (root.savePending) saveDelay.restart()
      else {
        root.saveError = ""
        settingsFile.reload()
      }
    }
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onSaved: {
      root.savedText = root.savingText
      root.saveInFlight = false
      root.savePending = root.revision !== root.savingRevision
      root.saveError = ""
      if (root.savePending) saveDelay.restart()
    }
    onSaveFailed: function(error) {
      root.saveInFlight = false
      root.saveError = String(error)
    }
    onLoaded: root.load(text())
    onLoadFailed: {
      root.savedText = ""
      if (!root.directoryReady) return
      if (!root.loaded) { legacyFile.path = root.configDir + "/launcher.json"; legacyFile.reload() }
      else root.scheduleSave()
    }
    onFileChanged: reload()
  }

  // Migrate once into a separate file. Older releases keep their original
  // ordering and cannot erase custom command definitions during rollback.
  FileView {
    id: legacyFile
    printErrors: false
    onLoaded: { if (!root.loaded) { root.load(text()); root.scheduleSave() } }
    onLoadFailed: { if (!root.loaded) { root.loaded = true; root.scheduleSave() } }
  }
  Process {
    id: launchProcess
    property bool launchPending: false
    onStarted: launchPending = false
    onRunningChanged: if (!running && launchPending) { launchPending = false; root.actionNotice = "Couldn’t start the command launcher." }
    onExited: function(exitCode) {
      root.actionNotice = exitCode === 0 ? "Started" : "Couldn’t start. Check the command and working folder."
    }
  }

  onActionNoticeChanged: { noticeDelay.stop(); if (actionNotice === "Started") noticeDelay.restart() }
  Timer { id: noticeDelay; interval: 2500; onTriggered: root.actionNotice = "" }

  Timer { id: saveDelay; interval: 180; repeat: false; onTriggered: root.persist() }

  Timer {
    interval: 5000
    running: root.saveError !== "" && !root.saveInFlight
    repeat: true
    onTriggered: root.persist()
  }

  Component.onCompleted: mkdirProcess.running = true
}
