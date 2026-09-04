import QtQuick
import qs.Commons

Item {
  id: root

  property string label: ""
  property string iconText: ""
  property bool selected: false
  signal clicked()

  implicitHeight: Style.space(50)
  Accessible.role: Accessible.Button
  Accessible.name: label

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: categoryPointer.pressed
      ? Style.pressedFillFor(Color.foreground, Color.accent)
      : "transparent"

    Behavior on color { ColorAnimation { duration: 100 } }
  }

  Rectangle {
    width: Style.space(3)
    height: Style.space(26)
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    radius: width / 2
    color: Color.accent
    opacity: root.selected ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 120 } }
  }

  Row {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.spacing.controlPaddingX
    anchors.rightMargin: Style.spacing.controlPaddingX
    spacing: Style.spacing.rowGap

    Text {
      width: Style.space(28)
      anchors.verticalCenter: parent.verticalCenter
      text: root.iconText
      color: root.selected ? Color.accent : Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.iconLarge
      horizontalAlignment: Text.AlignHCenter
    }

    Text {
      width: parent.width - x
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      color: root.selected ? Color.foreground : Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: root.selected
      elide: Text.ElideRight
    }
  }

  MouseArea {
    id: categoryPointer
    anchors.fill: parent
    preventStealing: false
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
