import QtQuick
import qs.Commons

Item {
  id: root

  property date now: new Date()

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  Column {
    anchors.centerIn: parent
    spacing: Style.spacing.labelGap

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDateTime(root.now, "h:mm")
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.displayLarge * 2.2
      font.weight: Font.DemiBold
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDateTime(root.now, "dddd, MMMM d")
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }
}
