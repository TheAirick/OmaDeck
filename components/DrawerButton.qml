import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string edge: ""
  property string label: ""
  property string iconText: ""
  signal triggered()

  width: Style.space(190)
  height: Style.space(92)
  color: touch.pressed ? Style.pressedFill
    : hover.hovered ? Style.hoverFill : Style.normalFill
  radius: Style.cornerRadius
  borderSpec: Border.controlSpec(hover.hovered ? "hover" : "normal",
    Color.foreground, Color.accent, Color.urgent)

  Column {
    anchors.centerIn: parent
    spacing: Style.spacing.labelGap

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.iconText
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.displayLarge
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.label
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
    }
  }

  HoverHandler { id: hover }
  TapHandler { id: touch; onTapped: root.triggered() }
}
