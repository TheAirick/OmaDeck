import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../modules"

PanelWindow {
  id: root

  property var shell: null
  property var pluginRoot: null
  property var layoutController: null
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

  IpcHandler {
    enabled: root.isTarget
    target: "pretty.omadeck"

    function drawer(edge: string): void {
      if (["left", "right", "top", "bottom"].indexOf(edge) !== -1) root.toggleDrawer(edge)
    }

    function closeDrawer(): void {
      root.closeDrawer()
    }

    function edit(enabled: bool): void {
      if (!root.layoutController) return
      if (enabled) root.layoutController.beginEdit("")
      else root.layoutController.finishEdit()
    }

    function ratio(path: string, value: real): void {
      if (root.layoutController) root.layoutController.setRatio(path, value)
    }
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

    SplitNode {
      anchors.fill: parent
      anchors.margins: root.outerGap
      controller: root.layoutController
      path: ""
      deck: root
      shell: root.shell
      primaryMonitor: root.primaryMonitor
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

  Button {
    visible: root.layoutController && root.layoutController.editMode
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: root.outerGap + Style.spacing.controlPaddingX
    z: 200
    text: "Done"
    iconText: "󰄬"
    selected: true
    foreground: Color.foreground
    onClicked: root.layoutController.finishEdit()
  }
}
