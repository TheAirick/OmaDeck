import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Ui
import "../components"
import "NotificationHistory.js" as NotificationHistory

Item {
  id: root

  property var shell: null
  property var deck: null
  property bool active: false
  property var historyEntries: []
  property int historyRevision: 0
  readonly property string pluginDir: deck ? String(deck.pluginDir || "") : ""
  readonly property string historyDir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/history"
  readonly property var notificationService: shell && typeof shell.firstPartyServiceFor === "function"
    ? shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var nightlightService: shell && typeof shell.firstPartyServiceFor === "function"
    ? shell.firstPartyServiceFor("omarchy.nightlight") : null
  readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
  readonly property bool wifiAvailable: root.hasWifiDevice()
  readonly property int liveCount: notificationService && notificationService.popupModel
    ? notificationService.popupModel.count : 0
  readonly property var entries: {
    var liveRevision = root.liveCount
    var diskRevision = root.historyRevision
    return NotificationHistory.merge(root.liveRows(), root.historyEntries, 12)
  }

  function hasWifiDevice() {
    if (Networking.backend !== NetworkBackendType.NetworkManager) return false
    var devices = Networking.devices ? Networking.devices.values : []
    for (var index = 0; index < devices.length; index++)
      if (devices[index].type === DeviceType.Wifi) return true
    return false
  }

  function liveRows() {
    var rows = []
    var model = notificationService ? notificationService.popupModel : null
    if (!model) return rows
    for (var index = 0; index < model.count; index++) {
      var value = model.get(index)
      rows.push({
        app: value.app,
        summary: value.summary,
        body: value.body,
        glyph: value.glyph,
        urgency: value.urgency,
        timestamp: value.timestamp,
        originalId: value.originalId,
        sourceIndex: index
      })
    }
    return rows
  }

  function reloadHistory() {
    if (historyReader.running || pluginDir === "") return
    historyReader.running = true
  }

  function stopHistoryReader() {
    historyLifecycleBackstop.stop()
    if (!historyReader.running) return
    historyReader.running = false
    historyForceStopDelay.restart()
  }

  function applyHistory(raw) {
    historyEntries = NotificationHistory.parseHistory(raw, 12)
    historyRevision++
  }

  function clearAll() {
    if (notificationService) {
      notificationService.clearPopups()
      notificationService.clearHistory()
    }
    historyEntries = []
    historyRevision++
  }

  function activate(entry) {
    if (!notificationService || !entry) return
    if (entry.live) notificationService.invokePopupDefault(entry.sourceIndex)
    else notificationService.focusApp(entry)
    Qt.callLater(root.reloadHistory)
  }

  function timeLabel(timestamp) {
    var value = Number(timestamp || 0)
    if (value <= 0) return "Recent"
    return Qt.formatDateTime(new Date(value), "ddd h:mm AP")
  }

  function toggleDnd() {
    if (notificationService)
      notificationService.setDoNotDisturb(!notificationService.doNotDisturb)
  }

  function toggleWifi() {
    if (wifiAvailable) Networking.wifiEnabled = !Networking.wifiEnabled
  }

  function toggleBluetooth() {
    if (!bluetoothAdapter) return
    Quickshell.execDetached([
      "/usr/bin/env", "PATH=/usr/bin:/usr/share/omarchy/bin",
      "/usr/bin/timeout", "--signal=TERM", "--kill-after=1s", "12s",
      "/usr/bin/omarchy-bluetooth-power",
      bluetoothAdapter.enabled ? "off" : "on"
    ])
  }

  function toggleNightlight() {
    if (nightlightService)
      nightlightService.setNightlight(!nightlightService.enabled)
  }

  onActiveChanged: if (active) reloadHistory()

  Process {
    id: historyReader
    running: false
    command: ["/usr/bin/timeout", "--signal=TERM", "--kill-after=1s", "2s",
              root.pluginDir + "/scripts/notification-history", root.historyDir]
    stdout: BoundedOutputParser {
      id: historyOutput
      maxBytes: 128 * 1024
    }
    onStarted: {
      historyOutput.reset()
      historyLifecycleBackstop.restart()
    }
    onExited: function(exitCode) {
      historyLifecycleBackstop.stop()
      historyForceStopDelay.stop()
      if (exitCode === 0 && !historyOutput.truncated)
        root.applyHistory(historyOutput.text)
    }
  }

  Timer {
    id: historyLifecycleBackstop
    interval: 3 * 1000
    repeat: false
    onTriggered: root.stopHistoryReader()
  }

  Timer {
    id: historyForceStopDelay
    interval: 500
    repeat: false
    onTriggered: if (historyReader.running) historyReader.signal(9)
  }

  Component.onDestruction: root.stopHistoryReader()

  Row {
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(parent.width, Style.space(1320))
    spacing: Style.spacing.panelGap

    BorderSurface {
      id: quickPane
      width: Math.min(Style.space(390), Math.max(Style.space(320), parent.width * 0.32))
      height: parent.height
      color: Style.normalFill
      radius: Style.cornerRadius
      borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)

      Column {
        anchors.fill: parent
        anchors.margins: Style.spacing.panelPadding
        spacing: Style.spacing.panelGap

        Text {
          text: "Quick controls"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Grid {
          id: quickGrid
          width: parent.width
          columns: 2
          columnSpacing: Style.spacing.controlGap
          rowSpacing: Style.spacing.controlGap

          QuickToggle {
            objectName: "notificationDndControl"
            width: (quickGrid.width - quickGrid.columnSpacing) / 2
            height: Style.space(98)
            label: "Focus"
            status: checked ? "Silenced" : "Alerts on"
            iconText: checked ? "󰂛" : "󰂚"
            checked: !!root.notificationService && root.notificationService.doNotDisturb
            available: !!root.notificationService
            onToggled: root.toggleDnd()
          }

          QuickToggle {
            objectName: "notificationWifiControl"
            width: (quickGrid.width - quickGrid.columnSpacing) / 2
            height: Style.space(98)
            label: "Wi-Fi"
            status: checked ? "On" : "Off"
            iconText: checked ? "󰖩" : "󰖪"
            checked: root.wifiAvailable && Networking.wifiEnabled
            available: root.wifiAvailable
            onToggled: root.toggleWifi()
          }

          QuickToggle {
            objectName: "notificationBluetoothControl"
            width: (quickGrid.width - quickGrid.columnSpacing) / 2
            height: Style.space(98)
            label: "Bluetooth"
            status: checked ? "On" : "Off"
            iconText: checked ? "󰂯" : "󰂲"
            checked: !!root.bluetoothAdapter && root.bluetoothAdapter.enabled
            available: !!root.bluetoothAdapter
            onToggled: root.toggleBluetooth()
          }

          QuickToggle {
            objectName: "notificationNightlightControl"
            width: (quickGrid.width - quickGrid.columnSpacing) / 2
            height: Style.space(98)
            label: "Night Light"
            status: checked ? "Warm" : "Daylight"
            iconText: checked ? "󰖔" : "󰖨"
            checked: !!root.nightlightService && root.nightlightService.enabled
            available: !!root.nightlightService
            onToggled: root.toggleNightlight()
          }
        }

        Item { width: 1; height: Style.spacing.rowGap }

        Text {
          text: "Open"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1
        }

        Row {
          width: parent.width
          spacing: Style.spacing.controlGap

          Button {
            width: (parent.width - parent.spacing) / 2
            height: Style.space(52)
            text: "Network"
            iconText: "󰤨"
            bordered: true
            onClicked: if (root.deck) {
              root.deck.showSystemSection("network")
              root.deck.closeOverlay()
            }
          }

          Button {
            width: (parent.width - parent.spacing) / 2
            height: Style.space(52)
            text: "Audio"
            iconText: "󰕾"
            bordered: true
            onClicked: if (root.deck) {
              root.deck.setOpenDrawer("left", "notification:audio")
              root.deck.closeOverlay()
            }
          }
        }
      }
    }

    BorderSurface {
      id: feedPane
      width: parent.width - x
      height: parent.height
      color: Style.normalFill
      radius: Style.cornerRadius
      borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)

      Row {
        id: feedHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Style.spacing.panelPadding
        height: Style.space(48)
        spacing: Style.spacing.controlGap

        Text {
          width: parent.width - x - clearButton.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          text: root.entries.length > 0 ? "Recent · " + root.entries.length : "Recent"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Button {
          id: clearButton
          objectName: "notificationClearControl"
          width: Style.space(116)
          height: parent.height
          text: "Clear all"
          iconText: "󰃢"
          bordered: true
          enabled: root.entries.length > 0
          tooltipText: "Clear notification history"
          onClicked: root.clearAll()
        }
      }

      ListView {
        id: notificationList
        objectName: "notificationCenterList"
        anchors.top: feedHeader.bottom
        anchors.topMargin: Style.spacing.controlGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Style.spacing.panelPadding
        anchors.rightMargin: Style.spacing.panelPadding
        anchors.bottomMargin: Style.spacing.panelPadding
        spacing: Style.spacing.controlGap
        clip: true
        model: root.entries

        delegate: Item {
          id: notificationDelegate
          required property var modelData
          width: notificationList.width
          height: Style.space(86)

          BorderSurface {
            id: notificationCard
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(notificationList.width, Style.space(720))
            color: notificationTap.pressed ? Style.pressedFill
              : notificationHover.hovered ? Style.hoverFill : Style.normalFill
            radius: Style.cornerRadius
            borderSpec: Border.controlSpec(notificationHover.hovered ? "hover" : "normal",
              Color.foreground, Color.accent, Color.urgent)

            Text {
              id: notificationGlyph
              anchors.left: parent.left
              anchors.leftMargin: Style.spacing.panelGap
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(40)
              text: notificationDelegate.modelData.glyph || "󰂚"
              color: notificationDelegate.modelData.urgency === 2 ? Color.urgent : Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
            }

            Column {
              anchors.left: notificationGlyph.right
              anchors.leftMargin: Style.spacing.panelGap
              anchors.right: notificationTime.left
              anchors.rightMargin: Style.spacing.panelGap
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.labelGap

              Text {
                width: parent.width
                text: notificationDelegate.modelData.summary
                textFormat: Text.PlainText
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: notificationDelegate.modelData.body || notificationDelegate.modelData.app
                textFormat: Text.PlainText
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Text {
              id: notificationTime
              anchors.right: parent.right
              anchors.rightMargin: Style.spacing.panelGap
              anchors.verticalCenter: parent.verticalCenter
              text: root.timeLabel(notificationDelegate.modelData.timestamp)
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            HoverHandler { id: notificationHover }
            TapHandler { id: notificationTap; onTapped: root.activate(notificationDelegate.modelData) }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.entries.length === 0
          text: "󰂚   No recent notifications"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }
      }
    }
  }
}
