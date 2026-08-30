import QtQuick
import qs.Commons
import "../modules"

Item {
  id: root

  property var controller: null
  property string path: ""
  property var deck: null
  property var shell: null
  property var appearanceController: null
  property var weatherController: null
  property var timerController: null
  property string primaryMonitor: "DP-1"

  readonly property int observedRevision: controller ? controller.revision : 0
  readonly property var node: {
    var revision = observedRevision
    return controller ? controller.nodeAt(path) : null
  }
  readonly property string moduleId: node ? String(node.moduleId || "") : ""
  readonly property bool selected: controller && controller.selectedPath === path
  readonly property string moduleTitle: moduleId === "clock" ? "OmaDeck"
    : moduleId === "workspaces" ? "Workspaces"
    : moduleId === "command-center" ? "Command center"
    : moduleId
  readonly property string moduleSubtitle: moduleId === "clock" ? "DP-3 · edge workspace"
    : moduleId === "workspaces" ? "Tap to focus on " + primaryMonitor
    : moduleId === "command-center" ? "Swipe from any edge"
    : ""

  z: moduleDrag.active ? 50 : 1
  scale: moduleDrag.active ? 0.98 : 1
  opacity: moduleDrag.active ? 0.86 : 1
  transform: Translate {
    x: moduleDrag.active ? moduleDrag.translation.x : 0
    y: moduleDrag.active ? moduleDrag.translation.y : 0
  }

  Behavior on scale { NumberAnimation { duration: 100 } }
  Behavior on opacity { NumberAnimation { duration: 100 } }

  Drag.active: moduleDrag.active
  Drag.source: root
  Drag.keys: ["omadeck-module"]
  Drag.hotSpot.x: width / 2
  Drag.hotSpot.y: height / 2

  DeckCard {
    anchors.fill: parent
    title: root.moduleTitle
    subtitle: root.moduleSubtitle
    active: root.selected || (root.moduleId === "clock" && !root.controller.editMode)

    Loader {
      anchors.fill: parent
      sourceComponent: root.moduleId === "clock" ? clockComponent
        : root.moduleId === "workspaces" ? workspaceComponent
        : commandComponent
    }
  }

  Rectangle {
    anchors.fill: parent
    visible: root.controller.editMode
    color: "transparent"
    border.color: root.selected ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.22)
    border.width: root.selected ? 3 : 1
    radius: Style.cornerRadius
    z: 10
  }

  Text {
    visible: root.controller.editMode
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Style.spacing.controlPaddingX
    text: root.selected ? "DRAG OR TAP A TARGET" : "TAP TO SWAP"
    color: root.selected ? Color.accent : Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
    z: 12
  }

  TapHandler {
    enabled: !root.controller.editMode
    longPressThreshold: 500
    onLongPressed: root.controller.beginEdit(root.path)
  }

  TapHandler {
    enabled: root.controller.editMode && !moduleDrag.active
    onTapped: root.controller.selectOrSwap(root.path)
  }

  DragHandler {
    id: moduleDrag
    enabled: root.controller.editMode
    target: null
    dragThreshold: Style.space(8)
    onActiveChanged: {
      if (active) root.controller.selectedPath = root.path
      else root.Drag.drop()
    }
  }

  DropArea {
    anchors.fill: parent
    keys: ["omadeck-module"]
    onDropped: function(drop) {
      if (drop.source && drop.source.path) root.controller.swap(drop.source.path, root.path)
      drop.accept()
    }
  }

  Component {
    id: clockComponent
    ClockModule {
      controller: root.appearanceController
      weather: root.weatherController
      timer: root.timerController
      interactionEnabled: !root.controller.editMode
    }
  }
  Component { id: workspaceComponent; WorkspaceModule { compact: true; primaryMonitor: root.primaryMonitor } }
  Component { id: commandComponent; CommandCenterModule { deck: root.deck; controller: root.controller } }
}
