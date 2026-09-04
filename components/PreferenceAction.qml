import QtQuick
import qs.Commons

Item {
  id: root

  property string label: ""
  property string description: ""
  property string iconText: ""
  property string actionText: "Open"
  signal clicked()

  implicitHeight: Style.space(64)
  Accessible.role: Accessible.Button
  Accessible.name: label

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: actionPointer.pressed
      ? Style.pressedFillFor(Color.foreground, Color.accent)
      : "transparent"

    Behavior on color { ColorAnimation { duration: 100 } }
  }

  Row {
    anchors.fill: parent
    spacing: Style.spacing.rowGap

    Text {
      visible: root.iconText !== ""
      width: visible ? Style.space(34) : 0
      anchors.verticalCenter: parent.verticalCenter
      text: root.iconText
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.iconLarge
      horizontalAlignment: Text.AlignHCenter
    }

    Column {
      width: parent.width - x - actionLabel.width - chevron.width - parent.spacing * 2
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.xs

      Text {
        width: parent.width
        text: root.label
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        visible: root.description !== ""
        width: parent.width
        text: root.description
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Text {
      id: actionLabel
      anchors.verticalCenter: parent.verticalCenter
      text: root.actionText
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Text {
      id: chevron
      width: Style.space(22)
      anchors.verticalCenter: parent.verticalCenter
      text: "󰅂"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.icon
      horizontalAlignment: Text.AlignRight
    }
  }

  MouseArea {
    id: actionPointer
    anchors.fill: parent
    preventStealing: false
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
