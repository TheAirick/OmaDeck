import QtQuick
import qs.Commons
import "../theme"
import "../modules"
import "../services"

Item {
  id: root

  property var controller: null
  property string path: ""
  objectName: "dashboardTile-" + moduleId
  property var deck: null
  property var shell: null
  property var appearanceController: null
  property var launcherController: null
  property var weatherController: null
  property var timerController: null
  property string primaryMonitor: "DP-1"

  readonly property int observedRevision: controller ? controller.revision : 0
  readonly property var node: {
    var revision = observedRevision
    return controller ? controller.nodeAt(path) : null
  }
  readonly property string moduleId: node ? String(node.moduleId || "") : ""
  readonly property bool fullDashboard: !!(controller && controller.dashboardLayout)
  readonly property bool editing: !!(controller && controller.editMode)
  property string dropEdge: ""
  property bool dragging: false
  readonly property bool selected: controller && controller.selectedPath === path
  readonly property string moduleTitle: moduleId === "clock" ? "Clock"
    : moduleId === "media" ? "Now Playing"
    : moduleId === "weather" ? "Weather / Timer"
    : moduleId === "workspaces" ? "Workspaces"
    : moduleId === "command-center" ? "Command center"
    : moduleId
  readonly property string moduleSubtitle: moduleId === "clock" ? "DP-3 · edge workspace"
    : moduleId === "workspaces" ? "Tap to focus on " + primaryMonitor
    : moduleId === "command-center" ? "Pages & edge controls"
    : ""

  z: root.dragging ? 50 : 1
  scale: root.dragging ? 0.98 : 1
  opacity: root.dragging ? 0.86 : 1
  Behavior on scale { NumberAnimation { duration: 100 } }
  Behavior on opacity { NumberAnimation { duration: 100 } }

  Drag.active: root.dragging
  Drag.source: root
  Drag.keys: ["omadeck-module"]
  Drag.hotSpot.x: moduleDrag.centroid.pressPosition.x
  Drag.hotSpot.y: moduleDrag.centroid.pressPosition.y

  Loader {
    anchors.fill: parent
    enabled: !root.editing
    sourceComponent: root.moduleId === "media" ? mediaComponent
      : root.moduleId === "clock" ? (root.fullDashboard ? clockComponent : clockTileComponent)
      : root.moduleId === "weather" ? weatherComponent : genericCardComponent
  }

  Rectangle {
    anchors.fill: parent
    visible: root.editing
    color: "transparent"
    border.color: root.selected ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.22)
    border.width: root.selected ? 3 : 1
    radius: Style.cornerRadius
    z: 10
  }

  Text {
    visible: root.editing
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Style.spacing.controlPaddingX
    text: root.selected ? "DRAG TO MOVE · TAP ANOTHER TO SWAP" : "DRAG TO MOVE"
    color: root.selected ? Color.accent : DeckColors.secondaryText
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
    z: 12
  }

  TapHandler {
    enabled: root.enabled && root.editing && !moduleDrag.active
    onTapped: root.controller.selectOrSwap(root.path)
  }

  DragHandler {
    id: moduleDrag
    enabled: root.enabled && root.editing
    target: root
    dragThreshold: Style.space(8)
    onActiveChanged: {
      if (active) {
        root.controller.selectedPath = root.path
        root.dragging = true
      } else {
        if (root.enabled && root.editing) root.Drag.drop()
        else root.Drag.cancel()
        root.dragging = false
        root.x = 0
        root.y = 0
      }
    }
  }

  DropArea {
    id: dropTarget
    anchors.fill: parent
    enabled: root.editing && !root.dragging
    keys: ["omadeck-module"]
    function edgeAt(x, y) {
      // The center swaps; each outer quarter places beside the target panel.
      var nx = x / width, ny = y / height
      var nearest = Math.min(nx, 1 - nx, ny, 1 - ny)
      return nearest > 0.25 ? "center" : nearest === nx ? "left"
        : nearest === 1 - nx ? "right" : nearest === ny ? "top" : "bottom"
    }
    onPositionChanged: function(drag) { root.dropEdge = edgeAt(drag.x, drag.y) }
    onEntered: function(drag) { root.dropEdge = edgeAt(drag.x, drag.y) }
    onExited: root.dropEdge = ""
    onDropped: function(drop) {
      if (!drop.source || drop.source === root) return
      var controller = root.controller, fullDashboard = root.fullDashboard
      var sourceId = drop.source.moduleId, targetId = root.moduleId
      var sourcePath = drop.source.path, targetPath = root.path
      var edge = edgeAt(drop.x, drop.y)
      root.dropEdge = ""
      drop.accept()
      // Topology changes can destroy this receiver. Finish the drop first.
      Qt.callLater(function() {
        if (!controller.editMode) return
        if (edge === "center" || !fullDashboard) controller.swap(sourcePath, targetPath)
        else controller.moveModule(sourceId, targetId, edge)
      })
    }
  }

  Rectangle {
    visible: root.editing && dropTarget.containsDrag && dropTarget.drag.source !== root
    x: root.dropEdge === "right" ? parent.width / 2 : 0
    y: root.dropEdge === "bottom" ? parent.height / 2 : 0
    width: root.dropEdge === "left" || root.dropEdge === "right" ? parent.width / 2 : parent.width
    height: root.dropEdge === "top" || root.dropEdge === "bottom" ? parent.height / 2 : parent.height
    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
    border.color: Color.accent
    radius: Style.cornerRadius
    z: 11
    Text {
      anchors.centerIn: parent
      text: root.dropEdge === "center" ? "Swap" : "Place here"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
    }
  }

  Component {
    id: mediaComponent
    MediaModule { shell: root.shell; providedMedia: root.deck ? root.deck.dashboardMedia : null }
  }
  Component {
    id: clockComponent
    DeckCard {
      objectName: "clockPanelCard"
      title: "Clock"
      subtitle: root.moduleSubtitle
      ClockModule {
        anchors.fill: parent
        controller: root.appearanceController
        timer: root.timerController
        interactionEnabled: !root.editing && !(root.deck && root.deck.timerPanelOpen)
        onSetupRequested: if (root.deck) root.deck.openTimerPanel()
      }
    }
  }
  Component {
    id: weatherComponent
    DeckCard {
      objectName: "companionPanelCard"
      title: companionModule.occupant === "timer" ? "Timer" : "Weather"
      padding: companionModule.occupant === "timer" && width < Style.space(360)
        ? Style.spacing.controlGap : Style.spacing.panelPadding
      ClockCompanionModule {
        id: companionModule
        anchors.fill: parent
        controller: root.appearanceController
        weather: root.weatherController
        timer: root.timerController
        Component.onCompleted: if (root.deck) root.deck.timerCompanion = companionModule
        Component.onDestruction: {
          if (root.deck && root.deck.timerCompanion === companionModule) root.deck.timerCompanion = null
        }
      }
    }
  }

  Component {
    id: clockTileComponent
    ClockCompanionTile {
      controller: root.appearanceController
      weather: root.weatherController
      timer: root.timerController
      interactionEnabled: !root.editing
      active: root.selected || !root.editing
    }
  }
  Component {
    id: genericCardComponent
    DeckCard {
      objectName: "moduleCard"
      title: root.moduleTitle
      subtitle: root.moduleSubtitle
      active: root.selected

      Loader {
        anchors.fill: parent
        sourceComponent: root.moduleId === "workspaces" ? workspaceComponent : commandComponent
      }
    }
  }
  Component {
    id: workspaceComponent
    WorkspaceModule {
      controller: WorkspaceController { shell: root.shell; primaryMonitor: root.primaryMonitor }
    }
  }
  Component {
    id: commandComponent
    CommandCenterModule {
      deck: root.deck
      controller: root.controller
      shell: root.shell
      launcherController: root.launcherController
      pluginDir: root.deck ? root.deck.pluginDir : ""
      primaryMonitor: root.primaryMonitor
    }
  }
}
