import QtQuick
import qs.Commons

Item {
  id: root

  property string label: ""
  property string description: ""
  property bool checked: false
  signal clicked()

  implicitHeight: Style.space(64)
  Accessible.role: Accessible.Button
  Accessible.name: label
  Accessible.checked: checked

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: togglePointer.pressed
      ? Style.pressedFillFor(Color.foreground, Color.accent)
      : "transparent"

    Behavior on color { ColorAnimation { duration: 100 } }
  }

  Column {
    anchors.left: parent.left
    anchors.right: switchTrack.left
    anchors.rightMargin: Style.spacing.panelGap
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

  Rectangle {
    id: switchTrack
    width: Style.space(44)
    height: Style.space(24)
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    radius: height / 2
    color: root.checked ? Color.accent : Color.muted
    opacity: root.checked ? 1 : 0.42

    Behavior on color { ColorAnimation { duration: 120 } }

    Rectangle {
      width: Style.space(18)
      height: width
      y: (parent.height - height) / 2
      x: root.checked ? parent.width - width - Style.space(3) : Style.space(3)
      radius: width / 2
      color: root.checked ? Color.background : Color.foreground

      Behavior on x {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
      }
    }
  }

  MouseArea {
    id: togglePointer
    anchors.fill: parent
    enabled: root.enabled
    preventStealing: false
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
