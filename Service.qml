import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "services"

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string targetScreen: "DP-3"
  property string primaryMonitor: "DP-1"
  property var touchDeviceNames: ["WCH.CN", "XENEON"]
  property var activeSurface: null
  readonly property string pluginDir: {
    if (manifest && manifest.__sourceDir) return String(manifest.__sourceDir)
    var resolved = String(Qt.resolvedUrl("."))
    return resolved.replace(/^file:\/\//, "").replace(/\/$/, "")
  }
  readonly property var targetScreens: {
    var screens = Quickshell.screens || []
    var matches = []
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].name === targetScreen) matches.push(screens[i])
    }
    return matches
  }

  function registerSurface(surface) {
    if (surface) activeSurface = surface
  }

  function unregisterSurface(surface) {
    if (activeSurface === surface) activeSurface = null
  }

  LayoutController {
    id: layoutStore
  }

  AppearanceController {
    id: appearanceStore
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
    running: root.pluginDir !== ""
  }

  IpcHandler {
    target: "pretty.omadeck"

    function drawer(edge: string): void {
      if (!root.activeSurface) return
      if (["left", "right", "top", "bottom"].indexOf(edge) !== -1)
        root.activeSurface.toggleDrawer(edge)
    }

    function closeDrawer(): void {
      if (root.activeSurface) root.activeSurface.closeDrawer()
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
        devicePath: "",
        configuredDeviceNames: root.touchDeviceNames,
        status: "Target monitor unavailable"
      })
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
      layoutController: layoutStore
      appearanceController: appearanceStore
      weatherController: weatherStore
    }
  }
}
