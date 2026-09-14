import QtQuick
import qs.Commons

Item {
  id: root

  property string text: ""
  property string accessibleName: ""
  readonly property bool pressFeedbackActive: stepTap.pressed
  property int repeatCount: 0

  signal clicked()
  Accessible.onPressAction: if (root.enabled && root.visible) root.clicked()

  function stopRepeating() { holdDelay.stop(); repeatDelay.stop() }
  onEnabledChanged: if (!enabled) stopRepeating()
  onVisibleChanged: if (!visible) stopRepeating()

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
    enabled: root.enabled && root.visible
    onPressedChanged: {
      if (pressed) { root.repeatCount = 0; holdDelay.restart() }
      else root.stopRepeating()
    }
    onTapped: if (root.repeatCount === 0) root.clicked()
  }
  Timer {
    id: holdDelay
    interval: 450
    onTriggered: if (stepTap.pressed && root.enabled && root.visible) {
      root.repeatCount++
      root.clicked()
      repeatDelay.start()
    }
  }
  Timer {
    id: repeatDelay
    interval: root.repeatCount >= 8 ? 70 : 160
    repeat: true
    onTriggered: {
      if (!stepTap.pressed || !root.enabled || !root.visible) { root.stopRepeating(); return }
      root.repeatCount++
      root.clicked()
    }
  }
}
