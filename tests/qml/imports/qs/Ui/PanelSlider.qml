import QtQuick
import qs.Commons

Rectangle {
  id: root

  property real minimum: 0
  property real maximum: 1
  property real value: 0
  property color fillColor: Color.accent
  property color knobColor: Color.accent
  property bool dragging: false
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

  MouseArea {
    anchors.fill: parent
    onPressed: function(mouse) {
      root.dragging = true
      root.moved(Math.max(root.minimum, Math.min(root.maximum,
        root.minimum + mouse.x / root.width * (root.maximum - root.minimum))))
    }
    onPositionChanged: function(mouse) {
      if (!root.dragging) return
      root.moved(Math.max(root.minimum, Math.min(root.maximum,
        root.minimum + mouse.x / root.width * (root.maximum - root.minimum))))
    }
    onReleased: function(mouse) {
      root.dragging = false
      root.released(Math.max(root.minimum, Math.min(root.maximum,
        root.minimum + mouse.x / root.width * (root.maximum - root.minimum))))
    }
  }
}
