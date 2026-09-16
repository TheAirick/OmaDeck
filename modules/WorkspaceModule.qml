import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "../theme"
import "../theme/TextContrast.js" as Contrast
import "../components"

Item {
  id: root
  property var controller: null
  readonly property var workspaceRows: controller ? controller.workspaces : []
  readonly property int columnCount: Math.max(1, Math.min(5, Math.floor((width + Style.spacing.controlGap) / Style.space(184))))
  readonly property int rowCount: Math.ceil(workspaceRows.length / columnCount)
  readonly property real tileWidth: Math.max(0, (width - Style.spacing.controlGap * (columnCount - 1)) / columnCount)
  readonly property real tileHeight: Math.max(Style.space(210), (height - Style.spacing.controlGap * (rowCount - 1)) / Math.max(1, rowCount))

  Flickable {
    id: workspaceScroll
    anchors.fill: parent
    contentWidth: width
    contentHeight: workspaceGrid.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

    Grid {
      id: workspaceGrid
      width: parent.width
      columns: root.columnCount
      spacing: Style.spacing.controlGap

      Repeater {
        model: root.workspaceRows.length
        BorderSurface {
          id: workspaceTile
          required property int index
          readonly property var modelData: root.workspaceRows[index]
          objectName: "workspaceCard" + modelData.id
          readonly property bool occupied: modelData.occupied
          readonly property bool focused: modelData.focused
          width: root.tileWidth
          height: root.tileHeight
          radius: Style.cornerRadius
          color: Contrast.hex(Contrast.composite(occupied ? Style.normalFill : DeckColors.surface, DeckColors.surface))
          borderSpec: focused
            ? Border.hyprlandActiveSpec(Color.accent, 2)
            : Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)

          // Only the app rows own window actions. All remaining card space,
          // including list padding, belongs to workspace navigation.
          function pointInWindowList(position) {
            var local = windowsList.mapFromItem(workspaceTile, position.x, position.y)
            return local.x >= 0 && local.y >= 0 && local.x < windowsList.width && local.y < windowsList.height
          }


          TapHandler {
            id: cardTap
            property int pressedWorkspace: 0
            property bool beganOnWindow: false
            onPressedChanged: if (pressed) {
              pressedWorkspace = workspaceTile.modelData.id
              beganOnWindow = workspaceTile.pointInWindowList(point.position)
            }
            onTapped: if (!beganOnWindow && !workspaceTile.pointInWindowList(point.position)
              && pressedWorkspace === workspaceTile.modelData.id && root.controller)
                root.controller.focusWorkspace(pressedWorkspace)
          }

          Item {
            id: workspaceHeader
            objectName: "workspaceHeader" + workspaceTile.modelData.id
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Style.spacing.controlGap
            height: Style.space(68)
            Accessible.role: Accessible.Button
            Accessible.name: "Workspace " + workspaceTile.modelData.id + ", " + workspaceTile.modelData.windows.length + " windows"
            Accessible.onPressAction: if (root.controller) root.controller.focusWorkspace(workspaceTile.modelData.id)

            Text {
              id: workspaceNumber
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: String(workspaceTile.modelData.id)
              color: workspaceTile.occupied || workspaceTile.focused ? Color.foreground : DeckColors.secondaryText
              font.family: Style.font.family
              font.pixelSize: Style.font.displayLarge
              font.bold: true
            }
            Column {
              anchors.left: workspaceNumber.right
              anchors.leftMargin: Style.spacing.controlGap
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.labelGap
              Text {
                width: parent.width
                text: workspaceTile.focused ? "Current" : workspaceTile.occupied
                  ? workspaceTile.modelData.windows.length + (workspaceTile.modelData.windows.length === 1 ? " window" : " windows") : "Empty"
                color: DeckColors.secondaryTextOn(workspaceTile.color)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: workspaceTile.modelData.monitor
                visible: text !== ""
                color: DeckColors.secondaryTextOn(workspaceTile.color)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }
          }

          Rectangle {
            anchors.top: workspaceHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Style.spacing.controlGap
            height: Style.spacing.hairline
            color: Color.foreground
            opacity: 0.12
          }

          ListView {
            id: windowsList
            objectName: "workspaceWindows" + workspaceTile.modelData.id
            anchors.top: workspaceHeader.bottom
            anchors.topMargin: Style.spacing.controlGap * 2
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Style.spacing.controlGap
            anchors.rightMargin: Style.spacing.controlGap
            anchors.bottomMargin: Style.spacing.controlGap
            clip: true
            model: workspaceTile.modelData.windows.length
            // Flickable receives presses on its unused content area itself.
            // Handle that area here without stealing app-row taps or drags.
            TapHandler {
              property int pressedWorkspace: 0
              property bool beganOnWindow: false
              onPressedChanged: if (pressed) {
                pressedWorkspace = workspaceTile.modelData.id
                beganOnWindow = windowsList.indexAt(point.position.x + windowsList.contentX,
                  point.position.y + windowsList.contentY) >= 0
              }
              onTapped: if (!beganOnWindow && windowsList.indexAt(point.position.x + windowsList.contentX,
                point.position.y + windowsList.contentY) < 0 && pressedWorkspace === workspaceTile.modelData.id && root.controller)
                  root.controller.focusWorkspace(pressedWorkspace)
            }
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
            delegate: WorkspaceWindowRow {
              required property int index
              readonly property var modelData: workspaceTile.modelData.windows[index] || ({})
              width: windowsList.width
              windowRow: modelData
              backingColor: workspaceTile.color
              onActivated: if (root.controller) root.controller.focusWindow(modelData.address)
            }
          }

          Item {
            anchors.fill: windowsList
            visible: !workspaceTile.occupied
            Text {
              anchors.centerIn: parent
              width: parent.width
              text: "Tap to switch"
              horizontalAlignment: Text.AlignHCenter
              color: DeckColors.secondaryText
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }
}
