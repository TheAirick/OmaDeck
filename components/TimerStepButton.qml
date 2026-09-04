import QtQuick
import qs.Commons

Item {
  id: root

  property string text: ""
  property string accessibleName: ""
  readonly property bool pressFeedbackActive: stepTap.pressed

  signal clicked()

  width: 48
  height: 48
  Accessible.role: Accessible.Button
  Accessible.name: accessibleName

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: stepTap.pressed
      ? Style.pressedFillFor(Color.foreground, Color.accent)
      : "transparent"

    Behavior on color {
      ColorAnimation { duration: 120 }
    }
  }

  Text {
    anchors.centerIn: parent
    text: root.text
    color: stepTap.pressed ? Color.accent : Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.display
    font.weight: Font.DemiBold

    Behavior on color {
      ColorAnimation { duration: 90 }
    }
  }

  TapHandler {
    id: stepTap
    onTapped: root.clicked()
  }
}
