import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool compact: false
  property bool singleRow: false
  property string primaryMonitor: "DP-1"
  readonly property real workspaceScale: Math.min(1,
    Math.max(0, width - Style.spacing.controlGap * 2) / Math.max(1, workspaceGrid.implicitWidth),
    Math.max(0, height - Style.spacing.controlGap * 2) / Math.max(1, workspaceGrid.implicitHeight))

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
    id: workspaceGrid
    anchors.centerIn: parent
    columns: root.singleRow ? 10 : 5
    columnSpacing: Style.spacing.controlGap
    rowSpacing: Style.spacing.controlGap
    scale: root.workspaceScale
    transformOrigin: Item.Center

    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

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
