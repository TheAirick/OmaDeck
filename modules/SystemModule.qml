import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ClipboardDeletePolicy.js" as ClipboardDeletePolicy

Item {
  id: root

  property var shell: null
  property string selectedSection: ""
  property var selectedClipboard: null
  property string selectedClientAddress: ""
  property bool forceKillArmed: false
  property string clipboardNotice: ""
  property var cpuHistory: []
  property var gpuHistory: []
  property var memoryHistory: []
  property var downloadHistory: []
  property var uploadHistory: []
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
  function hasLeaf() {
    return (selectedSection === "clipboard" && selectedClipboard)
      || (selectedSection === "applications" && selectedClientAddress !== "")
  }
  function leafTitle() {
    if (selectedSection === "clipboard" && selectedClipboard) return selectedClipboard.type === "image" ? "Image" : "Text"
    if (selectedSection === "applications") {
      var client = currentClient()
      if (!client) return "Closed"
      var name = String(client.class || "Application")
      if (name === "zen") return "Zen"
      if (name === "discord") return "Discord"
      if (name.indexOf("ghostty") !== -1) return "Ghostty"
      if (name.indexOf("Nautilus") !== -1) return "Files"
      return name.charAt(0).toUpperCase() + name.slice(1)
    }
    return ""
  }
  function returnToSystem() {
    selectedClipboard = null
    selectedClientAddress = ""
    forceKillArmed = false
    selectedSection = ""
  }
  function returnToSection() {
    selectedClipboard = null
    selectedClientAddress = ""
    forceKillArmed = false
  }
  function appendSample(history, value) { return history.concat([Number(value || 0)]).slice(-45) }
  function peak(history) {
    var result = 0
    for (var i = 0; i < history.length; i++) result = Math.max(result, Number(history[i] || 0))
    return result
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
      Quickshell.execDetached(["omarchy-clipboard-paste-text", "--copy-only", entry.text || ""])
    }
    clipboardNotice = "Copied"
    noticeTimer.restart()
  }
  function clipboardOwner() {
    var loader = root.shell && root.shell.panelLoaders
      ? root.shell.panelLoaders["omarchy.clipboard"] : null
    return loader && loader.item ? loader.item : null
  }
  function deleteClipboard(entry) {
    if (!entry) return
    var owner = clipboardOwner()
    if (!owner || !Array.isArray(owner.history)) {
      clipboardNotice = "Clipboard unavailable"
      noticeTimer.restart()
      return
    }
    var result = ClipboardDeletePolicy.removeEntry(owner.history, entry)
    if (!result.ok) {
      clipboardNotice = "History changed · try again"
      noticeTimer.restart()
      refreshTimer.restart()
      return
    }
    // The built-in clipboard component is the sole history writer. Keep image
    // payload files rather than racing a new capture/reference with eager
    // filesystem cleanup; content-addressed captures safely reuse them.
    var saved = false
    try {
      var limit = Math.max(0, Number(owner.historyLimit || 300))
      clipboardHistoryFile.setText(JSON.stringify(result.history.slice(0, limit), null, 2) + "\n")
      saved = clipboardHistoryFile.waitForJob()
    } catch (error) {
      console.warn("OmaDeck clipboard delete:", error)
    }
    if (!saved) {
      clipboardNotice = "Delete failed"
      noticeTimer.restart()
      return
    }
    owner.history = result.history
    if (owner.opened && typeof owner.rebuildDisplay === "function") owner.rebuildDisplay()
    selectedClipboard = null
    clipboardNotice = "Deleted"
    noticeTimer.restart()
    refreshTimer.restart()
  }
  function showClipboard(entry) { selectedClipboard = entry }
  function goBack() {
    if (selectedSection === "clipboard" && selectedClipboard) selectedClipboard = null
    else if (selectedSection === "applications" && selectedClientAddress !== "") { selectedClientAddress = ""; forceKillArmed = false }
    else selectedSection = ""
  }
  function summon(panel) {
    if (shell && typeof shell.summon === "function") shell.summon(panel, "{}")
    else Quickshell.execDetached(["omarchy-shell", "shell", "summon", panel])
  }
  function focusClient(client) {
    if (client && client.address) Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + client.address])
  }
  function applicationIcon(client) {
    var value = String(client && client.class || "").toLowerCase()
    if (value.indexOf("ghostty") !== -1 || value.indexOf("terminal") !== -1) return "󰆍"
    if (value === "zen" || value.indexOf("chrom") !== -1 || value.indexOf("firefox") !== -1) return "󰖟"
    if (value.indexOf("nautilus") !== -1 || value.indexOf("file") !== -1) return "󰉋"
    if (value.indexOf("discord") !== -1 || value.indexOf("vesktop") !== -1) return "󰙯"
    if (value.indexOf("obsidian") !== -1) return "󰠮"
    if (value.indexOf("hermes") !== -1) return "󰚩"
    if (value.indexOf("omawrite") !== -1) return "󰈙"
    return "󰣆"
  }
  function inspectClient(client) { if (client) selectedClientAddress = client.address || "" }
  function currentClient() {
    for (var i = 0; i < stats.clients.length; i++) if (stats.clients[i].address === selectedClientAddress) return stats.clients[i]
    return null
  }
  function processState(client) {
    if (!client) return "Closed"
    var state = String(client.state || "?").charAt(0)
    return ({R:"Running", S:"Sleeping", I:"Idle", D:"Uninterruptible", T:"Stopped", Z:"Zombie"})[state] || "Unknown"
  }
  function elapsed(seconds) {
    var total = Number(seconds || 0)
    var hours = Math.floor(total / 3600)
    var minutes = Math.floor((total % 3600) / 60)
    return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m"
  }
  function workspaceLabel(client) {
    if (!client) return "—"
    if (Number(client.workspace) < 0) return String(client.workspaceName || "Special").replace(/^special:/, "")
    return String(client.workspace)
  }
  function closeClient(client) {
    if (client && client.address) Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", "address:" + client.address])
  }
  function forceKillClient(client) {
    if (!client || !client.pid) return
    if (!forceKillArmed) { forceKillArmed = true; killTimer.restart(); return }
    Quickshell.execDetached(["kill", "-KILL", String(client.pid)])
    forceKillArmed = false
    selectedClientAddress = ""
  }

  Process {
    id: statsProcess
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/pretty.omadeck/scripts/system-stats"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var next = JSON.parse(text)
          root.stats = next
          root.cpuHistory = root.appendSample(root.cpuHistory, next.performance.cpu)
          root.gpuHistory = root.appendSample(root.gpuHistory, next.performance.gpu)
          root.memoryHistory = root.appendSample(root.memoryHistory, next.performance.memory)
          root.downloadHistory = root.appendSample(root.downloadHistory, next.network.down)
          root.uploadHistory = root.appendSample(root.uploadHistory, next.network.up)
        } catch (error) { console.warn("OmaDeck system stats:", error) }
      }
    }
  }

  FileView {
    id: clipboardHistoryFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-history.json"
    atomicWrites: true
    printErrors: false
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statsProcess.running) statsProcess.running = true
  }

  Timer { id: refreshTimer; interval: 250; onTriggered: if (!statsProcess.running) statsProcess.running = true }
  Timer { id: noticeTimer; interval: 2400; onTriggered: root.clipboardNotice = "" }
  Timer { id: killTimer; interval: 2500; onTriggered: root.forceKillArmed = false }

  BorderSurface {
    z: 500
    visible: root.clipboardNotice !== ""
    anchors.top: parent.top
    anchors.right: parent.right
    width: Math.max(Style.space(150), noticeText.implicitWidth + Style.spacing.panelGap * 2 + Style.space(28))
    height: Style.space(38)
    color: Style.hoverFill
    radius: Style.cornerRadius
    borderSpec: Border.controlSpec("hover", Color.foreground, Color.accent, Color.urgent)

    Row {
      anchors.centerIn: parent
      height: Style.space(24)
      spacing: Style.spacing.controlGap
      Text {
        height: parent.height
        text: root.clipboardNotice === "Copied" ? "󰆏"
          : root.clipboardNotice === "Deleted" ? "󰆴" : "󰅖"
        color: root.clipboardNotice === "Copied" || root.clipboardNotice === "Deleted"
          ? Color.accent : Color.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        verticalAlignment: Text.AlignVCenter
      }
      Text {
        id: noticeText
        height: parent.height
        text: root.clipboardNotice
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        verticalAlignment: Text.AlignVCenter
      }
    }
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

      Row {
        anchors.left: parent.left
        anchors.top: parent.top
        height: parent.height
        spacing: Style.spacing.controlGap

        BreadcrumbPart { label: "System"; navigable: true; onTriggered: root.returnToSystem() }
        Text { text: "󰅂"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.body }
        BreadcrumbPart { label: root.sectionTitle(root.selectedSection); navigable: root.hasLeaf(); onTriggered: root.returnToSection() }
        Text { visible: root.hasLeaf(); text: "󰅂"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.body }
        BreadcrumbPart { visible: root.hasLeaf(); label: root.leafTitle(); navigable: false }
      }
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
    property bool navigable: true
    signal triggered()
    width: parent ? parent.width : 0
    height: Style.space(48)
    color: strip.navigable && stripTap.pressed ? Style.pressedFill : (strip.navigable && stripHover.hovered ? Style.hoverFill : Style.normalFill)
    radius: Style.cornerRadius
    borderSpec: Border.controlSpec(strip.navigable && stripHover.hovered ? "hover" : "normal", Color.foreground, Color.accent, Color.urgent)
    Text { id: stripIcon; anchors.left: parent.left; anchors.leftMargin: Style.spacing.panelGap; anchors.verticalCenter: parent.verticalCenter; text: strip.iconText; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.display }
    Column { anchors.left: stripIcon.right; anchors.leftMargin: Style.spacing.panelGap; anchors.right: stripArrow.left; anchors.rightMargin: Style.spacing.controlGap; anchors.verticalCenter: parent.verticalCenter; spacing: Style.spacing.labelGap
      Text { width: parent.width; text: strip.title; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
      Text { width: parent.width; text: strip.summary; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
    }
    Text { id: stripArrow; visible: strip.navigable; anchors.right: parent.right; anchors.rightMargin: Style.spacing.panelGap; anchors.verticalCenter: parent.verticalCenter; text: "󰅂"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.body }
    HoverHandler { id: stripHover; enabled: strip.navigable }
    TapHandler { id: stripTap; enabled: strip.navigable; onTapped: strip.triggered() }
  }

  component BreadcrumbPart: Item {
    id: crumb
    property string label: ""
    property bool navigable: false
    signal triggered()
    width: crumbText.implicitWidth
    height: parent ? parent.height : Style.space(34)
    Text {
      id: crumbText
      anchors.left: parent.left
      anchors.top: parent.top
      text: crumb.label
      color: crumb.navigable ? Color.accent : Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.bold: !crumb.navigable
    }
    HoverHandler { id: crumbHover; enabled: crumb.navigable }
    TapHandler { enabled: crumb.navigable; onTapped: crumb.triggered() }
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

  component HistoryChart: BorderSurface {
    id: chart
    property string label: ""
    property string valueText: ""
    property string peakText: ""
    property var history: []
    property real ceiling: 100
    height: Style.space(78)
    color: Style.normalFill
    radius: Style.cornerRadius
    borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)

    Text { anchors.left: parent.left; anchors.leftMargin: Style.spacing.panelGap; anchors.top: parent.top; anchors.topMargin: Style.spacing.controlGap; text: chart.label; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
    Text { anchors.right: parent.right; anchors.rightMargin: Style.spacing.panelGap; anchors.top: parent.top; anchors.topMargin: Style.spacing.controlGap; text: chart.valueText; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
    Text { anchors.right: parent.right; anchors.rightMargin: Style.spacing.panelGap; anchors.bottom: parent.bottom; anchors.bottomMargin: Style.spacing.labelGap; text: chart.peakText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }

    Canvas {
      id: canvas
      anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
      anchors.leftMargin: Style.spacing.panelGap; anchors.rightMargin: Style.spacing.panelGap
      anchors.bottomMargin: Style.spacing.controlGap; height: Style.space(42)
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = Color.muted
        ctx.globalAlpha = 0.2
        ctx.lineWidth = 1
        for (var grid = 1; grid < 4; grid++) {
          var gy = height * grid / 4
          ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
        }
        if (!chart.history || chart.history.length < 2) return
        ctx.globalAlpha = 1
        ctx.strokeStyle = Color.accent
        ctx.lineWidth = Math.max(2, Style.space(2))
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.beginPath()
        var maximum = Math.max(1, chart.ceiling)
        for (var i = 0; i < chart.history.length; i++) {
          var x = width * i / Math.max(1, chart.history.length - 1)
          var y = height - Math.min(1, Number(chart.history[i] || 0) / maximum) * (height - Style.space(3))
          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
        }
        ctx.stroke()
      }
      Connections { target: chart; function onHistoryChanged() { canvas.requestPaint() } function onCeilingChanged() { canvas.requestPaint() } }
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
    }
  }

  component ActionButton: BorderSurface {
    id: action
    property string iconText: ""
    property string label: ""
    signal triggered()
    height: Style.space(48)
    color: actionTap.pressed ? Style.pressedFill : (actionHover.hovered ? Style.hoverFill : Style.normalFill)
    radius: Style.cornerRadius
    borderSpec: Border.controlSpec(actionHover.hovered ? "hover" : "normal", Color.foreground, Color.accent, Color.urgent)
    Row { anchors.centerIn: parent; height: Style.space(28); spacing: Style.spacing.controlGap
      Text { width: Style.space(28); height: parent.height; text: action.iconText; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.display; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
      Text { height: parent.height; text: action.label; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true; verticalAlignment: Text.AlignVCenter }
    }
    HoverHandler { id: actionHover }
    TapHandler { id: actionTap; onTapped: action.triggered() }
  }

  Component { id: performanceDetail
    Column { spacing: Style.spacing.controlGap
      HistoryChart { width: parent.width; label: "CPU"; history: root.cpuHistory; valueText: root.stats.performance.cpu + "%  ·  " + (root.stats.performance.cpuTemp || "—") + "°C"; peakText: "Peak " + root.peak(root.cpuHistory).toFixed(0) + "%" }
      HistoryChart { width: parent.width; label: "GPU"; history: root.gpuHistory; valueText: (root.stats.performance.gpu || 0) + "%  ·  " + (root.stats.performance.gpuTemp || "—") + "°C"; peakText: "Peak " + root.peak(root.gpuHistory).toFixed(0) + "%" }
      HistoryChart { width: parent.width; label: "Memory"; history: root.memoryHistory; valueText: root.stats.performance.memory + "%"; peakText: root.bytes(root.stats.performance.memoryUsed) + " / " + root.bytes(root.stats.performance.memoryTotal) }
    }
  }

  Component { id: networkDetail
    Column { spacing: Style.spacing.controlGap
      HistoryChart { width: parent.width; label: "Download"; history: root.downloadHistory; ceiling: Math.max(1048576, root.peak(root.downloadHistory) * 1.15); valueText: root.rate(root.stats.network.down); peakText: "Peak " + root.rate(root.peak(root.downloadHistory)) }
      HistoryChart { width: parent.width; label: "Upload"; history: root.uploadHistory; ceiling: Math.max(1048576, root.peak(root.uploadHistory) * 1.15); valueText: root.rate(root.stats.network.up); peakText: "Peak " + root.rate(root.peak(root.uploadHistory)) }
      Row { width: parent.width; spacing: Style.spacing.controlGap
        ActionButton { width: parent.width * 0.66; iconText: "󰓅"; label: "Run speed test"; onTriggered: root.summon("omarchy.speedtest") }
        BorderSurface { width: parent.width - x; height: Style.space(48); color: Style.normalFill; radius: Style.cornerRadius; borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)
          Column { anchors.centerIn: parent; spacing: Style.spacing.labelGap
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Interface"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.stats.network.interface || "Offline"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
          }
        }
      }
    }
  }

  Component { id: applicationsDetail
    Item { Loader { anchors.fill: parent; sourceComponent: root.selectedClientAddress !== "" ? applicationInspector : applicationList } }
  }

  Component { id: applicationList
    Flickable { clip: true; contentHeight: appsColumn.height; boundsBehavior: Flickable.StopAtBounds
      Column { id: appsColumn; width: parent.width; spacing: Style.spacing.controlGap
        Repeater { model: root.stats.clients
          SystemStrip { required property var modelData; iconText: root.applicationIcon(modelData); title: modelData.class || "Application"; summary: root.processState(modelData) + "  ·  " + Number(modelData.cpu || 0).toFixed(1) + "% CPU  ·  " + root.bytes(modelData.rss); onTriggered: root.inspectClient(modelData) }
        }
      }
    }
  }

  component MetricCard: BorderSurface {
    id: metric
    property string label: ""
    property string valueText: ""
    height: Style.space(55)
    color: Style.normalFill; radius: Style.cornerRadius
    borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)
    Column { anchors.centerIn: parent; spacing: Style.spacing.labelGap
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: metric.label; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: metric.valueText; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
    }
  }

  Component { id: applicationInspector
    Item {
      id: inspector
      property var client: root.currentClient()
      Column { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; spacing: Style.spacing.controlGap
        BorderSurface { width: parent.width; height: Style.space(72); color: Style.normalFill; radius: Style.cornerRadius; borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)
          Text { id: appIcon; anchors.left: parent.left; anchors.leftMargin: Style.spacing.panelGap; anchors.verticalCenter: parent.verticalCenter; text: root.applicationIcon(inspector.client); color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.displayLarge }
          Column { anchors.left: appIcon.right; anchors.leftMargin: Style.spacing.panelGap; anchors.right: parent.right; anchors.rightMargin: Style.spacing.panelGap; anchors.verticalCenter: parent.verticalCenter; spacing: Style.spacing.labelGap
            Text { width: parent.width; text: inspector.client ? (inspector.client.class || "Application") : "Application closed"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true; elide: Text.ElideRight }
            Text { width: parent.width; text: inspector.client ? (inspector.client.title || "Untitled") : "The process is no longer running"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
          }
        }
        Row { width: parent.width; spacing: Style.spacing.controlGap
          MetricCard { width: (parent.width - parent.spacing * 2) / 3; label: "CPU"; valueText: inspector.client ? Number(inspector.client.cpu || 0).toFixed(1) + "%" : "—" }
          MetricCard { width: (parent.width - parent.spacing * 2) / 3; label: "Memory"; valueText: inspector.client ? root.bytes(inspector.client.rss) : "—" }
          MetricCard { width: (parent.width - parent.spacing * 2) / 3; label: "State"; valueText: root.processState(inspector.client) }
        }
        Row { width: parent.width; spacing: Style.spacing.controlGap
          MetricCard { width: (parent.width - parent.spacing) / 2; label: "Workspace"; valueText: root.workspaceLabel(inspector.client) }
          MetricCard { width: (parent.width - parent.spacing) / 2; label: "Uptime"; valueText: inspector.client ? root.elapsed(inspector.client.elapsed) : "—" }
        }
      }
      Row { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; spacing: Style.spacing.controlGap
        ActionButton { width: (parent.width - parent.spacing * 2) / 3; iconText: "󰁔"; label: "Focus"; onTriggered: root.focusClient(inspector.client) }
        ActionButton { width: (parent.width - parent.spacing * 2) / 3; iconText: "󰅖"; label: "Close"; onTriggered: root.closeClient(inspector.client) }
        ActionButton { width: (parent.width - parent.spacing * 2) / 3; iconText: "󰆴"; label: root.forceKillArmed ? "Tap again" : "Force kill"; onTriggered: root.forceKillClient(inspector.client) }
      }
    }
  }

  Component { id: clipboardDetail
    Item {
      Loader { anchors.fill: parent; sourceComponent: root.selectedClipboard ? clipboardInspector : clipboardList }
    }
  }

  Component { id: clipboardList
    Flickable { clip: true; contentHeight: clipboardColumn.height; boundsBehavior: Flickable.StopAtBounds
      Column { id: clipboardColumn; width: parent.width; spacing: Style.spacing.controlGap
        Repeater { model: root.stats.clipboard
          BorderSurface {
            id: clipboardRow
            required property var modelData
            property bool copiedByHold: false
            width: parent.width; height: Style.space(54)
            color: clipboardTap.pressed ? Style.pressedFill : (clipboardHover.hovered ? Style.hoverFill : Style.normalFill)
            radius: Style.cornerRadius
            borderSpec: Border.controlSpec(clipboardHover.hovered ? "hover" : "normal", Color.foreground, Color.accent, Color.urgent)
            Text { id: clipboardIcon; anchors.left: parent.left; anchors.leftMargin: Style.spacing.panelGap; anchors.verticalCenter: parent.verticalCenter; text: clipboardRow.modelData.type === "image" ? "󰋩" : "󰅇"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.display }
            Column { anchors.left: clipboardIcon.right; anchors.leftMargin: Style.spacing.panelGap; anchors.right: clipboardArrow.left; anchors.rightMargin: Style.spacing.controlGap; anchors.verticalCenter: parent.verticalCenter; spacing: Style.spacing.labelGap
              Text { width: parent.width; text: root.clipboardPreview(clipboardRow.modelData); color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; elide: Text.ElideRight }
              Text { width: parent.width; text: "Tap to inspect  ·  hold to copy"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
            Text { id: clipboardArrow; anchors.right: parent.right; anchors.rightMargin: Style.spacing.panelGap; anchors.verticalCenter: parent.verticalCenter; text: "󰅂"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.body }
            HoverHandler { id: clipboardHover }
            TapHandler { id: clipboardTap
              onLongPressed: { clipboardRow.copiedByHold = true; root.copyClipboard(clipboardRow.modelData) }
              onTapped: {
                if (clipboardRow.copiedByHold) clipboardRow.copiedByHold = false
                else root.showClipboard(clipboardRow.modelData)
              }
            }
          }
        }
      }
    }
  }

  Component { id: clipboardInspector
    Item {
      BorderSurface {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: actions.top
        anchors.bottomMargin: Style.spacing.panelGap
        color: Style.normalFill; radius: Style.cornerRadius
        borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)
        clip: true
        Image {
          visible: root.selectedClipboard && root.selectedClipboard.type === "image"
          anchors.fill: parent; anchors.margins: Style.spacing.panelGap
          source: visible ? "file://" + root.selectedClipboard.path : ""
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }
        Flickable {
          visible: root.selectedClipboard && root.selectedClipboard.type !== "image"
          anchors.fill: parent; anchors.margins: Style.spacing.panelGap
          contentHeight: fullText.paintedHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
          Text { id: fullText; width: parent.width; text: root.selectedClipboard ? (root.selectedClipboard.text || "") : ""; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText }
        }
      }
      Row { id: actions; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; spacing: Style.spacing.controlGap
        ActionButton { width: (parent.width - parent.spacing) / 2; iconText: "󰆏"; label: root.clipboardNotice === "Copied" ? "Copied" : "Copy"; onTriggered: root.copyClipboard(root.selectedClipboard) }
        ActionButton { width: (parent.width - parent.spacing) / 2; iconText: "󰆴"; label: root.clipboardNotice === "Deleted" ? "Deleted" : "Delete"; onTriggered: root.deleteClipboard(root.selectedClipboard) }
      }
    }
  }

  Component { id: storageDetail
    Column { spacing: Style.spacing.panelGap
      Meter { width: parent.width; label: "System disk"; value: root.stats.storage.percent; valueText: root.stats.storage.percent + "%" }
      SystemStrip { iconText: "󰋊"; title: "Used"; summary: root.bytes(root.stats.storage.used); navigable: false }
      SystemStrip { iconText: "󰉋"; title: "Available"; summary: root.bytes(root.stats.storage.free); navigable: false }
      ActionButton { width: parent.width; iconText: "󰓅"; label: "Run disk speed test"; onTriggered: root.summon("omarchy.disk-speedtest") }
    }
  }
}
