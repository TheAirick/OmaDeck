import QtQuick
import qs.Commons

Item {
  id: root

  property var controller: null
  property string path: ""
  property var deck: null
  property var shell: null
  property string primaryMonitor: "DP-1"

  readonly property int observedRevision: controller ? controller.revision : 0
  readonly property var node: {
    var revision = observedRevision
    return controller ? controller.nodeAt(path) : null
  }
  readonly property bool horizontal: node && node.orientation === "horizontal"
  readonly property real ratio: node && node.ratio !== undefined ? Number(node.ratio) : 0.5
  readonly property int gap: Style.space(5)
  readonly property real availableLength: horizontal ? width - gap : height - gap
  readonly property real firstLength: Math.max(0, Math.round(availableLength * ratio))
  readonly property string firstPath: path ? path + "/first" : "first"
  readonly property string secondPath: path ? path + "/second" : "second"

  function loadChild(loader) {
    if (!root.controller) return
    var child = root.controller.nodeAt(loader.nodePath)
    var file = child && child.type === "split" ? "SplitNode.qml" : "ModuleTile.qml"
    loader.setSource(Qt.resolvedUrl(file), {
      controller: root.controller,
      path: loader.nodePath,
      deck: root.deck,
      shell: root.shell,
      primaryMonitor: root.primaryMonitor
    })
  }

  Loader {
    id: firstLoader
    property string nodePath: root.firstPath
    x: 0
    y: 0
    width: root.horizontal ? root.firstLength : root.width
    height: root.horizontal ? root.height : root.firstLength
    Component.onCompleted: root.loadChild(firstLoader)
  }

  Loader {
    id: secondLoader
    property string nodePath: root.secondPath
    x: root.horizontal ? root.firstLength + root.gap : 0
    y: root.horizontal ? 0 : root.firstLength + root.gap
    width: root.horizontal ? root.width - x : root.width
    height: root.horizontal ? root.height : root.height - y
    Component.onCompleted: root.loadChild(secondLoader)
  }

  Rectangle {
    id: divider
    visible: root.controller && root.controller.editMode
    x: root.horizontal ? root.firstLength : 0
    y: root.horizontal ? 0 : root.firstLength
    width: root.horizontal ? root.gap : root.width
    height: root.horizontal ? root.height : root.gap
    color: Color.accent
    opacity: dividerDrag.active ? 1 : 0.5
    z: 20

    DragHandler {
      id: dividerDrag
      target: null
      xAxis.enabled: root.horizontal
      yAxis.enabled: !root.horizontal
      property real startingRatio: 0.5

      onActiveChanged: if (active) startingRatio = root.ratio
      onTranslationChanged: {
        if (!active || root.availableLength <= 0) return
        var delta = root.horizontal ? translation.x : translation.y
        root.controller.setRatio(root.path, startingRatio + delta / root.availableLength)
      }
    }
  }

}
