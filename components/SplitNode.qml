import QtQuick
import qs.Commons
import "SplitPresentationPolicy.js" as SplitPresentationPolicy

Item {
  id: root

  property var controller: null
  property string path: ""
  property var deck: null
  property var shell: null
  property var appearanceController: null
  property var launcherController: null
  property var weatherController: null
  property var timerController: null
  property string primaryMonitor: "DP-1"
  property bool childrenInitialized: false
  property bool reloadPending: false

  readonly property int observedRevision: controller ? controller.revision : 0
  readonly property var node: {
    var revision = observedRevision
    return controller ? controller.nodeAt(path) : null
  }
  readonly property bool horizontal: node && node.orientation === "horizontal"
  readonly property real ratio: node && node.ratio !== undefined ? Number(node.ratio) : 0.5
  readonly property var firstNode: node && node.first ? node.first : null
  readonly property var secondNode: node && node.second ? node.second : null
  readonly property string firstModuleId: firstNode && firstNode.type === "module" ? String(firstNode.moduleId || "") : ""
  readonly property string secondModuleId: secondNode && secondNode.type === "module" ? String(secondNode.moduleId || "") : ""
  readonly property real effectiveRatio: SplitPresentationPolicy.effectiveRatio(
    horizontal, firstModuleId, secondModuleId, ratio)
  readonly property int gap: Style.spacing.panelGap
  readonly property real availableLength: horizontal ? width - gap : height - gap
  readonly property real firstLength: Math.max(0, Math.round(availableLength * effectiveRatio))
  readonly property string firstPath: path ? path + "/first" : "first"
  readonly property string secondPath: path ? path + "/second" : "second"

  function loadChild(loader) {
    if (!root.controller || !loader) return
    var child = root.controller.nodeAt(loader.nodePath)
    var file = child && child.type === "split" ? "SplitNode.qml" : "ModuleTile.qml"
    if (loader.loadedComponent === file) return
    loader.loadedComponent = file
    loader.setSource(Qt.resolvedUrl(file), {
      controller: root.controller,
      path: loader.nodePath,
      deck: root.deck,
      shell: root.shell,
      primaryMonitor: root.primaryMonitor,
      appearanceController: root.appearanceController,
      launcherController: root.launcherController,
      weatherController: root.weatherController,
      timerController: root.timerController
    })
  }

  function reloadChildren() {
    loadChild(firstLoader)
    loadChild(secondLoader)
  }

  function loadersBusy() {
    return firstLoader.status === Loader.Loading || secondLoader.status === Loader.Loading
  }

  function requestReload() {
    if (!childrenInitialized) return
    if (loadersBusy()) {
      reloadPending = true
      return
    }
    reloadPending = false
    reloadChildren()
  }

  function finishPendingReload() {
    if (reloadPending && !loadersBusy()) Qt.callLater(root.requestReload)
  }

  onObservedRevisionChanged: root.requestReload()

  Component.onCompleted: {
    childrenInitialized = true
    reloadChildren()
  }

  Loader {
    id: firstLoader
    property string nodePath: root.firstPath
    property string loadedComponent: ""
    x: 0
    y: 0
    width: root.horizontal ? root.firstLength : root.width
    height: root.horizontal ? root.height : root.firstLength
    onStatusChanged: root.finishPendingReload()
  }

  Loader {
    id: secondLoader
    property string nodePath: root.secondPath
    property string loadedComponent: ""
    x: root.horizontal ? root.firstLength + root.gap : 0
    y: root.horizontal ? 0 : root.firstLength + root.gap
    width: root.horizontal ? root.width - x : root.width
    height: root.horizontal ? root.height : root.height - y
    onStatusChanged: root.finishPendingReload()
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
