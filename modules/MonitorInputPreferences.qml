import QtQuick
import qs.Commons
import qs.Ui
import "../theme"
import "../components"

Column {
  id: root
  property var controller: null
  property string editingId: ""
  property string editingCode: ""
  property string setupStep: ""
  property bool initialized: false
  property bool componentReady: false
  signal setupNavigation()
  readonly property var configured: controller ? controller.monitors : []
  readonly property var editingMonitor: configured.find(function(row) { return row.id === root.editingId }) || null
  readonly property var detected: controller ? controller.detectedMonitors : []
  readonly property var detectedMonitor: detected.find(function(row) { return row.id === root.editingId }) || null
  readonly property var inputOptions: {
    var rows = detectedMonitor ? detectedMonitor.inputs.slice() : []
    var sources = editingMonitor ? editingMonitor.sources : []
    for (var source of sources) if (!rows.some(function(row) { return row.code === source.code }))
      rows.push({ code: source.code, label: portLabel(source.code) })
    return rows
  }
  readonly property var editingSource: editingMonitor
    ? editingMonitor.sources.find(function(row) { return row.code === root.editingCode }) || null : null
  spacing: Style.spacing.controlGap
  onConfiguredChanged: {
    if (!editingMonitor) editingId = configured.length ? configured[0].id : ""
    initialize()
  }
  onVisibleChanged: if (visible) initialize()
  onSetupStepChanged: setupNavigation()
  Component.onCompleted: { componentReady = true; initialize() }
  Connections {
    target: root.controller
    function onLoadedChanged() { root.initialize() }
  }

  function initialize() {
    if (!componentReady || !visible || initialized || !controller || !controller.loaded) return
    initialized = true
    editingId = controller.settings.selectedId || (configured.length ? configured[0].id : "")
    if (!configured.length) startSetup()
  }
  function startSetup() {
    setupStep = "computer"
    controller.checkSetup()
  }

  function portLabel(code) {
    var detectedInput = detectedMonitor ? detectedMonitor.inputs.find(function(row) { return row.code === code }) : null
    if (detectedInput) return detectedInput.label
    var names = { "0f": "DisplayPort 1", "10": "DisplayPort 2", "11": "HDMI 1", "12": "HDMI 2" }
    return names[code] || "Input 0x" + String(code).toUpperCase()
  }

  MonitorSetupGuide {
    objectName: "monitorSetupGuide"
    width: parent.width
    visible: root.setupStep === "computer" || root.setupStep === "monitor"
    controller: root.controller
    step: root.setupStep
    onStepRequested: step => root.setupStep = step
    onCancelled: root.setupStep = ""
    onMonitorChosen: id => {
      if (root.configured.some(function(row) { return row.id === id }) || root.controller.addMonitor(id)) {
        root.editingId = id
        root.editingCode = ""
        root.setupStep = "inputs"
      }
    }
  }
  Column {
    width: parent.width
    visible: root.setupStep === ""
    spacing: Style.spacing.controlGap
    PreferenceAction {
      objectName: "preferencesMonitorSetup"
      width: parent.width
      label: root.configured.length ? "Set up another monitor" : "Set up monitor switching"
      description: "Guided software, monitor, and input setup"
      actionText: "Start"
      enabled: root.controller && root.controller.loaded && !root.controller.busy
      onClicked: root.startSetup()
    }

    PreferenceToggle {
      objectName: "preferencesMonitorSwitching"
      width: parent.width
      height: Style.space(64)
      label: "Show monitor switching"
      description: "Add your monitor input buttons to Command Center"
      enabled: root.controller && root.controller.loaded && !root.controller.busy
      checked: root.controller ? root.controller.settings.enabled : false
      onClicked: root.controller.setShown(!checked)
    }
    Button {
      objectName: "preferencesScanMonitors"
      width: parent.width
      height: Style.space(52)
      text: root.controller && root.controller.busy ? "Working…" : "Scan connected monitors"
      iconText: "󰑓"
      leftAlign: true
      enabled: root.controller && !root.controller.busy
      onClicked: root.controller.scan()
    }
    Text {
      width: parent.width
      text: root.controller && root.controller.notice ? root.controller.notice
        : "Enable DDC/CI in your monitor's menu to control its inputs. Scanning does not switch inputs."
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    PreferenceChoice {
      objectName: "preferencesConfiguredMonitor"
      width: parent.width
      visible: root.configured.length > 0
      label: "Configured monitors"
      description: "Choose a monitor to change its input buttons"
      value: root.editingId
      options: root.configured.map(function(row) { return { value: row.id, label: row.label } })
      onChanged: value => { root.editingId = value; root.editingCode = "" }
    }
  }
  Column {
    width: parent.width
    visible: root.editingMonitor !== null && (root.setupStep === "" || root.setupStep === "inputs")
    spacing: Style.spacing.controlGap
    Text {
      width: parent.width
      text: root.setupStep === "inputs" ? "3 / 3 · Choose inputs for " + (root.editingMonitor ? root.editingMonitor.label : "your monitor") : "INPUT BUTTONS · CHOOSE UP TO FOUR"
      color: DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    Text {
      width: parent.width
      visible: root.setupStep === "inputs"
      text: "Keep only the ports with a cable connected. Under Button labels, choose a port and the computer or device plugged into it. Its name and icon will appear in Command Center."
      color: DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
    }
    Repeater {
      model: root.inputOptions.length
      PreferenceToggle {
        required property int index
        readonly property var source: root.inputOptions[index] || ({})
        readonly property var configuredSource: root.editingMonitor
          ? root.editingMonitor.sources.find(function(row) { return row.code === source.code }) || null : null
        objectName: "configuredInput:" + source.code
        width: parent.width
        height: Style.space(58)
        label: source.label || ""
        description: configuredSource && configuredSource.label !== source.label
          ? "Shown as " + configuredSource.label : "Show this input in Command Center"
        checked: configuredSource !== null
        enabled: root.controller && !root.controller.busy
        onClicked: root.controller.setSource(root.editingId, source.code, !checked, "")
      }
    }
    PreferenceChoice {
      objectName: "preferencesInputToLabel"
      width: parent.width
      label: "Button labels"
      description: "Choose a port, then the device connected to it"
      value: root.editingCode
      options: root.editingMonitor ? root.editingMonitor.sources.map(function(row) { return { value: row.code, label: root.portLabel(row.code) } }) : []
      onChanged: value => root.editingCode = value
    }
    PreferenceChoice {
      objectName: "preferencesInputLabel"
      width: parent.width
      visible: root.editingSource !== null
      label: "Connected device"
      description: "Sets the button name and icon in Command Center"
      value: root.editingSource ? root.editingSource.label : ""
      options: {
        var input = root.inputOptions.find(function(row) { return row.code === root.editingCode })
        var names = [input ? input.label : "Input", "Omarchy", "Mac", "Windows", "Linux", "Desktop", "Laptop", "Console"]
        if (root.editingSource && names.indexOf(root.editingSource.label) === -1) names.push(root.editingSource.label)
        return names.map(function(name) { return { value: name, label: name } })
      }
      onChanged: value => root.controller.setSource(root.editingId, root.editingCode, true, value)
    }
    Button {
      objectName: "preferencesRemoveMonitor"
      width: parent.width
      height: Style.space(48)
      text: "Remove this monitor from OmaDeck"
      visible: root.setupStep === ""
      leftAlign: true
      enabled: root.controller && !root.controller.busy
      onClicked: root.controller.removeMonitor(root.editingId)
    }
    Row {
      visible: root.setupStep === "inputs"
      spacing: Style.spacing.controlGap
      Button {
        objectName: "monitorSetupFinish"
        text: "Finish setup"
        width: Style.space(180); height: Style.space(52)
        bordered: true
        enabled: root.controller && !root.controller.busy
        onClicked: if (root.controller.setShown(true)) {
          root.setupStep = ""
          root.controller.notice = "Your input buttons are ready in Command Center"
        }
      }
      Button {
        text: "Back"
        width: Style.space(88); height: Style.space(52)
        enabled: root.controller && !root.controller.busy
        onClicked: root.setupStep = "monitor"
      }
    }
    Text {
      width: parent.width
      visible: root.setupStep === "inputs" && root.controller && root.controller.notice !== "Saved"
      text: root.controller ? root.controller.notice : ""
      color: DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
    }
  }
  Column {
    width: parent.width
    visible: root.setupStep === ""
    spacing: Style.spacing.controlGap
    Text {
      width: parent.width
      visible: root.detected.length > 0
      text: "DETECTED MONITORS"
      color: DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    Repeater {
      model: root.detected.length
      PreferenceAction {
        required property int index
        readonly property var monitor: root.detected[index] || ({})
        readonly property bool added: root.configured.some(function(row) { return row.id === monitor.id })
        objectName: "detectedMonitor:" + monitor.id
        width: parent.width
        label: monitor.label || "Monitor"
        description: monitor.error || (monitor.connector + (added ? " · Added" : ""))
        actionText: added ? "Edit" : "Add"
        enabled: root.controller && !root.controller.busy && !monitor.error
        onClicked: {
          if (added || root.controller.addMonitor(monitor.id)) root.editingId = monitor.id
          root.editingCode = ""
        }
      }
    }
  }
}
