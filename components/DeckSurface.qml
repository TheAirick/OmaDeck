import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../modules"

PanelWindow {
  id: root

  property var shell: null
  property var pluginRoot: null
  property string targetScreen: "DP-3"
  property string primaryMonitor: "DP-1"
  property string openDrawer: ""
  property real drawerProgress: openDrawer === "" ? 0 : 1

  readonly property bool isTarget: screen && screen.name === targetScreen
  readonly property int outerGap: Math.max(1, Style.gapsOut)
  readonly property int innerGap: Style.space(5)
  readonly property int leftDrawerWidth: Math.round(width * 0.34)
  readonly property int rightDrawerWidth: Math.round(width * 0.34)
  readonly property int topDrawerHeight: Math.round(height * 0.44)
  readonly property int bottomDrawerHeight: Math.round(height * 0.44)
  readonly property real centerX: openDrawer === "left" ? leftDrawerWidth * drawerProgress
    : openDrawer === "right" ? -rightDrawerWidth * drawerProgress : 0
  readonly property real centerY: openDrawer === "top" ? topDrawerHeight * drawerProgress
    : openDrawer === "bottom" ? -bottomDrawerHeight * drawerProgress : 0

  visible: isTarget
  anchors { top: true; right: true; bottom: true; left: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omadeck"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

  function toggleDrawer(edge) {
    openDrawer = openDrawer === edge ? "" : edge
  }

  function closeDrawer() {
    openDrawer = ""
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background
  }

  // Drawers live behind the translated center canvas, so revealing one feels
  // like moving a tiled workspace rather than opening a floating dialog.
  EdgeDrawer {
    edge: "left"
    open: root.openDrawer === edge
    x: root.outerGap
    y: root.outerGap
    width: root.leftDrawerWidth - root.outerGap
    height: parent.height - root.outerGap * 2

    MediaModule {
      anchors.fill: parent
      shell: root.shell
    }
  }

  EdgeDrawer {
    edge: "right"
    open: root.openDrawer === edge
    x: parent.width - root.rightDrawerWidth
    y: root.outerGap
    width: root.rightDrawerWidth - root.outerGap
    height: parent.height - root.outerGap * 2

    AgentModule {
      anchors.fill: parent
      shell: root.shell
    }
  }

  EdgeDrawer {
    edge: "top"
    open: root.openDrawer === edge
    x: root.outerGap
    y: root.outerGap
    width: parent.width - root.outerGap * 2
    height: root.topDrawerHeight - root.outerGap

    WorkspaceModule {
      anchors.fill: parent
      primaryMonitor: root.primaryMonitor
    }
  }

  EdgeDrawer {
    edge: "bottom"
    open: root.openDrawer === edge
    x: root.outerGap
    y: parent.height - root.bottomDrawerHeight
    width: parent.width - root.outerGap * 2
    height: root.bottomDrawerHeight - root.outerGap

    AppLauncherModule {
      anchors.fill: parent
      shell: root.shell
      primaryMonitor: root.primaryMonitor
    }
  }

  Item {
    id: centerCanvas
    x: root.centerX
    y: root.centerY
    width: parent.width
    height: parent.height

    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Rectangle {
      anchors.fill: parent
      color: Color.background
    }

    Row {
      anchors.fill: parent
      anchors.margins: root.outerGap
      spacing: root.innerGap

      Column {
        width: Math.round((parent.width - parent.spacing) * 0.36)
        height: parent.height
        spacing: root.innerGap

        DeckCard {
          width: parent.width
          height: Math.round((parent.height - parent.spacing) * 0.56)
          title: "OmaDeck"
          subtitle: "DP-3 · edge workspace"
          active: true

          ClockModule {
            anchors.fill: parent
          }
        }

        DeckCard {
          width: parent.width
          height: parent.height - y
          title: "Workspaces"
          subtitle: "Tap to focus on " + root.primaryMonitor

          WorkspaceModule {
            anchors.fill: parent
            compact: true
            primaryMonitor: root.primaryMonitor
          }
        }
      }

      DeckCard {
        width: parent.width - x
        height: parent.height
        title: "Command center"
        subtitle: "Swipe from any edge"

        Item {
          anchors.fill: parent

          Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: Style.spacing.panelGap

            DrawerButton { edge: "left"; label: "Media"; iconText: "󰝚"; onTriggered: root.toggleDrawer(edge) }
            DrawerButton { edge: "right"; label: "Agents"; iconText: "󰚩"; onTriggered: root.toggleDrawer(edge) }
            DrawerButton { edge: "top"; label: "Workspaces"; iconText: "󰍹"; onTriggered: root.toggleDrawer(edge) }
            DrawerButton { edge: "bottom"; label: "Applications"; iconText: "󰀻"; onTriggered: root.toggleDrawer(edge) }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.spacing.panelGap
            text: "Foundation preview · drawers, tiling, live Omarchy theme"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    TapHandler {
      enabled: root.openDrawer !== ""
      acceptedButtons: Qt.LeftButton
      onTapped: if (root.openDrawer !== "") root.closeDrawer()
    }
  }

  // Generous touch zones begin the drawer gesture. The first foundation uses
  // single-point drags; multi-touch resize/edit handlers come with the layout
  // tree so gesture ownership remains unambiguous.
  EdgeSwipeArea { edge: "left"; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; onTriggered: root.toggleDrawer(edge) }
  EdgeSwipeArea { edge: "right"; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; onTriggered: root.toggleDrawer(edge) }
  EdgeSwipeArea { edge: "top"; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; onTriggered: root.toggleDrawer(edge) }
  EdgeSwipeArea { edge: "bottom"; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; onTriggered: root.toggleDrawer(edge) }
}
