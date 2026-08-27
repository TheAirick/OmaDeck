import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string edge: "left"
  property bool open: false
  readonly property real dismissInset: edge === "left" ? contentRightInset
    : edge === "right" ? contentLeftInset
    : edge === "top" ? contentBottomInset
    : contentTopInset
  default property alias content: contentHost.data
  signal dismissRequested()

  color: Color.popups.background
  radius: Style.cornerRadius
  padding: Style.spacing.panelPadding
  borderSpec: Border.hyprlandActiveSpec(Color.accent, 2)
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
}
