import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string text: ""
  property string iconText: ""
  property string tooltipText: ""
  property real iconSize: Style.font.body
  property real fontSize: Style.font.body
  property var borderSpec: Border.none()
  property bool bordered: false
  property bool selected: false
  property color foreground: Color.foreground
  property real horizontalPadding: 12
  property real verticalPadding: 8
  signal clicked()

  implicitWidth: Math.max(48, label.implicitWidth + 24)
  implicitHeight: 48
  radius: 8
  color: selected ? Color.accent : "#27272a"
  border.width: bordered ? 1 : 0
  border.color: Color.muted
  opacity: enabled ? 1 : 0.4

  Text {
    id: label
    anchors.centerIn: parent
    text: root.iconText || root.text
    color: root.selected ? Color.background : Color.foreground
    font.family: Style.font.family
    font.pixelSize: root.iconText ? root.iconSize : root.fontSize
  }

  TapHandler {
    enabled: root.enabled
    onTapped: root.clicked()
  }
}
