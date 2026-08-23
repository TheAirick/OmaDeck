import QtQuick
import qs.Commons
import "../components"

Item {
  id: root

  property var deck: null
  property var controller: null

  Column {
    anchors.centerIn: parent
    spacing: Style.spacing.panelGap

    Row {
      spacing: Style.spacing.panelGap

      DrawerButton { edge: "left"; label: "Media"; iconText: "󰝚"; onTriggered: if (root.deck) root.deck.toggleDrawer(edge) }
      DrawerButton { edge: "right"; label: "Agents"; iconText: "󰚩"; onTriggered: if (root.deck) root.deck.toggleDrawer(edge) }
    }

    MonitorInputModule {
      width: parent.width
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.spacing.panelGap
    text: root.controller && root.controller.editMode
      ? "Edit mode · drag modules or dividers · tap Done when finished"
      : "Swipe down for workspaces · swipe up for applications"
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
}
