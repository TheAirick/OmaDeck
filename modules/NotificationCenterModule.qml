import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.Commons
import qs.Ui
import "../theme"
import "../components"
import "../services"
import "NotificationHistory.js" as NotificationHistory

Item {
  id: root
  objectName: "notificationCenterPresenter"
  property var shell: null
  property var deck: null
  property bool active: false
  property var controller: notificationController
  property string selectedKey: ""
  property bool reading: false
  property bool showControls: false
  property bool clearArmed: false
  property double now: Date.now()
  readonly property bool wide: width >= Style.space(1120)
  readonly property bool narrow: width < Style.space(760)
  readonly property real railWidth: narrow ? width : Style.space(256)
  readonly property real mainWidth: narrow ? width : width - railWidth - Style.spacing.panelGap * 2
  readonly property real listWidth: wide && entries.length > 0 ? Math.min(Style.space(420), mainWidth * 0.4) : mainWidth
  readonly property var entries: controller ? controller.entries : []
  readonly property var selectedEntry: {
    for (var i = 0; i < entries.length; i++) if (NotificationHistory.entryKey(entries[i]) === selectedKey) return entries[i]
    return null
  }
  readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
  readonly property bool wifiAvailable: hasWifiDevice()

  NotificationController {
    id: notificationController
    shell: root.shell
    pluginDir: root.deck ? String(root.deck.pluginDir || "") : ""
    active: root.active && root.controller === notificationController
  }
  Connections { target: root.controller; function onAppOpened() { if (root.deck) root.deck.closeOverlay() } }
  function hasWifiDevice() {
    if (Networking.backend !== NetworkBackendType.NetworkManager) return false
    var devices = Networking.devices ? Networking.devices.values : []
    for (var i = 0; i < devices.length; i++) if (devices[i].type === DeviceType.Wifi) return true
    return false
  }
  function iconFor(entry) {
    if (!entry) return ""
    var icon = entry.appIcon || String(entry.app || "").toLowerCase().replace(/\s+/g, "-")
    // Only theme icon names; notification content cannot initiate remote loads.
    return /^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(icon) ? Quickshell.iconPath(icon, true) : ""
  }
  function selectEntry(entry) { selectedKey = NotificationHistory.entryKey(entry); reading = true; clearArmed = false }
  function toggleWifi() { if (active && wifiAvailable) Networking.wifiEnabled = !Networking.wifiEnabled }
  function toggleBluetooth() {
    if (!active || !bluetoothAdapter) return
    Quickshell.execDetached(["/usr/bin/env", "PATH=/usr/bin:/usr/share/omarchy/bin",
      "/usr/bin/timeout", "--signal=TERM", "--kill-after=1s", "12s",
      "/usr/bin/omarchy-bluetooth-power", bluetoothAdapter.enabled ? "off" : "on"])
  }
  onActiveChanged: if (active) { now = Date.now(); clearArmed = false; showControls = false; reading = false }
  onEntriesChanged: {
    if (selectedEntry) return
    selectedKey = entries.length ? NotificationHistory.entryKey(entries[0]) : ""
    reading = false
    clearArmed = false
  }
  onSelectedKeyChanged: if (messageScroll) messageScroll.contentY = 0
  Timer { interval: 30000; repeat: true; running: root.active; onTriggered: root.now = Date.now() }

  Item {
    id: feedPane
    objectName: "notificationFeedPane"
    width: root.listWidth
    height: parent.height
    visible: !(root.narrow && root.showControls) && (root.wide || !root.reading || !root.selectedEntry)
    Row {
      id: feedHeader
      width: parent.width
      height: Style.space(48)
      spacing: Style.spacing.controlGap
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, parent.width - clearButton.width - refreshButton.width
          - (controlsButton.visible ? controlsButton.width + parent.spacing : 0) - parent.spacing * 2)
        text: root.entries.length ? "Recent · " + root.entries.length : "Recent"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
        elide: Text.ElideRight
      }
      Button {
        id: controlsButton
        objectName: "notificationShowControls"
        visible: root.narrow
        text: "Controls"
        height: parent.height
        bordered: false
        onClicked: root.showControls = true
      }
      Button {
        id: refreshButton
        objectName: "notificationRefreshControl"
        width: Style.space(48); height: width
        iconText: "󰑓"
        Accessible.name: "Refresh notifications and controls"
        enabled: root.controller && !root.controller.loading && !root.controller.busy
        bordered: false
        onClicked: root.controller.refresh()
      }
      Button {
        id: clearButton
        objectName: "notificationClearControl"
        text: "Clear all"
        height: parent.height
        bordered: false
        enabled: root.entries.length > 0 && root.controller && root.controller.dndAvailable && !root.controller.busy
        onClicked: root.clearArmed = !root.clearArmed
      }
    }
    Column {
      id: clearConfirmation
      width: parent.width
      y: feedHeader.height
      visible: root.clearArmed
      height: visible ? implicitHeight : 0
      Text {
        text: "Clear all notifications and history?"
        width: parent.width
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
      }
      Row {
        spacing: Style.spacing.controlGap
        Button {
          objectName: "notificationCancelClear"
          height: Style.space(48); text: "Cancel"; bordered: false
          onClicked: root.clearArmed = false
        }
        Button {
          objectName: "notificationConfirmClear"
          height: Style.space(48); text: "Clear all"; bordered: false
          foreground: Color.urgent
          onClicked: { root.clearArmed = false; root.controller.clearAll() }
        }
      }
    }
    Text {
      id: feedNotice
      x: Style.spacing.controlPaddingX
      y: clearConfirmation.y + clearConfirmation.height
      width: Math.max(0, parent.width - x * 2)
      visible: text !== ""
      height: visible ? implicitHeight + Style.spacing.controlGap : 0
      text: root.controller ? root.controller.historyError : ""
      textFormat: Text.PlainText
      color: DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
    }
    ListView {
      id: notificationList
      objectName: "notificationCenterList"
      y: feedNotice.y + feedNotice.height + Style.spacing.controlGap
      width: parent.width
      height: Math.max(0, parent.height - y)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: root.entries
      Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
      delegate: NotificationRow {
        required property var modelData
        width: notificationList.width
        height: implicitHeight
        entry: modelData
        entryKey: NotificationHistory.entryKey(modelData)
        iconSource: root.iconFor(modelData)
        timeText: NotificationHistory.relativeTime(modelData.timestamp, root.now)
        selected: root.wide && root.selectedKey === entryKey
        onActivated: root.selectEntry(modelData)
      }
      Column {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Style.spacing.panelPadding * 2)
        visible: root.entries.length === 0
        spacing: Style.spacing.controlGap
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰂚"
          color: DeckColors.secondaryText
          font.family: Style.font.family
          font.pixelSize: Style.font.displayLarge
        }
        Text {
          width: parent.width
          text: root.controller && root.controller.loading ? "Loading notifications…"
            : root.controller && root.controller.historyError ? "Notifications unavailable" : "You’re all caught up"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
        }
        Text {
          width: parent.width
          text: "New notifications will appear here."
          color: DeckColors.secondaryText
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          visible: !root.controller || (!root.controller.loading && !root.controller.historyError)
        }
      }
    }
  }

  Rectangle {
    visible: root.wide && root.entries.length > 0
    x: root.listWidth + Style.spacing.panelGap
    width: 1; height: parent.height
    color: Color.foreground; opacity: 0.1
  }
  Item {
    id: messagePane
    objectName: "notificationMessagePane"
    x: root.wide ? root.listWidth + Style.spacing.panelGap * 2 : 0
    width: root.wide ? root.mainWidth - x : root.mainWidth
    height: parent.height
    visible: !!root.selectedEntry && !(root.narrow && root.showControls) && (root.wide || root.reading)
    Item {
      id: messageActions
      width: parent.width
      height: Style.space(48)
      Button {
        objectName: "notificationBackToList"
        visible: !root.wide
        text: "Back"
        height: parent.height
        bordered: false
        onClicked: root.reading = false
      }
      Button {
        id: openAppButton
        anchors.right: parent.right
        objectName: "notificationOpenApp"
        text: "Open app"
        height: parent.height
        bordered: false
        enabled: root.controller && !root.controller.busy && !!root.selectedEntry
        onClicked: root.controller.openApp(root.selectedEntry)
      }
    }
    Flickable {
      id: messageScroll
      objectName: "notificationMessageScroll"
      y: messageActions.height + Style.spacing.controlGap
      width: parent.width
      height: Math.max(0, parent.height - y - (actionNotice.visible ? actionNotice.height + Style.spacing.controlGap : 0))
      contentWidth: width
      contentHeight: messageContent.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
      Column {
        id: messageContent
        width: Math.max(0, Math.min(parent.width - Style.spacing.panelPadding * 2, Style.space(720)))
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.spacing.panelGap
        Row {
          width: parent.width
          spacing: Style.spacing.controlGap
          Image {
            id: readerIcon
            width: Style.space(32); height: width
            source: root.iconFor(root.selectedEntry)
            fillMode: Image.PreserveAspectFit
            Text {
              anchors.centerIn: parent
              visible: readerIcon.status !== Image.Ready
              text: root.selectedEntry && root.selectedEntry.glyph ? root.selectedEntry.glyph : "󰂚"
              color: root.selectedEntry && root.selectedEntry.urgency === 2 ? Color.urgent : Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.iconLarge
            }
          }
          Column {
            width: parent.width - x
            spacing: Style.spacing.labelGap
            Text {
              width: parent.width
              text: root.selectedEntry ? root.selectedEntry.app : ""
              textFormat: Text.PlainText
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              wrapMode: Text.Wrap
            }
            Text {
              width: parent.width
              text: root.selectedEntry && root.selectedEntry.timestamp > 0
                ? Qt.formatDateTime(new Date(root.selectedEntry.timestamp), "ddd, MMM d · h:mm AP") : "Recent"
              color: DeckColors.secondaryText
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }
          }
        }
        Text {
          objectName: "notificationMessageTitle"
          width: parent.width
          text: root.selectedEntry ? root.selectedEntry.summary : ""
          textFormat: Text.PlainText
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
          wrapMode: Text.Wrap
        }
        Text {
          objectName: "notificationMessageBody"
          width: parent.width
          text: root.selectedEntry ? root.selectedEntry.body : ""
          textFormat: Text.PlainText
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          lineHeight: 1.3
          wrapMode: Text.Wrap
        }
      }
    }
    Text {
      id: actionNotice
      anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
      text: root.controller ? root.controller.notice : ""
      visible: text !== ""
      textFormat: Text.PlainText
      color: DeckColors.secondaryText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
    }
  }

  Rectangle {
    visible: !root.narrow
    x: root.mainWidth + Style.spacing.panelGap
    width: 1; height: parent.height
    color: Color.foreground; opacity: 0.1
  }
  Flickable {
    id: controlsPane
    objectName: "notificationControlsPane"
    visible: !root.narrow || root.showControls
    x: root.narrow ? 0 : parent.width - root.railWidth
    width: root.railWidth
    height: parent.height
    contentWidth: width
    contentHeight: quickControls.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
    Column {
      id: quickControls
      width: parent.width
      spacing: Style.spacing.labelGap
      Item {
        width: parent.width
        height: Style.space(48)
        Text {
          anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
          text: "Quick controls"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
        Button {
          objectName: "notificationBackFromControls"
          anchors.right: parent.right
          visible: root.narrow
          height: parent.height
          text: "Back"; bordered: false
          onClicked: root.showControls = false
        }
      }
      QuickToggle {
        objectName: "notificationDndControl"
        width: parent.width; height: implicitHeight
        label: "Do not disturb"
        status: checked ? "Notifications silenced" : "Alerts on"
        iconText: checked ? "󰂛" : "󰂚"
        checked: root.controller && root.controller.dnd
        available: root.controller && root.controller.dndAvailable
        enabled: root.active && root.controller && !root.controller.busy
        onToggled: root.controller.toggleDnd()
      }
      QuickToggle {
        objectName: "notificationWifiControl"
        width: parent.width; height: implicitHeight
        label: "Wi-Fi"; status: checked ? "On" : "Off"
        iconText: checked ? "󰖩" : "󰖪"
        checked: root.wifiAvailable && Networking.wifiEnabled
        available: root.wifiAvailable
        onToggled: root.toggleWifi()
      }
      QuickToggle {
        objectName: "notificationBluetoothControl"
        width: parent.width; height: implicitHeight
        label: "Bluetooth"; status: checked ? "On" : "Off"
        iconText: checked ? "󰂯" : "󰂲"
        checked: !!root.bluetoothAdapter && root.bluetoothAdapter.enabled
        available: !!root.bluetoothAdapter
        onToggled: root.toggleBluetooth()
      }
      QuickToggle {
        objectName: "notificationNightlightControl"
        width: parent.width; height: implicitHeight
        label: "Night Light"; status: checked ? "Warm" : "Daylight"
        iconText: checked ? "󰖔" : "󰖨"
        checked: root.controller && root.controller.night
        available: root.controller && root.controller.nightAvailable
        enabled: root.active && root.controller && !root.controller.busy
        onToggled: root.controller.toggleNightlight()
      }
      Row {
        width: parent.width
        spacing: Style.spacing.controlGap
        Button {
          width: (parent.width - parent.spacing) / 2
          height: Style.space(48)
          text: "Network"; bordered: false
          onClicked: if (root.deck) { root.deck.showSystemSection("network"); root.deck.closeOverlay() }
        }
        Button {
          width: (parent.width - parent.spacing) / 2
          height: Style.space(48)
          text: "Audio"; bordered: false
          onClicked: if (root.deck) { root.deck.setOpenDrawer("left", "notification:audio"); root.deck.closeOverlay() }
        }
      }
      Text {
        width: parent.width
        text: root.controller ? root.controller.notice : ""
        visible: text !== "" && !messagePane.visible
        height: visible ? implicitHeight : 0
        textFormat: Text.PlainText
        color: DeckColors.secondaryText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }
    }
  }
}
