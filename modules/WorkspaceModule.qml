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
  property bool expandToFit: false
  property string primaryMonitor: "DP-1"
  readonly property real workspaceScale: Math.min(expandToFit ? 1.85 : 1,
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
      "/usr/bin/hyprctl", "dispatch",
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

      BorderSurface {
        id: workspaceTile
        required property int index

        readonly property int workspaceId: index + 1
        readonly property var workspace: root.workspaceById(workspaceId)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === workspaceId

        implicitWidth: root.compact ? Style.space(38) : Style.space(54)
        implicitHeight: root.compact ? Style.space(38) : Style.space(54)
        radius: Style.cornerRadius
        color: workspaceTap.pressed
          ? Style.pressedFillFor(Color.foreground, Color.accent)
          : focused
          ? Style.selectedFillFor(Color.foreground, Color.accent)
          : workspaceHover.hovered
          ? Style.hoverFillFor(Color.foreground, Color.accent)
          : "transparent"
        borderSpec: focused
          ? Border.hyprlandActiveSpec(Color.accent, 2)
          : workspaceHover.hovered
          ? Border.controlSpec("hover-cursor", Color.foreground, Color.accent, Color.urgent)
          : Border.none()

        Text {
          anchors.centerIn: parent
          text: workspaceTile.workspaceId === 10 ? "0" : String(workspaceTile.workspaceId)
          color: workspaceTile.focused
            ? Style.selectedStateColor(Color.foreground, Color.accent, Color.urgent)
            : workspaceTile.occupied ? Color.foreground : Color.muted
          opacity: workspaceTile.focused || workspaceTile.occupied ? 1 : 0.58
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: workspaceTile.focused
        }

        // HoverHandler ignores non-hovering touchscreens, so a tap cannot
        // leave the synthetic mouse hover painted until a real mouse moves.
        HoverHandler { id: workspaceHover }
        TapHandler {
          id: workspaceTap
          onTapped: root.focusWorkspace(workspaceTile.workspaceId)
        }
      }
    }
  }
}
