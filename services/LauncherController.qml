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

  function entries() { return LauncherPolicy.entries(entryIds) }
  function availableEntries() { return LauncherPolicy.available(entryIds) }
  function entryForId(id) { return LauncherPolicy.entryForId(id) }

  function load(raw) {
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
    if (directoryReady) saveDelay.restart()
  }

  function persist() {
    if (!directoryReady) return
    settingsFile.setText(JSON.stringify(LauncherPolicy.snapshot(entryIds), null, 2) + "\n")
  }

  Process {
    id: mkdirProcess
    command: ["/usr/bin/mkdir", "-p", root.configDir]
    onExited: {
      root.directoryReady = true
      settingsFile.reload()
    }
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: {
      if (!root.directoryReady) return
      root.loaded = true
      root.persist()
    }
    onFileChanged: reload()
  }

  Timer { id: saveDelay; interval: 180; repeat: false; onTriggered: root.persist() }

  Component.onCompleted: mkdirProcess.running = true
}
