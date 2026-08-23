import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string edge: "left"
  property bool open: false
  default property alias content: contentHost.data

  color: Color.popups.background
  radius: Style.cornerRadius
  padding: Style.spacing.panelPadding
  borderSpec: Border.hyprlandActiveSpec(Color.accent, 2)
  opacity: open ? 1 : 0.72

  Behavior on opacity { NumberAnimation { duration: 160 } }

  Item {
    id: contentHost
    anchors.fill: parent
    anchors.topMargin: root.contentTopInset
    anchors.rightMargin: root.contentRightInset
    anchors.bottomMargin: root.contentBottomInset
    anchors.leftMargin: root.contentLeftInset
  }
}
