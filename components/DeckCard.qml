import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string title: ""
  property string subtitle: ""
  property bool active: false
  default property alias content: contentHost.data

  color: Color.popups.background
  radius: Style.cornerRadius
  padding: Style.spacing.panelPadding
  borderSpec: active
    ? Border.hyprlandActiveSpec(Color.accent, 2)
    : Border.surfaceSpec("popups", "border", Color.popups.border, 1)

  Column {
    anchors.fill: parent
    anchors.topMargin: root.contentTopInset
    anchors.rightMargin: root.contentRightInset
    anchors.bottomMargin: root.contentBottomInset
    anchors.leftMargin: root.contentLeftInset
    spacing: Style.spacing.rowGap

    Row {
      width: parent.width
      spacing: Style.spacing.controlGap

      Text {
        text: root.title
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        width: parent.width - x
        text: root.subtitle
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
      }
    }

    Item {
      id: contentHost
      width: parent.width
      height: parent.height - y
    }
  }
}
