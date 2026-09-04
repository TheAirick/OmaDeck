import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BorderSurface {
  id: root
  objectName: "monitorInputModule"

  property string omarchyCommand: Quickshell.env("HOME") + "/.local/bin/alienware-to-omarchy"
  property string macCommand: Quickshell.env("HOME") + "/.local/bin/alienware-to-mac"
  property string pendingSource: ""
  property string statusText: ""

  height: Style.space(92)
  color: Style.normalFill
  radius: Style.cornerRadius
  padding: 0
  clip: true
  borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)

  function switchTo(source) {
    if (inputSwitch.running) return
    pendingSource = source
    statusText = "Switching…"
    inputSwitch.command = [
      "/usr/bin/env", "PATH=/usr/bin:/usr/share/omarchy/bin",
      "/usr/bin/timeout", "--signal=TERM", "--kill-after=1s", "15s",
      "/usr/bin/bash", source === "mac" ? macCommand : omarchyCommand
    ]
    inputSwitch.running = true
  }

  Item {
    id: omarchyButton
    x: root.contentLeftInset
    y: root.contentTopInset
    width: Math.floor((root.width - root.contentLeftInset - root.contentRightInset) / 2)
    height: root.height - root.contentTopInset - root.contentBottomInset
    opacity: inputSwitch.running && root.pendingSource !== "omarchy" ? 0.42 : 1

    Rectangle {
      anchors.fill: parent
      color: omarchyTap.pressed ? Style.pressedFill : (omarchyHover.hovered ? Style.hoverFill : "transparent")
    }

    Column {
      anchors.centerIn: parent
      spacing: Style.spacing.labelGap

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: ""
        color: Color.accent
        font.family: "omarchy"
        font.pixelSize: Style.font.displayLarge
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.pendingSource === "omarchy" ? "Switching…" : "Omarchy"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }

    HoverHandler { id: omarchyHover; enabled: !inputSwitch.running }
    TapHandler { id: omarchyTap; enabled: !inputSwitch.running; onTapped: root.switchTo("omarchy") }
  }

  Column {
    anchors.centerIn: parent
    spacing: Style.spacing.labelGap
    z: 5

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "󰍹"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.icon
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.statusText || "Alienware"
      color: root.statusText.indexOf("Failed") === 0 ? Color.urgent : Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: root.statusText !== ""
    }
  }

  Item {
    id: macButton
    x: Math.ceil(root.width / 2)
    y: root.contentTopInset
    width: root.width - x - root.contentRightInset
    height: root.height - root.contentTopInset - root.contentBottomInset
    opacity: inputSwitch.running && root.pendingSource !== "mac" ? 0.42 : 1

    Rectangle {
      anchors.fill: parent
      color: macTap.pressed ? Style.pressedFill : (macHover.hovered ? Style.hoverFill : "transparent")
    }

    Column {
      anchors.centerIn: parent
      spacing: Style.spacing.labelGap

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "󰀵"
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.displayLarge
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.pendingSource === "mac" ? "Switching…" : "Mac"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }

    HoverHandler { id: macHover; enabled: !inputSwitch.running }
    TapHandler { id: macTap; enabled: !inputSwitch.running; onTapped: root.switchTo("mac") }
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
