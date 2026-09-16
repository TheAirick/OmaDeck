import QtQuick
import qs.Commons
import "../theme"

Item {
  id: root
  property string label: ""
  property string status: ""
  property string iconText: ""
  property bool checked: false
  property bool available: true
  signal toggled()
  implicitHeight: Style.space(56)
  Accessible.role: Accessible.CheckBox
  Accessible.name: label
  Accessible.checked: checked
  Accessible.onPressAction: if (enabled && available) toggled()

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: quickTap.pressed ? Style.pressedFillFor(Color.foreground, Color.accent) : "transparent"
  }
  Text {
    id: glyph
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(32)
    text: root.iconText
    color: root.available && root.checked ? Color.accent : DeckColors.secondaryText
    font.family: Style.font.family
    font.pixelSize: Style.font.iconLarge
  }
  Column {
    anchors.left: glyph.right
    anchors.leftMargin: Style.spacing.controlGap
    anchors.right: switchTrack.left
    anchors.rightMargin: Style.spacing.controlGap
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.labelGap
    Text {
      width: parent.width
      text: root.label
      color: root.available ? Color.foreground : DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      text: root.available ? root.status : "Unavailable"
      color: DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }
  Rectangle {
    id: switchTrack
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(40); height: Style.space(22)
    radius: height / 2
    color: root.checked && root.available ? Color.accent : Color.muted
    opacity: root.checked && root.available ? 1 : 0.42
    Rectangle {
      width: Style.space(16); height: width
      y: (parent.height - height) / 2
      x: root.checked && root.available ? parent.width - width - Style.space(3) : Style.space(3)
      radius: width / 2
      color: root.checked && root.available ? Color.background : Color.foreground
      Behavior on x { NumberAnimation { duration: 120 } }
    }
  }
  TapHandler {
    id: quickTap
    enabled: root.enabled && root.available
    onTapped: root.toggled()
  }
}
