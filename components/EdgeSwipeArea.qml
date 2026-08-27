import QtQuick
import qs.Commons
import "DrawerGesture.js" as DrawerGesture

Item {
  id: root

  property string edge: "left"
  property bool reverse: false
  property real gestureThickness: Style.space(30)
  signal triggered()

  width: edge === "left" || edge === "right" ? gestureThickness : (parent ? parent.width : 0)
  height: edge === "top" || edge === "bottom" ? gestureThickness : (parent ? parent.height : 0)
  z: 100

  DragHandler {
    id: drag
    target: null

    property point startPoint: Qt.point(0, 0)

    onActiveChanged: {
      if (active) {
        startPoint = centroid.position
        return
      }

      var dx = centroid.position.x - startPoint.x
      var dy = centroid.position.y - startPoint.y
      var threshold = Style.space(42)
      if (DrawerGesture.shouldTrigger(root.edge, root.reverse, dx, dy, threshold)) root.triggered()
    }
  }
}
