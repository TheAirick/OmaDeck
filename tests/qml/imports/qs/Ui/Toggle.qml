import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string label: ""
  property string description: ""
  property bool checked: false
  signal clicked()

  implicitWidth: 240
  implicitHeight: 54
  radius: Style.cornerRadius
  color: Style.normalFill
  border.width: 1
  border.color: Color.muted

  Text {
    anchors.left: parent.left
    anchors.leftMargin: Style.spacing.rowPaddingX
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Rectangle {
    anchors.right: parent.right
    anchors.rightMargin: Style.spacing.rowPaddingX
    anchors.verticalCenter: parent.verticalCenter
    width: 44
    height: 24
    radius: height / 2
    color: root.checked ? Color.accent : Color.muted
  }

  TapHandler {
    enabled: root.enabled
    onTapped: root.clicked()
  }
}
