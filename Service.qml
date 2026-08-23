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

  LayoutController {
    id: layoutStore
  }

  Variants {
    model: Quickshell.screens

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
