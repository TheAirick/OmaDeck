import QtQuick
import Quickshell
import Quickshell.Io
import "LauncherPolicy.js" as LauncherPolicy

Item {
  id: root

  readonly property string configDir: Quickshell.env("HOME") + "/.config/omadeck"
  readonly property string settingsPath: configDir + "/launcher.json"

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

  function entries() { return LauncherPolicy.entries(entryIds) }
  function availableEntries() { return LauncherPolicy.available(entryIds) }
  function entryForId(id) { return LauncherPolicy.entryForId(id) }

  function load(raw) {
    if (savePending || saveInFlight) return
    savedText = raw
    var parsed = LauncherPolicy.parseSettings(raw)
    if (parsed === null) {
      console.warn("OmaDeck: invalid launcher settings, using defaults")
      entryIds = LauncherPolicy.DEFAULT_IDS.slice()
      loaded = true
      revision++
      scheduleSave()
      return
    }
    entryIds = parsed
    loaded = true
    revision++
  }

  function commit(nextIds) {
    entryIds = nextIds
    revision++
    scheduleSave()
  }

  function add(id) { commit(LauncherPolicy.add(entryIds, id)) }
  function remove(id) { commit(LauncherPolicy.remove(entryIds, id)) }
  function move(id, delta) { commit(LauncherPolicy.move(entryIds, id, delta)) }

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
    savingText = JSON.stringify(LauncherPolicy.snapshot(entryIds), null, 2) + "\n"
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
      root.loaded = true
      root.scheduleSave()
    }
    onFileChanged: reload()
  }

  Timer { id: saveDelay; interval: 180; repeat: false; onTriggered: root.persist() }

  Timer {
    interval: 5000
    running: root.saveError !== "" && !root.saveInFlight
    repeat: true
    onTriggered: root.persist()
  }

  Component.onCompleted: mkdirProcess.running = true
}
