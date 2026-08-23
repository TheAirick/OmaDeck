import QtQuick
import Quickshell
import "components"
import "services"

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string targetScreen: "DP-3"
  property string primaryMonitor: "DP-1"
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

  Variants {
    model: root.targetScreens

    DeckSurface {
      required property var modelData

      screen: modelData
      shell: root.shell
      pluginRoot: root
      targetScreen: root.targetScreen
      primaryMonitor: root.primaryMonitor
      layoutController: layoutStore
    }
  }
}
