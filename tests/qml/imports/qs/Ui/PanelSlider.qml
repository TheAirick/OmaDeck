import QtQuick
import qs.Commons

Rectangle {
  id: root

  property real minimum: 0
  property real maximum: 1
  property real value: 0
  property color fillColor: Color.accent
  property color knobColor: Color.accent
  signal moved(real value)
  signal released(real value)
  signal rightClicked()

  implicitWidth: 160
  implicitHeight: 20
  height: implicitHeight
  radius: height / 2
  color: Color.muted
  opacity: enabled ? 1 : 0.35

  Rectangle {
    width: parent.width * Math.max(0, Math.min(1, (root.value - root.minimum) / Math.max(0.0001, root.maximum - root.minimum)))
    height: parent.height
    radius: parent.radius
    color: root.fillColor
  }
}
