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

  Variants {
    model: root.targetScreens

    DeckSurface {
      required property var modelData

      screen: modelData
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
