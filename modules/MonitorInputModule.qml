import QtQuick
import qs.Commons
import qs.Ui
import "../theme"

BorderSurface {
  id: root
  objectName: "monitorInputModule"
  property var controller: null
  readonly property var monitor: controller ? controller.selectedMonitor : null
  readonly property bool multipleMonitors: controller && controller.monitors.length > 1
  readonly property bool centeredMonitor: monitor && monitor.sources.length === 2 && width >= Style.space(360)
  readonly property real navigationWidth: multipleMonitors ? Style.space(48) : 0
  readonly property real monitorLabelWidth: centeredMonitor ? Math.min(Style.space(128), width * 0.24) : 0
  height: Style.space(104)
  color: Style.normalFill
  radius: Style.cornerRadius
  padding: 0
  clip: true
  borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)

  function switchTo(id, code) {
    if (!root.enabled || !controller || controller.busy) return false
    return controller.switchInput(id, code)
  }

  function sourceIcon(label) {
    switch (String(label || "").trim().toLowerCase()) {
    case "omarchy": return ""
    case "mac": return "󰀵"
    case "windows": return "󰍲"
    case "linux": return "󰌽"
    case "laptop": return "󰌢"
    case "console": return "󰊴"
    default: return "󰍹"
    }
  }

  Item {
    id: controls
    x: root.contentLeftInset
    y: root.contentTopInset
    width: root.width - root.contentLeftInset - root.contentRightInset
    height: root.height - root.contentTopInset - root.contentBottomInset
    Button {
      objectName: "previousMonitor"
      anchors.left: parent.left
      width: Style.space(48)
      height: root.centeredMonitor ? parent.height : Style.space(44)
      text: "‹"
      visible: root.multipleMonitors
      enabled: root.enabled && root.controller && !root.controller.busy
      Accessible.name: "Previous monitor"
      onClicked: root.controller.cycleMonitor(-1)
    }
    Item {
      id: monitorDetails
      objectName: "monitorDetails"
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.alignWhenCentered: false
      width: root.centeredMonitor ? root.monitorLabelWidth : parent.width - root.navigationWidth * 2
      height: root.centeredMonitor ? parent.height : Style.space(44)
      Column {
        anchors.centerIn: parent
        width: parent.width - Style.spacing.controlGap
        spacing: Style.spacing.labelGap
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰍹"
          color: DeckColors.secondaryTextOn(root.color)
          font.family: Style.font.family
          font.pixelSize: Style.font.icon
        }
        Text {
          width: parent.width
          text: root.controller && root.controller.switchStatus ? root.controller.switchStatus
            : root.monitor ? root.monitor.label : "Monitor inputs"
          horizontalAlignment: Text.AlignHCenter
          wrapMode: root.centeredMonitor ? Text.WordWrap : Text.NoWrap
          maximumLineCount: root.centeredMonitor ? 3 : 1
          elide: Text.ElideRight
          textFormat: Text.PlainText
          color: DeckColors.secondaryTextOn(root.color)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
    Button {
      objectName: "nextMonitor"
      anchors.right: parent.right
      width: Style.space(48)
      height: root.centeredMonitor ? parent.height : Style.space(44)
      text: "›"
      visible: root.multipleMonitors
      enabled: root.enabled && root.controller && !root.controller.busy
      Accessible.name: "Next monitor"
      onClicked: root.controller.cycleMonitor(1)
    }
  }
  Item {
    x: controls.x + (root.centeredMonitor ? root.navigationWidth : 0)
    y: controls.y + (root.centeredMonitor ? 0 : Style.space(44))
    width: controls.width - (root.centeredMonitor ? root.navigationWidth * 2 : 0)
    height: controls.height - (root.centeredMonitor ? 0 : Style.space(44))
    Repeater {
      model: root.monitor ? root.monitor.sources.length : 0
      Item {
        id: sourceButton
        required property int index
        readonly property var source: root.monitor ? root.monitor.sources[index] || ({}) : ({})
        x: index * (width + root.monitorLabelWidth)
        width: (parent.width - root.monitorLabelWidth) / Math.max(1, root.monitor ? root.monitor.sources.length : 0)
        height: parent.height
        objectName: "monitorSource:" + source.code
        Accessible.role: Accessible.Button
        Accessible.name: (source.label || "Input") + " on " + (root.monitor ? root.monitor.label : "monitor")
        Accessible.onPressAction: if (root.monitor) root.switchTo(root.monitor.id, source.code)
        Rectangle {
          anchors.fill: parent
          color: tap.pressed ? Style.pressedFill : hover.hovered ? Style.hoverFill : "transparent"
        }
        Column {
          anchors.centerIn: parent
          width: parent.width - Style.spacing.controlGap
          spacing: Style.spacing.labelGap
          Text {
            objectName: "monitorSourceIcon:" + sourceButton.source.code
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.sourceIcon(sourceButton.source.label)
            color: root.controller && root.controller.busy ? DeckColors.secondaryTextOn(root.color) : Color.accent
            font.family: text === "" ? "omarchy" : Style.font.family
            font.pixelSize: root.centeredMonitor ? Style.font.displayLarge : Style.font.iconLarge
          }
          Text {
            width: parent.width
            text: sourceButton.source.label || ""
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: root.centeredMonitor ? Text.WordWrap : Text.NoWrap
            maximumLineCount: root.centeredMonitor ? 2 : 1
            elide: Text.ElideRight
            color: root.controller && root.controller.busy ? DeckColors.secondaryTextOn(root.color) : Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }
        }
        HoverHandler { id: hover; enabled: root.enabled && root.controller && !root.controller.busy }
        TapHandler {
          id: tap
          enabled: root.enabled && root.controller && !root.controller.busy
          property string pressedMonitor: ""
          property string pressedCode: ""
          onPressedChanged: if (pressed && root.monitor) { pressedMonitor = root.monitor.id; pressedCode = sourceButton.source.code }
          onTapped: if (root.monitor && pressedMonitor === root.monitor.id && pressedCode === sourceButton.source.code)
            root.switchTo(pressedMonitor, pressedCode)
        }
      }
    }
  }
}
