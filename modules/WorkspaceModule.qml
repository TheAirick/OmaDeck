import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool compact: false
  property string primaryMonitor: "DP-1"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) if (values[i].id === id) return values[i]
    return null
  }

  function luaString(value) {
    return "\"" + String(value || "").replace(/\\/g, "\\\\").replace(/\"/g, "\\\"") + "\""
  }

  function focusWorkspace(id) {
    Quickshell.execDetached([
      "hyprctl", "dispatch",
      "hl.dsp.focus({ workspace = " + luaString(String(id)) + " })"
    ])
  }

  GridLayout {
    anchors.centerIn: parent
    columns: 5
    columnSpacing: Style.spacing.controlGap
    rowSpacing: Style.spacing.controlGap

    Repeater {
      model: 10

      Button {
        required property int index

        readonly property int workspaceId: index + 1
        readonly property var workspace: root.workspaceById(workspaceId)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === workspaceId

        text: workspaceId === 10 ? "0" : String(workspaceId)
        foreground: Color.foreground
        selected: focused
        opacity: occupied || focused ? 1 : 0.48
        horizontalPadding: root.compact ? Style.spacing.controlPaddingX : Style.spacing.panelGap
        verticalPadding: root.compact ? Style.spacing.controlPaddingY : Style.spacing.rowPaddingX
        onClicked: root.focusWorkspace(workspaceId)
      }
    }
  }
}
