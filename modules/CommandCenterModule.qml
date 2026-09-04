import QtQuick
import qs.Commons
import "../components"

Item {
  id: root

  property var deck: null
  property var controller: null
  property var shell: null
  property var launcherController: null
  property string pluginDir: ""
  property string primaryMonitor: "DP-1"
  readonly property string page: deck ? deck.commandCenterPage : "home"
  readonly property real compactButtonWidth: Style.space(146)
  readonly property bool useThreeColumns: width >= compactButtonWidth * 3 + Style.spacing.panelGap * 4
  readonly property int columnCount: useThreeColumns ? 3 : 2
  readonly property real contentWidth: Math.min(
    Math.max(0, width - Style.spacing.panelGap * 2),
    useThreeColumns ? compactButtonWidth * 3 + Style.spacing.panelGap * 2 : Style.space(392))
  readonly property real buttonWidth: Math.max(Style.space(72),
    (contentWidth - Style.spacing.panelGap * (columnCount - 1)) / columnCount)
  readonly property real monitorHeight: useThreeColumns ? Style.space(92) : Style.space(76)
  readonly property real buttonHeight: useThreeColumns ? Style.space(92)
    : Math.max(Style.space(64), Math.min(Style.space(96),
      (height - monitorHeight - Style.spacing.panelGap * 3) / 3))
  // Retained as a public diagnostic contract. Controls now reflow instead of
  // shrinking uniformly when a drawer reserves part of the center canvas.
  readonly property real contentScale: 1

  Column {
    id: controlStack
    visible: root.page === "home"
    anchors.centerIn: parent
    width: root.contentWidth
    spacing: Style.spacing.panelGap

    Grid {
      id: drawerControls
      width: parent.width
      columns: root.columnCount
      rowSpacing: Style.spacing.panelGap
      columnSpacing: Style.spacing.panelGap
      move: Transition {
        NumberAnimation { properties: "x,y"; duration: 160; easing.type: Easing.OutCubic }
      }

      DrawerButton {
        width: root.buttonWidth; height: root.buttonHeight
        edge: "left"; label: "Volume"; iconText: "󰕾"
        onTriggered: if (root.deck) root.deck.toggleDrawer(edge)
      }
      DrawerButton {
        width: root.buttonWidth; height: root.buttonHeight
        edge: "right"; label: "System"; iconText: "󰍛"
        onTriggered: if (root.deck) root.deck.toggleDrawer(edge)
      }
      DrawerButton {
        width: root.buttonWidth; height: root.buttonHeight
        edge: "top"; label: "Notifications"; iconText: "󰂚"
        onTriggered: if (root.deck) root.deck.openOverlay("notifications")
      }
      DrawerButton {
        width: root.buttonWidth; height: root.buttonHeight
        edge: "bottom"; label: "Overview"; iconText: "󰖲"
        onTriggered: if (root.deck) root.deck.openOverlay("overview")
      }
      DrawerButton {
        width: root.buttonWidth; height: root.buttonHeight
        edge: "page"; label: "Applications"; iconText: "󰀻"
        onTriggered: if (root.deck) root.deck.setCommandCenterPage("applications")
      }
      DrawerButton {
        width: root.buttonWidth; height: root.buttonHeight
        edge: "preferences"; label: "Preferences"; iconText: "󰒓"
        onTriggered: if (root.deck) root.deck.openOverlay("preferences")
      }
    }

    MonitorInputModule {
      width: drawerControls.width
      height: root.monitorHeight
    }
  }

  AppLauncherModule {
    id: applicationsPage
    objectName: "commandCenterApplicationsPage"
    anchors.fill: parent
    visible: root.page === "applications"
    shell: root.shell
    deck: root.deck
    controller: root.launcherController
    pluginDir: root.pluginDir
    primaryMonitor: root.primaryMonitor
    onBackRequested: if (root.deck) root.deck.setCommandCenterPage("home")
  }

  Text {
    id: interactionHint
    objectName: "commandCenterInteractionHint"
    visible: root.page === "home" && root.useThreeColumns
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.spacing.panelGap
    text: root.controller && root.controller.editMode
      ? "Edit mode · drag modules or dividers · tap Done when finished"
      : "Pull down notifications · pull up overview"
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
}
