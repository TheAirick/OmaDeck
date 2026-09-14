import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "../theme"
import "../components"
import "../services"

Item {
  id: root
  property var deck: null
  property var shell: null
  property var appearanceController: null
  property bool active: true
  readonly property bool closeOnActivate: appearanceController ? appearanceController.workspaceCloseOnActivate === true : false
  property string primaryMonitor: "DP-1"
  readonly property bool stacked: width < Style.space(900)
  readonly property real scratchpadWidth: Math.min(Style.space(340), width * 0.25)

  WorkspaceController {
    id: workspaceController
    objectName: "workspaceController"
    shell: root.shell
    active: root.active
    primaryMonitor: root.primaryMonitor
    onNavigated: if (root.deck && root.closeOnActivate) root.deck.closeOverlay()
  }

  Flickable {
    anchors.fill: parent
    contentWidth: width
    contentHeight: panels.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

    Item {
      id: panels
      width: parent.width
      height: root.stacked ? Math.max(root.height, Style.space(640)) : root.height

      WorkspaceModule {
        id: workspaces
        objectName: "workspaceBrowser"
        width: root.stacked ? parent.width : parent.width - root.scratchpadWidth - Style.spacing.panelGap
        height: root.stacked ? Style.space(300) : parent.height
        controller: workspaceController
      }

      BorderSurface {
        id: scratchpad
        objectName: "scratchpadPanel"
        readonly property bool showing: workspaceController.scratchpadVisible
        x: root.stacked ? 0 : workspaces.width + Style.spacing.panelGap
        y: root.stacked ? workspaces.height + Style.spacing.panelGap : 0
        width: root.stacked ? parent.width : root.scratchpadWidth
        height: Math.max(0, parent.height - y)
        color: DeckColors.surface
        radius: Style.cornerRadius
        borderSpec: showing ? Border.hyprlandActiveSpec(Color.accent, 2)
          : Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)

        function pointInChild(child, position) {
          var local = child.mapFromItem(scratchpad, position.x, position.y)
          return local.x >= 0 && local.y >= 0 && local.x < child.width && local.y < child.height
        }

        // The list handles its own blank space and rows. Keep Return and Park
        // independent of the card's show/hide action.
        TapHandler {
          property bool beganOnControl: false
          onPressedChanged: if (pressed) beganOnControl = scratchpad.pointInChild(parkedList, point.position)
            || scratchpad.pointInChild(scratchpadActions, point.position)
          onTapped: if (!beganOnControl && !scratchpad.pointInChild(parkedList, point.position)
            && !scratchpad.pointInChild(scratchpadActions, point.position)) workspaceController.toggleScratchpad()
        }

        Column {
          id: scratchpadHeader
          objectName: "scratchpadHeader"
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Style.spacing.panelPadding
          spacing: Style.spacing.labelGap
          Accessible.role: Accessible.Button
          Accessible.name: scratchpad.showing ? "Hide scratchpad" : "Show scratchpad"
          Accessible.onPressAction: workspaceController.toggleScratchpad()
          Text {
            width: parent.width
            text: "Scratchpad · " + workspaceController.parkedWindows.length
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: workspaceController.parkedWindows.length
              ? (scratchpad.showing ? "Showing · tap to hide" : "Hidden · tap to show")
              : "Park a window here to get it out of the way."
            color: DeckColors.secondaryText
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        ListView {
          id: parkedList
          objectName: "parkedWindows"
          anchors.top: scratchpadHeader.bottom
          anchors.topMargin: Style.spacing.rowGap
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: scratchpadActions.top
          anchors.margins: Style.spacing.controlGap
          clip: true
          model: workspaceController.parkedWindows.length
          TapHandler {
            property bool beganOnWindow: false
            onPressedChanged: if (pressed) beganOnWindow = parkedList.indexAt(point.position.x + parkedList.contentX,
              point.position.y + parkedList.contentY) >= 0
            onTapped: if (!beganOnWindow && parkedList.indexAt(point.position.x + parkedList.contentX,
              point.position.y + parkedList.contentY) < 0) workspaceController.toggleScratchpad()
          }
          boundsBehavior: Flickable.StopAtBounds
          Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
          delegate: WorkspaceWindowRow {
            required property int index
            readonly property var modelData: workspaceController.parkedWindows[index] || ({})
            width: parkedList.width
            windowRow: modelData
            actionName: scratchpad.showing ? "Hide scratchpad" : "Show scratchpad"
            showReturn: true
            returnWorkspaceId: workspaceController.returnWorkspaceId
            onActivated: workspaceController.toggleScratchpad()
            onReturnRequested: workspaceController.returnWindow(modelData.address)
          }
        }

        Column {
          id: scratchpadActions
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: Style.spacing.controlGap
          spacing: Style.spacing.controlGap
          Button {
            objectName: "sendToScratchpadControl"
            width: parent.width
            height: Style.space(48)
            text: "Park focused window"
            enabled: workspaceController.canPark
            bordered: false
            onClicked: workspaceController.parkFocusedWindow()
          }
        }
      }
    }
  }
}
