import QtQuick
import qs.Commons
import "../theme"
import qs.Ui

Button {
  id: root
  required property string heading
  required property string deviceLabel
  implicitHeight: Style.space(44)
  bordered: true
  Accessible.name: heading + ": " + deviceLabel + ". Change device"

  Column {
    anchors.left: parent.left
    anchors.leftMargin: Style.spacing.controlGap
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, parent.width - Style.space(18) - Style.spacing.controlGap * 2)
    Text {
      width: parent.width
      text: root.heading
      color: DeckColors.secondaryTextOn(root.color)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    Text {
      width: parent.width
      text: root.deviceLabel
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }
  Text {
    anchors.right: parent.right
    anchors.rightMargin: Style.spacing.controlGap
    anchors.verticalCenter: parent.verticalCenter
    text: "󰅂"
    color: Color.accent
    font.family: Style.font.family
    font.pixelSize: Style.font.icon
  }
}
