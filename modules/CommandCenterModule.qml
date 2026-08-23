import QtQuick
import qs.Commons
import "../components"

Item {
  id: root

  property var deck: null
  property var controller: null

  Grid {
    anchors.centerIn: parent
    columns: 2
    spacing: Style.spacing.panelGap

    DrawerButton { edge: "left"; label: "Media"; iconText: "󰝚"; onTriggered: if (root.deck) root.deck.toggleDrawer(edge) }
    DrawerButton { edge: "right"; label: "Agents"; iconText: "󰚩"; onTriggered: if (root.deck) root.deck.toggleDrawer(edge) }
    DrawerButton { edge: "top"; label: "Workspaces"; iconText: "󰍹"; onTriggered: if (root.deck) root.deck.toggleDrawer(edge) }
    DrawerButton { edge: "bottom"; label: "Applications"; iconText: "󰀻"; onTriggered: if (root.deck) root.deck.toggleDrawer(edge) }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.spacing.panelGap
    text: root.controller && root.controller.editMode
      ? "Edit mode · drag modules or dividers · tap Done when finished"
      : "Hold any module to edit · swipe from any edge"
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
}
