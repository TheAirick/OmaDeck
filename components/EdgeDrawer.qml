import QtQuick
import qs.Commons
import qs.Ui
import "DrawerGesture.js" as DrawerGesture

BorderSurface {
  id: root

  property string edge: "left"
  property bool open: false
  property bool pointerRevealed: false
  property bool framed: true
  property real framelessDismissInset: Style.spacing.panelPadding
  readonly property bool pointerHovered: drawerHover.hovered
  readonly property bool dismissButtonInInset: !framed && edge === "left"
  readonly property real dismissInset: edge === "left" ? contentRightInset
    : edge === "right" ? contentLeftInset
    : edge === "top" ? contentBottomInset
    : contentTopInset
  readonly property real navigationSize: Style.space(32)
  readonly property var dismissButtonPosition: DrawerGesture.dismissButtonPosition(
    edge, width, height, navigationSize,
    contentLeftInset, contentTopInset, contentRightInset, contentBottomInset)
  default property alias content: contentHost.data
  signal dismissRequested()

  color: root.framed ? Color.popups.background : "transparent"
  radius: root.framed ? Style.cornerRadius : 0
  padding: root.framed ? Style.spacing.panelPadding : 0
  rightPadding: root.framed ? root.padding : root.framelessDismissInset
  borderSpec: root.framed
    ? Border.hyprlandActiveSpec(Color.accent, 2)
    : Border.none()
  visible: open || opacity > 0
  opacity: open ? 1 : 0

  Behavior on opacity { NumberAnimation { duration: 160 } }

  Item {
    id: contentHost
    anchors.fill: parent
    anchors.topMargin: root.contentTopInset
    anchors.rightMargin: root.contentRightInset
    anchors.bottomMargin: root.contentBottomInset
    anchors.leftMargin: root.contentLeftInset
  }

  // Reverse swipes start only in the inner padding strip, outside content and
  // its pointer handlers. Sliders and other controls therefore retain grabs in
  // both directions while the padding remains a dedicated dismissal region.
  EdgeSwipeArea {
    edge: root.edge
    reverse: true
    enabled: root.open
    gestureThickness: root.dismissInset
    x: root.edge === "left" ? root.width - width : 0
    y: root.edge === "top" ? root.height - height : 0
    onTriggered: root.dismissRequested()
  }

  Button {
    id: dismissButton
    visible: root.open && (root.pointerRevealed || opacity > 0)
    opacity: root.pointerRevealed ? 1 : 0
    enabled: root.pointerRevealed
    width: root.dismissButtonInInset ? root.dismissInset : root.navigationSize
    height: root.navigationSize
    x: root.dismissButtonInInset ? root.width - width : root.dismissButtonPosition.x
    y: root.dismissButtonPosition.y
    z: 30
    iconText: root.edge === "left" ? "←"
      : root.edge === "right" ? "→"
      : root.edge === "top" ? "↑" : "↓"
    iconSize: Style.font.body
    tooltipText: "Close drawer"
    bordered: true
    foreground: Color.foreground
    onClicked: root.dismissRequested()

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  }

  HoverHandler {
    id: drawerHover
  }
}
