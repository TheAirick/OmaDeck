import QtQuick
import qs.Commons
import "../theme"
import "../components"

Item {
  id: root

  property var deck: null
  property var controller: null
  property var shell: null
  property var launcherController: null
  property string pluginDir: ""
  property string primaryMonitor: "DP-1"
  readonly property var monitorInputController: deck && "monitorInputController" in deck ? deck.monitorInputController : null
  readonly property bool hasMonitorControls: monitorInputController && monitorInputController.showControls
  readonly property string page: deck ? deck.commandCenterPage : "home"
  readonly property real compactButtonWidth: Style.space(146)
  readonly property bool useThreeColumns: width >= compactButtonWidth * 3 + Style.spacing.panelGap * 4
  readonly property int columnCount: useThreeColumns ? 3 : 2
  readonly property real contentWidth: Math.min(
    Math.max(0, width - Style.spacing.panelGap * 2),
    useThreeColumns ? compactButtonWidth * 3 + Style.spacing.panelGap * 2 : Style.space(392))
  readonly property real buttonWidth: Math.max(Style.space(72),
    (contentWidth - Style.spacing.panelGap * (columnCount - 1)) / columnCount)
  readonly property real monitorHeight: hasMonitorControls ? Style.space(104) : 0
  readonly property int rowCount: 6 / columnCount
  readonly property real buttonHeight: Math.max(Style.space(64),
    Math.min(Style.space(useThreeColumns ? 92 : 96),
      (height - monitorHeight - Style.spacing.panelGap * (rowCount - 1 + (hasMonitorControls ? 1 : 0))) / rowCount))
  // Retained as a public diagnostic contract. Controls now reflow instead of
  // shrinking uniformly when a drawer reserves part of the center canvas.
  readonly property real contentScale: 1

  Flickable {
    id: controlsViewport
    objectName: "commandCenterControlsViewport"
    anchors.fill: parent
    visible: root.page === "home"
    clip: true
    contentWidth: width
    contentHeight: Math.max(height, controlStack.implicitHeight)
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: controlStack
      x: (controlsViewport.width - width) / 2
      y: Math.max(0, (controlsViewport.height - height) / 2)
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
          edge: "bottom"; label: "Workspaces"; iconText: "󰖲"
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
        controller: root.monitorInputController
        visible: root.hasMonitorControls
        width: drawerControls.width
        height: root.monitorHeight
      }
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
      && controlStack.y + controlStack.height + height + Style.spacing.panelGap * 2 < root.height
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.spacing.panelGap
    text: "Pull down notifications · pull up workspaces"
    color: DeckColors.secondaryText
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
}
