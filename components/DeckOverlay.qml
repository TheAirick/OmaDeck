import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property string origin: "top"
  property string overlayId: origin === "top" ? "notification" : "overview"
  property string title: ""
  property string subtitle: ""
  property bool open: false
  property real outerGap: Math.max(1, Style.gapsOut)
  readonly property bool pointerHovered: overlayHover.hovered
  readonly property real closedOffset: origin === "top" ? -height : height
  default property alias content: contentHost.data
  signal dismissRequested()

  y: open ? 0 : closedOffset
  visible: open || Math.abs(y) < height
  clip: true

  Behavior on y {
    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.88)
  }

  DeckCard {
    id: overlayCard
    objectName: root.overlayId + "OverlayCard"
    anchors.fill: parent
    anchors.margins: root.outerGap
    title: root.title
    subtitle: root.subtitle
    active: true

    Item {
      id: contentHost
      anchors.fill: parent
    }
  }

  Button {
    id: closeButton
    objectName: "close" + root.overlayId.charAt(0).toUpperCase() + root.overlayId.slice(1) + "Overlay"
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: root.outerGap + Style.spacing.panelPadding
    width: Style.space(48)
    height: Style.space(48)
    iconText: "󰅖"
    iconSize: Style.font.display
    tooltipText: "Close " + root.title
    bordered: true
    z: 20
    onClicked: root.dismissRequested()
  }

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: root.origin === "bottom" ? parent.top : undefined
    anchors.bottom: root.origin === "top" ? parent.bottom : undefined
    anchors.topMargin: root.origin === "bottom" ? root.outerGap + Style.space(6) : 0
    anchors.bottomMargin: root.origin === "top" ? root.outerGap + Style.space(6) : 0
    width: Style.space(52)
    height: Style.space(4)
    radius: height / 2
    color: Color.muted
    opacity: 0.72
    z: 20
  }

  // Dismissal begins at the edge opposite the reveal gesture so content
  // scrolling and button drags retain their own pointer grabs.
  EdgeSwipeArea {
    edge: root.origin
    reverse: true
    gestureThickness: Style.space(30)
    anchors.top: root.origin === "bottom" ? parent.top : undefined
    anchors.bottom: root.origin === "top" ? parent.bottom : undefined
    anchors.left: parent.left
    anchors.right: parent.right
    onTriggered: root.dismissRequested()
    z: 30
  }

  HoverHandler { id: overlayHover }
}
