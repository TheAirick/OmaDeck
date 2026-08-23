import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string omarchyCommand: Quickshell.env("HOME") + "/.local/bin/alienware-to-omarchy"
  property string macCommand: Quickshell.env("HOME") + "/.local/bin/alienware-to-mac"
  property string pendingSource: ""
  property string statusText: ""

  height: Style.space(78)
  color: Style.normalFill
  radius: Style.cornerRadius
  padding: Style.spacing.controlPaddingX
  borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)

  function switchTo(source) {
    if (inputSwitch.running) return
    pendingSource = source
    statusText = "Switching…"
    inputSwitch.command = [source === "mac" ? macCommand : omarchyCommand]
    inputSwitch.running = true
  }

  Row {
    anchors.fill: parent
    anchors.topMargin: root.contentTopInset
    anchors.rightMargin: root.contentRightInset
    anchors.bottomMargin: root.contentBottomInset
    anchors.leftMargin: root.contentLeftInset
    spacing: Style.spacing.panelGap

    Column {
      width: parent.width - sourceButtons.width - parent.spacing
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.labelGap

      Text {
        text: "Alienware input"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        text: root.statusText || "Choose the active computer"
        color: root.statusText.indexOf("Failed") === 0 ? Color.urgent : Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    Row {
      id: sourceButtons
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.controlGap

      Button {
        text: "Omarchy"
        iconText: "󰌢"
        bordered: true
        enabled: !inputSwitch.running
        selected: root.pendingSource === "omarchy"
        onClicked: root.switchTo("omarchy")
      }

      Button {
        text: "Mac"
        iconText: "󰀵"
        bordered: true
        enabled: !inputSwitch.running
        selected: root.pendingSource === "mac"
        onClicked: root.switchTo("mac")
      }
    }
  }

  Process {
    id: inputSwitch
    running: false
    onExited: function(exitCode) {
      var source = root.pendingSource === "mac" ? "Mac" : "Omarchy"
      root.statusText = exitCode === 0 ? "Switched to " + source : "Failed to switch to " + source
      root.pendingSource = ""
      statusClear.restart()
    }
  }

  Timer {
    id: statusClear
    interval: 3500
    repeat: false
    onTriggered: root.statusText = ""
  }
}
