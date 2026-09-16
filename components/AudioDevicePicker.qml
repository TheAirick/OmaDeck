import QtQuick
import qs.Commons
import "../theme"
import qs.Ui

Item {
  id: root
  objectName: "audioDevicePicker"
  required property var controller
  property string kind: "output"
  readonly property var devices: kind === "output" ? controller.outputs : controller.inputs
  readonly property string currentName: kind === "output" ? controller.outputName : controller.inputName
  signal closed()
  signal kindRequested(string value)

  onVisibleChanged: if (visible) {
    outputList.contentY = 0
    inputList.contentY = 0
  }

  Row {
    id: navigation
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Style.spacing.controlGap
    height: Style.space(48)
    Button {
      objectName: "audioDeviceBack"
      text: "Back"
      width: Style.space(64)
      height: parent.height
      onClicked: root.closed()
    }
    Button {
      objectName: "audioOutputTab"
      text: "Output"
      selected: root.kind === "output"
      width: (parent.width - Style.space(64) - parent.spacing * 2) / 2
      height: parent.height
      onClicked: root.kindRequested("output")
    }
    Button {
      objectName: "audioInputTab"
      text: "Mic"
      selected: root.kind === "input"
      width: (parent.width - Style.space(64) - parent.spacing * 2) / 2
      height: parent.height
      onClicked: root.kindRequested("input")
    }
  }

  Text {
    id: status
    anchors.top: navigation.bottom
    anchors.topMargin: Style.spacing.controlGap
    width: parent.width
    text: root.controller.busy ? "Switching…"
      : root.controller.error || (root.devices.length ? "Choose " + (root.kind === "output" ? "speakers or headphones" : "a microphone") : "No devices connected")
    wrapMode: Text.Wrap
    color: root.controller.error ? Color.urgent : DeckColors.secondaryText
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }

  Item {
    id: listArea
    anchors.top: status.bottom
    anchors.topMargin: Style.spacing.controlGap
    anchors.bottom: parent.bottom
    width: parent.width

    // Both scalar snapshots stay mounted while the picker is open. Switching
    // tabs only changes visibility, preserving row ownership and avoiding a
    // synchronous teardown/rebuild of Omarchy's themed controls on every tap.
    DeviceList {
      id: outputList
      anchors.fill: parent
      listKind: "output"
      entries: root.controller.outputs
      currentName: root.controller.outputName
      visible: root.kind === "output"
    }
    DeviceList {
      id: inputList
      anchors.fill: parent
      listKind: "input"
      entries: root.controller.inputs
      currentName: root.controller.inputName
      visible: root.kind === "input"
    }
  }

  component DeviceList: Flickable {
    id: deviceList
    required property string listKind
    required property var entries
    required property string currentName
    objectName: "audioDeviceList:" + listKind
    contentHeight: rows.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: rows
      width: deviceList.width
      spacing: Style.spacing.controlGap
      Repeater {
        model: root.visible ? deviceList.entries : []
        delegate: Button {
          id: deviceButton
          required property var modelData
          objectName: "audioDevice:" + modelData.name
          width: rows.width
          height: Math.max(Style.space(56), deviceLabel.implicitHeight + Style.spacing.controlGap * 2)
          bordered: true
          selected: deviceList.currentName === modelData.name
          enabled: !root.controller.busy
          Accessible.name: modelData.label + (selected ? ", selected" : "")
          onClicked: root.controller.selectDevice(deviceList.listKind, modelData.id, modelData.name)
          Text {
            id: deviceLabel
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.controlPaddingX
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.spacing.controlPaddingX * 2 - Style.space(26)
            text: deviceButton.modelData.label
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.controlPaddingX
            anchors.verticalCenter: parent.verticalCenter
            text: deviceButton.selected ? "✓" : ""
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.icon
          }
        }
      }
    }
  }
}
