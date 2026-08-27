import QtQuick
import qs.Commons
import "../components"

Item {
  id: root

  property var deck: null
  property var controller: null
  readonly property bool pointerRevealed: drawerHover.hovered
  readonly property bool controlsRevealed: pointerRevealed
    || (controller && controller.editMode)
  readonly property real contentScale: Math.min(1,
    Math.max(0, width - Style.spacing.panelGap * 2) / Math.max(1, controlStack.implicitWidth),
    Math.max(0, height - Style.spacing.panelGap * 2) / Math.max(1, controlStack.implicitHeight))

  Column {
    id: controlStack
    anchors.centerIn: parent
    spacing: Style.spacing.panelGap
    scale: root.contentScale
    transformOrigin: Item.Center

    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Grid {
      id: drawerControls
      columns: 2
      rowSpacing: Style.spacing.panelGap
      columnSpacing: Style.spacing.panelGap
      opacity: root.controlsRevealed ? 1 : 0
      enabled: root.controlsRevealed

      Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

      DrawerButton {
        edge: "left"; label: "Media"; iconText: "󰝚"
        selected: root.deck && root.deck.openDrawer === edge
        onTriggered: if (root.deck) root.deck.toggleDrawer(edge)
      }
      DrawerButton {
        edge: "right"; label: "System"; iconText: "󰍛"
        selected: root.deck && root.deck.openDrawer === edge
        onTriggered: if (root.deck) root.deck.toggleDrawer(edge)
      }
      DrawerButton {
        edge: "top"; label: "Workspaces"; iconText: "󰍹"
        selected: root.deck && root.deck.openDrawer === edge
        onTriggered: if (root.deck) root.deck.toggleDrawer(edge)
      }
      DrawerButton {
        edge: "bottom"; label: "Applications"; iconText: "󰀻"
        selected: root.deck && root.deck.openDrawer === edge
        onTriggered: if (root.deck) root.deck.toggleDrawer(edge)
      }
    }

    MonitorInputModule {
      width: drawerControls.width
    }
  }

  Text {
    id: interactionHint
    visible: root.height > Style.space(300)
    opacity: root.controlsRevealed ? 1 : 0
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.spacing.panelGap
    text: root.controller && root.controller.editMode
      ? "Edit mode · drag modules or dividers · tap Done when finished"
      : "Swipe down for workspaces · swipe up for applications"
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  }

  HoverHandler { id: drawerHover }
}
