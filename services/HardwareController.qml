import QtQuick
import Quickshell
import Quickshell.Io
import "HardwarePolicy.js" as HardwarePolicy

Item {
  id: root

  readonly property string configDir: Quickshell.env("HOME") + "/.config/omadeck"
  readonly property string settingsPath: configDir + "/hardware.json"

  property string targetScreen: HardwarePolicy.DEFAULT_TARGET_SCREEN
  property string primaryMonitor: HardwarePolicy.DEFAULT_PRIMARY_MONITOR
  property var touchDeviceNames: HardwarePolicy.DEFAULT_TOUCH_DEVICE_NAMES.slice()
  property var availableScreenNames: []
  property var availableTouchDeviceNames: []
  readonly property string selectedTouchDeviceName:
    HardwarePolicy.touchSelection(touchDeviceNames, availableTouchDeviceNames)
  property bool loaded: false
  property bool directoryReady: false
  property bool lastSaveSucceeded: false
  property string lastSaveError: ""

  function snapshot() {
    return HardwarePolicy.snapshot(targetScreen, primaryMonitor, touchDeviceNames)
  }

  function restoreSnapshot(state) {
    targetScreen = state.targetScreen
    primaryMonitor = state.primaryMonitor
    touchDeviceNames = state.touchDeviceNames.slice()
  }

  function load(raw) {
    var parsed = HardwarePolicy.parseSettings(raw)
    if (parsed === null) {
      console.warn("OmaDeck: invalid hardware settings, selecting connected screens")
      restoreSnapshot(HardwarePolicy.initialSnapshot(availableScreenNames))
      loaded = true
      scheduleSave()
      return
    }
    restoreSnapshot(parsed)
    loaded = true
  }

  function setTargetScreen(value) {
    if (!loaded || !directoryReady
        || !HardwarePolicy.includesExact(availableScreenNames, value)) return false
    return commit(function() { root.targetScreen = String(value) })
  }

  function setPrimaryMonitor(value) {
    if (!loaded || !directoryReady
        || !HardwarePolicy.includesExact(availableScreenNames, value)) return false
    return commit(function() { root.primaryMonitor = String(value) })
  }

  function setTouchDevice(value) {
    if (!loaded || !directoryReady
        || !HardwarePolicy.includesExact(availableTouchDeviceNames, value)) return false
    return commit(function() { root.touchDeviceNames = [String(value)] })
  }

  function commit(mutator) {
    var before = snapshot()
    if (before === null) return false
    saveDelay.stop()
    mutator()
    var next = snapshot()
    if (next === null || !persist()) {
      restoreSnapshot(before)
      return false
    }
    return true
  }

  function scheduleSave() {
    if (directoryReady) saveDelay.restart()
  }

  function persist() {
    if (!directoryReady) return false
    var state = snapshot()
    if (state === null) return false
    lastSaveSucceeded = false
    lastSaveError = ""
    try {
      settingsFile.setText(JSON.stringify(state, null, 2) + "\n")
    } catch (error) {
      lastSaveError = String(error)
      console.warn("OmaDeck: failed to persist hardware settings:", error)
    }
    return lastSaveSucceeded
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
    blockWrites: true
    printErrors: false
    onSaved: root.lastSaveSucceeded = true
    onSaveFailed: function(error) {
      root.lastSaveSucceeded = false
      root.lastSaveError = String(error)
    }
    onLoaded: root.load(text())
    onLoadFailed: {
      if (!root.directoryReady) return
      root.restoreSnapshot(HardwarePolicy.initialSnapshot(root.availableScreenNames))
      root.loaded = true
      root.persist()
    }
    onFileChanged: reload()
  }

  Timer { id: saveDelay; interval: 180; repeat: false; onTriggered: root.persist() }

  Component.onCompleted: mkdirProcess.running = true
}
