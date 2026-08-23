import QtQuick
import qs.Commons

Item {
  id: root

  property string edge: "left"
  signal triggered()

  width: edge === "left" || edge === "right" ? Style.space(30) : (parent ? parent.width : 0)
  height: edge === "top" || edge === "bottom" ? Style.space(30) : (parent ? parent.height : 0)
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
      if ((root.edge === "left" && dx > threshold)
          || (root.edge === "right" && dx < -threshold)
          || (root.edge === "top" && dy > threshold)
          || (root.edge === "bottom" && dy < -threshold)) root.triggered()
    }
  }
}
