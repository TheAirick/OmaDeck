import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property string selectedSection: ""
  property var stats: ({
    performance: { cpu: 0, memory: 0, cpuTemp: "", gpu: "", gpuTemp: "" },
    network: { interface: "", down: 0, up: 0 },
    storage: { used: 0, total: 0, free: 0, percent: 0 },
    clients: [], clipboard: []
  })

  function percent(value) { return Math.max(0, Math.min(100, Number(value || 0))) }
  function bytes(value) {
    var n = Number(value || 0)
    if (n >= 1073741824) return (n / 1073741824).toFixed(n >= 10737418240 ? 0 : 1) + " GB"
    if (n >= 1048576) return (n / 1048576).toFixed(1) + " MB"
    if (n >= 1024) return (n / 1024).toFixed(0) + " KB"
    return n.toFixed(0) + " B"
  }
  function rate(value) { return bytes(value) + "/s" }
  function sectionTitle(section) {
    return ({performance:"Performance", network:"Network", applications:"Applications", clipboard:"Clipboard", storage:"Storage"})[section] || "System"
  }
  function clipboardPreview(entry) {
    if (!entry) return "No recent entries"
    if (entry.type === "image") return "Image · " + (entry.capturedAt || "recently")
    return String(entry.text || "").replace(/\s+/g, " ").trim() || "Empty text"
  }
  function copyClipboard(entry) {
    if (!entry) return
    if (entry.type === "image") {
      Quickshell.execDetached(["omarchy-clipboard-paste-file", "--copy-only", entry.mime || "image/png", entry.path])
    } else {
      Quickshell.execDetached(["omarchy-clipboard-paste-text", "--copy-only", "--history-index", String(entry.historyIndex)])
    }
  }
  function focusClient(client) {
    if (client && client.address) Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + client.address])
  }

  Process {
    id: statsProcess
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/pretty.omadeck/scripts/system-stats"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.stats = JSON.parse(text) } catch (error) { console.warn("OmaDeck system stats:", error) }
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statsProcess.running) statsProcess.running = true
  }

  Item {
    id: overview
    anchors.fill: parent
    opacity: root.selectedSection === "" ? 1 : 0
    x: root.selectedSection === "" ? 0 : -Style.space(28)
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160 } }
    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Text {
      id: overviewTitle
      text: "System"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.bold: true
    }

    Text {
      anchors.right: parent.right
      anchors.baseline: overviewTitle.baseline
      text: "Live overview"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    Column {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.controlGap

      SystemStrip { iconText: "󰍛"; title: "Performance"; summary: root.stats.performance.cpu + "% CPU  ·  " + root.stats.performance.memory + "% RAM"; onTriggered: root.selectedSection = "performance" }
      SystemStrip { iconText: "󰛳"; title: "Network"; summary: "↓ " + root.rate(root.stats.network.down) + "  ↑ " + root.rate(root.stats.network.up); onTriggered: root.selectedSection = "network" }
      SystemStrip { iconText: "󰣆"; title: "Applications"; summary: root.stats.clients.length + " windows open"; onTriggered: root.selectedSection = "applications" }
      SystemStrip { iconText: "󰅇"; title: "Clipboard"; summary: root.clipboardPreview(root.stats.clipboard[0]); onTriggered: root.selectedSection = "clipboard" }
      SystemStrip { iconText: "󰋊"; title: "Storage"; summary: root.stats.storage.percent + "% used  ·  " + root.bytes(root.stats.storage.free) + " free"; onTriggered: root.selectedSection = "storage" }
    }
  }

  Item {
    id: detail
    anchors.fill: parent
    opacity: root.selectedSection !== "" ? 1 : 0
    x: root.selectedSection !== "" ? 0 : Style.space(28)
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160 } }
    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Item {
      id: detailHeader
      width: parent.width
      height: Style.space(34)

      Text {
        id: backIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅁"
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.display
      }
      Text {
        anchors.left: backIcon.right
        anchors.leftMargin: Style.spacing.controlGap
        anchors.verticalCenter: parent.verticalCenter
        text: root.sectionTitle(root.selectedSection)
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }
      HoverHandler { id: backHover }
      TapHandler { onTapped: root.selectedSection = "" }
    }

    Loader {
      anchors.top: detailHeader.bottom
      anchors.topMargin: Style.spacing.panelGap
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      sourceComponent: root.selectedSection === "performance" ? performanceDetail
        : root.selectedSection === "network" ? networkDetail
        : root.selectedSection === "applications" ? applicationsDetail
        : root.selectedSection === "clipboard" ? clipboardDetail
        : root.selectedSection === "storage" ? storageDetail : null
    }
  }

  component SystemStrip: BorderSurface {
    id: strip
    property string iconText: ""
    property string title: ""
    property string summary: ""
    signal triggered()
    width: parent ? parent.width : 0
    height: Style.space(48)
    color: stripTap.pressed ? Style.pressedFill : (stripHover.hovered ? Style.hoverFill : Style.normalFill)
    radius: Style.cornerRadius
    borderSpec: Border.controlSpec(stripHover.hovered ? "hover" : "normal", Color.foreground, Color.accent, Color.urgent)
    Text { id: stripIcon; anchors.left: parent.left; anchors.leftMargin: Style.spacing.panelGap; anchors.verticalCenter: parent.verticalCenter; text: strip.iconText; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.display }
    Column { anchors.left: stripIcon.right; anchors.leftMargin: Style.spacing.panelGap; anchors.right: stripArrow.left; anchors.rightMargin: Style.spacing.controlGap; anchors.verticalCenter: parent.verticalCenter; spacing: Style.spacing.labelGap
      Text { width: parent.width; text: strip.title; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
      Text { width: parent.width; text: strip.summary; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
    }
    Text { id: stripArrow; anchors.right: parent.right; anchors.rightMargin: Style.spacing.panelGap; anchors.verticalCenter: parent.verticalCenter; text: "󰅂"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.body }
    HoverHandler { id: stripHover }
    TapHandler { id: stripTap; onTapped: strip.triggered() }
  }

  component Meter: Item {
    id: meter
    property string label: ""
    property string valueText: ""
    property real value: 0
    height: Style.space(42)
    Text { id: meterLabel; text: meter.label; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
    Text { anchors.right: parent.right; text: meter.valueText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: Style.space(4); radius: height / 2; color: Style.normalFill
      Rectangle { width: parent.width * root.percent(meter.value) / 100; height: parent.height; radius: parent.radius; color: Color.accent; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } }
    }
  }

  Component { id: performanceDetail
    Column { spacing: Style.spacing.panelGap
      Meter { width: parent.width; label: "CPU"; value: root.stats.performance.cpu; valueText: root.stats.performance.cpu + "%" + (root.stats.performance.cpuTemp ? "  ·  " + root.stats.performance.cpuTemp + "°C" : "") }
      Meter { width: parent.width; label: "GPU"; value: root.stats.performance.gpu; valueText: (root.stats.performance.gpu || 0) + "%" + (root.stats.performance.gpuTemp ? "  ·  " + root.stats.performance.gpuTemp + "°C" : "") }
      Meter { width: parent.width; label: "Memory"; value: root.stats.performance.memory; valueText: root.bytes(root.stats.performance.memoryUsed) + " / " + root.bytes(root.stats.performance.memoryTotal) }
      Text { width: parent.width; text: "Updates every two seconds"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter }
    }
  }

  Component { id: networkDetail
    Column { spacing: Style.spacing.panelGap
      SystemStrip { iconText: "󰁅"; title: "Download"; summary: root.rate(root.stats.network.down) }
      SystemStrip { iconText: "󰁝"; title: "Upload"; summary: root.rate(root.stats.network.up) }
      SystemStrip { iconText: "󰈀"; title: "Interface"; summary: root.stats.network.interface || "Not connected" }
    }
  }

  Component { id: applicationsDetail
    Flickable { clip: true; contentHeight: appsColumn.height; boundsBehavior: Flickable.StopAtBounds
      Column { id: appsColumn; width: parent.width; spacing: Style.spacing.controlGap
        Repeater { model: root.stats.clients
          SystemStrip { required property var modelData; iconText: "󰣆"; title: modelData.class || "Application"; summary: "Workspace " + modelData.workspace + "  ·  " + (modelData.title || "Untitled"); onTriggered: root.focusClient(modelData) }
        }
      }
    }
  }

  Component { id: clipboardDetail
    Flickable { clip: true; contentHeight: clipboardColumn.height; boundsBehavior: Flickable.StopAtBounds
      Column { id: clipboardColumn; width: parent.width; spacing: Style.spacing.controlGap
        Repeater { model: root.stats.clipboard
          SystemStrip { required property var modelData; iconText: modelData.type === "image" ? "󰋩" : "󰅇"; title: modelData.type === "image" ? "Image" : "Text"; summary: root.clipboardPreview(modelData); onTriggered: root.copyClipboard(modelData) }
        }
      }
    }
  }

  Component { id: storageDetail
    Column { spacing: Style.spacing.panelGap
      Meter { width: parent.width; label: "System disk"; value: root.stats.storage.percent; valueText: root.stats.storage.percent + "%" }
      SystemStrip { iconText: "󰋊"; title: "Used"; summary: root.bytes(root.stats.storage.used) }
      SystemStrip { iconText: "󰉋"; title: "Available"; summary: root.bytes(root.stats.storage.free) }
      SystemStrip { iconText: "󰒋"; title: "Capacity"; summary: root.bytes(root.stats.storage.total) }
    }
  }
}
