import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "services"
import "services/TimerPolicy.js" as TimerPolicy

Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property string targetScreen: hardwareStore.targetScreen
  readonly property string primaryMonitor: hardwareStore.primaryMonitor
  readonly property var touchDeviceNames: hardwareStore.touchDeviceNames
  property var activeSurface: null
  property bool unloading: false
  property int trayRestartFailures: 0
  readonly property string pluginDir: {
    if (manifest && manifest.__sourceDir) return String(manifest.__sourceDir)
    var resolved = String(Qt.resolvedUrl("."))
    return resolved.replace(/^file:\/\//, "").replace(/\/$/, "")
  }
  readonly property var targetScreens: {
    if (!layoutStore.loaded || !hardwareStore.loaded) return []
    var screens = Quickshell.screens || []
    var matches = []
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].name === targetScreen) matches.push(screens[i])
    }
    return matches
  }
  readonly property var availableScreenNames: {
    var screens = Quickshell.screens || []
    var names = []
    for (var i = 0; i < screens.length; i++) names.push(String(screens[i].name))
    names.sort()
    return names
  }

  function registerSurface(surface) {
    if (!surface) return
    activeSurface = surface
    hardwareStore.availableTouchDeviceNames = surface.availableTouchDeviceNames
  }

  function unregisterSurface(surface) {
    if (activeSurface !== surface) return
    activeSurface = null
    hardwareStore.availableTouchDeviceNames = []
  }

  function startTray() {
    if (unloading || pluginDir === "" || !hardwareStore.loaded || trayController.running) return
    trayController.running = true
  }

  function restartTrayForHardwareChange() {
    if (!hardwareStore.loaded || unloading) return
    if (trayController.running) stopTray()
    else Qt.callLater(root.startTray)
  }

  function stopTray() {
    trayRestartDelay.stop()
    trayStableDelay.stop()
    if (!trayController.running) return
    trayController.running = false
    if (!unloading) trayForceStopDelay.restart()
  }

  Component.onCompleted: Qt.callLater(root.startTray)
  Component.onDestruction: {
    unloading = true
    stopTray()
  }
  onPluginDirChanged: {
    if (pluginDir === "") stopTray()
    else Qt.callLater(root.startTray)
  }
  onTargetScreenChanged: root.restartTrayForHardwareChange()
  onPrimaryMonitorChanged: root.restartTrayForHardwareChange()
  onTouchDeviceNamesChanged: root.restartTrayForHardwareChange()

  Connections {
    target: root.activeSurface
    function onAvailableTouchDeviceNamesChanged() {
      hardwareStore.availableTouchDeviceNames = root.activeSurface
        ? root.activeSurface.availableTouchDeviceNames : []
    }
  }

  LayoutController {
    id: layoutStore
  }

  HardwareController {
    id: hardwareStore
    availableScreenNames: root.availableScreenNames
    onLoadedChanged: if (loaded) Qt.callLater(root.startTray)
  }

  AppearanceController {
    id: appearanceStore
  }

  LauncherController {
    id: launcherStore
  }

  TimerController {
    id: timerStore
  }

  WeatherController {
    id: weatherStore
    pluginDir: root.pluginDir
    enabled: appearanceStore.loaded && appearanceStore.showWeather
  }

  Process {
    id: trayController
    command: [root.pluginDir + "/scripts/run-tray", root.pluginDir,
              root.targetScreen, root.primaryMonitor].concat(root.touchDeviceNames)
    onStarted: trayStableDelay.restart()
    onExited: function(exitCode, exitStatus) {
      trayStableDelay.stop()
      trayForceStopDelay.stop()
      if (root.unloading || root.pluginDir === "") return
      // A missing optional tray exits successfully. Do not turn that standard
      // install mode into a keep-loaded polling loop.
      if (exitCode === 0) {
        root.trayRestartFailures = 0
        return
      }
      root.trayRestartFailures = Math.min(root.trayRestartFailures + 1, 6)
      trayRestartDelay.interval = Math.min(30000,
                                           1000 * Math.pow(2, root.trayRestartFailures - 1))
      trayRestartDelay.restart()
    }
  }

  Timer {
    id: trayStableDelay
    interval: 30 * 1000
    repeat: false
    onTriggered: root.trayRestartFailures = 0
  }

  Timer {
    id: trayRestartDelay
    interval: 1000
    repeat: false
    onTriggered: root.startTray()
  }

  Timer {
    id: trayForceStopDelay
    interval: 750
    repeat: false
    onTriggered: if (trayController.running) trayController.signal(9)
  }

  IpcHandler {
    target: "pretty.omadeck"

    function drawer(edge: string): void {
      if (!root.activeSurface) return
      if (["left", "right", "top", "bottom"].indexOf(edge) !== -1)
        root.activeSurface.toggleDrawer(edge)
    }

    function overlay(name: string): void {
      if (!root.activeSurface) return
      if (["notifications", "overview", "preferences"].indexOf(name) !== -1)
        root.activeSurface.openOverlay(name)
    }

    function page(name: string): void {
      if (root.activeSurface) root.activeSurface.setCommandCenterPage(name)
    }

    function closeDrawer(): void {
      if (root.activeSurface) root.activeSurface.closeDrawer()
    }

    function closeOverlay(): void {
      if (root.activeSurface) root.activeSurface.closeOverlay()
    }

    function drawerState(): string {
      if (root.activeSurface) return root.activeSurface.drawerState()
      return JSON.stringify({
        available: false,
        openDrawer: "",
        error: "Target monitor unavailable"
      })
    }

    function touchState(): string {
      if (root.activeSurface) return root.activeSurface.touchState()
      return JSON.stringify({
        active: false,
        exclusiveGrab: false,
        nativeAvailable: false,
        mode: "unavailable",
        devicePath: "",
        configuredDeviceNames: root.touchDeviceNames,
        status: "Target monitor unavailable"
      })
    }

    function hardwareState(): string {
      if (!hardwareStore.loaded)
        return JSON.stringify({ ok: false, error: "Hardware settings are not ready" })
      var state = hardwareStore.snapshot()
      state.availableScreenNames = hardwareStore.availableScreenNames
      state.availableTouchDeviceNames = hardwareStore.availableTouchDeviceNames
      state.selectedTouchDeviceName = hardwareStore.selectedTouchDeviceName
      state.ok = true
      return JSON.stringify(state)
    }

    function reconnectTouch(): string {
      if (!root.activeSurface)
        return JSON.stringify({ ok: false, error: "Target monitor unavailable" })
      root.activeSurface.reconnectTouch()
      return JSON.stringify({ ok: true })
    }

    function edit(enabled: bool): void {
      if (enabled) layoutStore.beginEdit("")
      else layoutStore.finishEdit()
    }

    function ratio(path: string, value: real): void {
      layoutStore.setRatio(path, value)
    }

    function appearanceState(): string {
      if (!appearanceStore.loaded)
        return JSON.stringify({ ok: false, error: "Appearance settings are not ready" })
      var state = appearanceStore.snapshot()
      state.ok = true
      return JSON.stringify(state)
    }

    function setAppearance(key: string, value: string): string {
      if (!appearanceStore.loaded)
        return JSON.stringify({ ok: false, error: "Appearance settings are not ready" })

      var booleanKeys = ["use24Hour", "showSeconds", "showWeather"]
      var stringKeys = ["clockStyle", "weatherStyle", "weatherDetail", "temperatureUnit"]
      if (booleanKeys.indexOf(key) === -1 && stringKeys.indexOf(key) === -1)
        return JSON.stringify({ ok: false, error: "Unknown appearance setting" })
      if (booleanKeys.indexOf(key) !== -1 && value !== "true" && value !== "false")
        return JSON.stringify({ ok: false, error: "Invalid boolean value" })

      var parsedValue = booleanKeys.indexOf(key) !== -1 ? value === "true" : value
      var persisted = appearanceStore.setOption(key, parsedValue)
      var state = appearanceStore.snapshot()
      if (!persisted)
        return JSON.stringify({ ok: false, error: "Appearance setting could not be saved", state: state })
      if (state[key] !== parsedValue)
        return JSON.stringify({ ok: false, error: "Appearance setting was rejected", state: state })
      return JSON.stringify({ ok: true, key: key, value: state[key], state: state })
    }

    function refreshWeather(): string {
      if (!appearanceStore.loaded)
        return JSON.stringify({ ok: false, error: "Appearance settings are not ready" })
      if (!appearanceStore.showWeather)
        return JSON.stringify({ ok: false, error: "Weather is disabled" })
      weatherStore.refresh()
      return JSON.stringify({ ok: true })
    }

    function timerState(): string {
      if (!timerStore.loaded)
        return JSON.stringify({ ok: false, error: "Timer state is not ready" })
      var state = timerStore.snapshot()
      state.ok = true
      return JSON.stringify(state)
    }

    function timerStart(hours: int, minutes: int): string {
      if (TimerPolicy.durationMs(hours, minutes) === null)
        return JSON.stringify({ ok: false, error: "Duration must be between 00:01 and 99:59" })
      return JSON.stringify(timerStore.start(hours, minutes))
    }

    function timerPause(): string {
      return JSON.stringify(timerStore.pause())
    }

    function timerResume(): string {
      return JSON.stringify(timerStore.resume())
    }

    function timerRestart(): string {
      return JSON.stringify(timerStore.restart())
    }

    function timerAdd(minutes: int): string {
      if (minutes !== 5)
        return JSON.stringify({ ok: false, error: "Only a 5 minute extension is supported" })
      return JSON.stringify(timerStore.add(minutes))
    }

    function timerCancel(): string {
      return JSON.stringify(timerStore.cancel())
    }

    function timerDismiss(): string {
      return JSON.stringify(timerStore.dismiss())
    }

    function system(section: string): void {
      if (root.activeSurface) root.activeSurface.showSystemSection(section)
    }

    function clipboard(index: int): void {
      if (root.activeSurface) root.activeSurface.showClipboardEntry(index)
    }

    function application(index: int): void {
      if (root.activeSurface) root.activeSurface.showApplication(index)
    }

    function systemBack(): void {
      if (root.activeSurface) root.activeSurface.systemBack()
    }

    function clipboardCopy(): void {
      if (root.activeSurface) root.activeSurface.clipboardCopy()
    }

    function clipboardDelete(): void {
      if (root.activeSurface) root.activeSurface.clipboardDelete()
    }

    function mediaCompact(compact: bool): void {
      if (root.activeSurface) root.activeSurface.setMediaCompact(compact)
    }

    function mediaCategory(category: string): void {
      if (root.activeSurface) root.activeSurface.setMediaCategory(category)
    }
  }

  Variants {
    model: root.targetScreens

    DeckSurface {
      required property var modelData

      screen: modelData
      serviceHost: root
      shell: root.shell
      pluginDir: root.pluginDir
      targetScreen: root.targetScreen
      primaryMonitor: root.primaryMonitor
      touchDeviceNames: root.touchDeviceNames
      hardwareController: hardwareStore
      layoutController: layoutStore
      appearanceController: appearanceStore
      launcherController: launcherStore
      weatherController: weatherStore
      timerController: timerStore
    }
  }
}
