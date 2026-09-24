import QtQuick
import qs.Commons

Item {
  id: root

  property real surfaceWidth: parent ? parent.width : 0
  property real surfaceHeight: parent ? parent.height : 0
  property real outerGap: 0
  property real usableWidth: Math.max(0, surfaceWidth - outerGap * 2)
  property real usableHeight: Math.max(0, surfaceHeight - outerGap * 2)
  property real reservedLeft: 0
  property real reservedRight: 0
  property real reservedTop: 0
  property real reservedBottom: 0
  property var layoutController: null
  property var appearanceController: null
  property var launcherController: null
  property var weatherController: null
  property var timerController: null
  property var watchController: null
  property var deck: null
  property var shell: null
  property string primaryMonitor: "DP-1"

  readonly property bool pointerHovered: centerHover.hovered

  objectName: "deckCenterCanvas"
  x: outerGap + reservedLeft
  y: outerGap + reservedTop
  width: Math.max(0, usableWidth - reservedLeft - reservedRight)
  height: Math.max(0, usableHeight - reservedTop - reservedBottom)

  Rectangle {
    anchors.fill: parent
    color: Color.background
    visible: !(root.watchController && root.watchController.active)
  }

  SplitNode {
    objectName: "deckRootSplit"
    anchors.fill: parent
    visible: !(root.watchController && root.watchController.active)
    enabled: visible
    controller: root.layoutController
    path: ""
    deck: root.deck
    shell: root.shell
    primaryMonitor: root.primaryMonitor
    appearanceController: root.appearanceController
    launcherController: root.launcherController
    weatherController: root.weatherController
    timerController: root.timerController
  }

  Loader {
    objectName: "watchModeLoader"
    anchors.fill: parent
    active: !!(root.watchController && root.watchController.active)
    sourceComponent: WatchMode {
      canvasX: root.x
      canvasY: root.y
      deck: root.deck
      shell: root.shell
      launcherController: root.launcherController
      primaryMonitor: root.primaryMonitor
      watch: root.watchController
      appearanceController: root.appearanceController
      weatherController: root.weatherController
      timerController: root.timerController
    }
  }

  HoverHandler {
    id: centerHover
  }
}
