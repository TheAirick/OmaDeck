import QtQuick
import qs.Commons
import qs.Ui
import "../theme"
import "../components"

Column {
  id: root
  property var controller: null
  property string step: "computer"
  readonly property var status: controller ? controller.setupStatus || null : null
  readonly property bool working: controller && controller.busy
  readonly property bool ready: status && status.state === "ready"
  readonly property bool setupOpened: !!(controller && controller.setupWindowOpened)
  signal stepRequested(string step)
  signal monitorChosen(string monitorId)
  signal cancelled()
  spacing: Style.spacing.panelGap

  Text {
    width: parent.width
    text: root.step === "computer" ? "1 / 3 · Prepare this computer" : "2 / 3 · Connect your monitor"
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.subtitle
    font.bold: true
    wrapMode: Text.WordWrap
  }
  Text {
    objectName: "monitorSetupInstructions"
    width: parent.width
    text: {
      if (root.step === "monitor") return "Use your monitor’s physical buttons to open its menu. Find DDC/CI, usually under System or Other Settings, and turn it on. This lets apps control the monitor through its display cable.\n\nKeep the monitor awake and connected to this computer by HDMI or DisplayPort, then find it below."
      if (root.working) return "Checking the software and display access on this computer…"
      if (root.setupOpened) return "A setup window has opened on your desktop. Enter your computer password if asked; the characters may not appear as you type. When that window says setup has finished, return here and tap Check again."
      if (root.ready) return "This computer has monitor-control support and access. Next, we’ll check your monitor. No input will change during setup."
      if (!root.status) return root.controller && root.controller.notice ? root.controller.notice : "First, check whether this computer is ready to control monitor inputs."
      if (root.status.state === "no-display") return "Monitor support is installed, but no display-control connection was found. Connect an external monitor by HDMI or DisplayPort. The next step explains what to check on the monitor."
      if (root.status.state === "missing-software") return "This computer needs monitor-control software. Install monitor support opens a setup window that guides you through installation and may ask for your computer password."
      return "The software is installed, but display access needs to be activated. Set up monitor access opens a window that handles this and may ask for your computer password. If access is still unavailable afterward, restart the computer and check again."
    }
    color: DeckColors.secondaryText
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
  }
  Text {
    width: parent.width
    visible: root.step === "computer" && root.status && !root.ready && !root.status.canPrepare
    text: "Automatic setup needs Omarchy’s package tools. Update Omarchy, reopen OmaDeck, and check again."
    color: DeckColors.secondaryText
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }
  Row {
    spacing: Style.spacing.controlGap
    Button {
      objectName: "monitorSetupPrimary"
      width: Math.min(Style.space(300), root.width - Style.space(100))
      height: Style.space(52)
      text: root.working ? "Working…" : root.step === "monitor" ? "Find my monitors"
        : root.setupOpened ? "Check again" : root.ready ? "Continue"
        : root.status && root.status.state === "no-display" ? "Monitor connection help"
        : !root.status || !root.status.canPrepare ? "Check computer"
        : root.status.state === "missing-software" ? "Install monitor support" : "Set up monitor access"
      bordered: true
      enabled: root.controller && !root.working
      onClicked: {
        if (root.step === "monitor") root.controller.scan()
        else if (root.setupOpened || !root.status) root.controller.checkSetup()
        else if (root.ready || root.status.state === "no-display") root.stepRequested("monitor")
        else if (!root.status.canPrepare) root.controller.checkSetup()
        else root.controller.openSetup()
      }
    }
    Button {
      width: Style.space(88)
      height: Style.space(52)
      text: root.step === "computer" ? "Cancel" : "Back"
      enabled: !root.working
      onClicked: root.step === "computer" ? root.cancelled() : root.stepRequested("computer")
    }
  }
  Column {
    width: parent.width
    visible: root.step === "monitor" && !root.working
    spacing: Style.spacing.controlGap
    Text {
      width: parent.width
      visible: !!(root.controller && root.controller.scanned && root.controller.detectedMonitors.length === 0)
      text: "No controllable monitor responded. Check that DDC/CI is enabled and this computer’s input is selected. If you use a dock, adapter, or KVM, try a direct display cable. Built-in laptop screens are not supported."
      color: DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
    }
    Text {
      width: parent.width
      visible: root.controller && !root.controller.scanned && root.controller.notice !== "Computer ready"
      text: root.controller ? root.controller.notice : ""
      color: DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
    }
    Repeater {
      model: root.controller ? root.controller.detectedMonitors : []
      PreferenceAction {
        required property var modelData
        objectName: "setupMonitor:" + modelData.id
        width: parent.width
        label: modelData.label
        description: modelData.error || "Ready to choose its input buttons"
        actionText: modelData.error ? "Unavailable" : "Choose"
        enabled: !modelData.error && !root.working
        onClicked: root.monitorChosen(modelData.id)
      }
    }
  }
}
