import QtQuick
import qs.Commons
import "../components"
import "../components/ResponsiveLayout.js" as ResponsiveLayout

Item {
  id: root

  property var deck: null
  property var controller: null
  property var shell: null
  property var launcherController: null
  property string pluginDir: ""
  property string primaryMonitor: "DP-1"
  readonly property string page: deck ? deck.commandCenterPage : "home"
  readonly property real standardLayoutHeight: Style.space(92 * 3) + Style.spacing.panelGap * 4
  readonly property real wideLayoutWidth: Style.space(190 * 4) + Style.spacing.panelGap * 5
  readonly property bool useWideLayout: ResponsiveLayout.useShortWide(
    width, height, root.standardLayoutHeight, root.wideLayoutWidth)
  readonly property real contentScale: Math.min(1,
    Math.max(0, width - Style.spacing.panelGap * 2) / Math.max(1, controlStack.implicitWidth),
    Math.max(0, height - Style.spacing.panelGap * 2) / Math.max(1, controlStack.implicitHeight))

  Column {
    id: controlStack
    visible: root.page === "home"
    anchors.centerIn: parent
    spacing: Style.spacing.panelGap
    scale: root.contentScale
    transformOrigin: Item.Center

    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Grid {
      id: drawerControls
      columns: root.useWideLayout ? 4 : 2
      rowSpacing: Style.spacing.panelGap
      columnSpacing: Style.spacing.panelGap
      move: Transition {
        NumberAnimation { properties: "x,y"; duration: 160; easing.type: Easing.OutCubic }
      }

      DrawerButton {
        edge: "left"; label: "Volume"; iconText: "󰕾"
        onTriggered: if (root.deck) root.deck.toggleDrawer(edge)
      }
      DrawerButton {
        edge: "right"; label: "System"; iconText: "󰍛"
        onTriggered: if (root.deck) root.deck.toggleDrawer(edge)
      }
      DrawerButton {
        edge: "bottom"; label: "Overview"; iconText: "󰖲"
        onTriggered: if (root.deck) root.deck.openOverlay("overview")
      }
      DrawerButton {
        edge: "page"; label: "Applications"; iconText: "󰀻"
        onTriggered: if (root.deck) root.deck.setCommandCenterPage("applications")
      }
    }

    MonitorInputModule {
      width: drawerControls.width
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
    visible: root.page === "home" && root.height > Style.space(300)
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
