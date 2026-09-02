import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "../components"

Item {
  id: root

  property var deck: null
  property string primaryMonitor: "DP-1"

  function toggleScratchpad() {
    Quickshell.execDetached([
      "/usr/bin/hyprctl", "dispatch",
      "hl.dsp.workspace.toggle_special(\"scratchpad\")"
    ])
    if (deck) deck.closeOverlay()
  }

  function sendFocusedToScratchpad() {
    Quickshell.execDetached([
      "/usr/bin/hyprctl", "dispatch",
      "hl.dsp.window.move({ workspace = \"special:scratchpad\", follow = false })"
    ])
    if (deck) deck.closeOverlay()
  }

  Row {
    anchors.fill: parent
    spacing: Style.spacing.panelGap

    BorderSurface {
      width: parent.width * 0.64
      height: parent.height
      color: Style.normalFill
      radius: Style.cornerRadius
      padding: Style.spacing.panelPadding
      borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)

      Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Style.spacing.panelPadding
        text: "Workspaces"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      WorkspaceModule {
        anchors.fill: parent
        anchors.margins: Style.spacing.panelPadding
        compact: false
        singleRow: false
        expandToFit: true
        primaryMonitor: root.primaryMonitor
      }
    }

    BorderSurface {
      width: parent.width - x
      height: parent.height
      color: Style.normalFill
      radius: Style.cornerRadius
      padding: Style.spacing.panelPadding
      borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)

      Column {
        anchors.fill: parent
        anchors.margins: Style.spacing.panelPadding
        spacing: Style.spacing.panelGap

        Text {
          text: "Scratchpad"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          width: parent.width
          text: "Show parked windows on " + root.primaryMonitor + " or send the last focused window there."
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Button {
          objectName: "toggleScratchpadControl"
          width: parent.width
          height: Style.space(68)
          text: "Toggle scratchpad"
          iconText: "󰖲"
          iconSize: Style.font.displayLarge
          bordered: true
          selected: true
          tooltipText: "Toggle Omarchy scratchpad"
          onClicked: root.toggleScratchpad()
        }

        Button {
          objectName: "sendToScratchpadControl"
          width: parent.width
          height: Style.space(68)
          text: "Park focused window"
          iconText: "󰍹"
          iconSize: Style.font.displayLarge
          bordered: true
          tooltipText: "Move the focused window to scratchpad"
          onClicked: root.sendFocusedToScratchpad()
        }

        Button {
          objectName: "overviewClipboardControl"
          width: parent.width
          height: Style.space(58)
          text: "Clipboard"
          iconText: "󰅇"
          bordered: true
          tooltipText: "Open clipboard controls"
          onClicked: if (root.deck) root.deck.showSystemSection("clipboard")
        }
      }
    }
  }
}
