import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../modules"
import "DrawerGesture.js" as DrawerGesture
import "../native/OmaDeck/Touch" as NativeTouch

PanelWindow {
  id: root

  property var serviceHost: null
  property var shell: null
  property string pluginDir: ""
  property var layoutController: null
  property var appearanceController: null
  property var launcherController: null
  property var weatherController: null
  property var timerController: null
  property string targetScreen: "DP-3"
  property string primaryMonitor: "DP-1"
  property var touchDeviceNames: []
  property string openDrawer: ""
  property string openOverlayName: ""
  property string commandCenterPage: "home"
  property string lastDrawerTransition: "initial"
  property int drawerTransitionSequence: 0

  readonly property string drawerBuild: "static-media-layered-overlays-v2"
  readonly property string componentUrl: String(Qt.resolvedUrl("DeckSurface.qml"))
  readonly property string sourceDir: pluginDir

  readonly property bool isTarget: screen && screen.name === targetScreen
  readonly property bool deckHovered: backgroundHover.hovered || centerCanvas.pointerHovered
    || nowPlayingHover.hovered
    || leftDrawer.pointerHovered || rightDrawer.pointerHovered
    || notificationOverlay.pointerHovered || overviewOverlay.pointerHovered
  readonly property bool pointerRevealed: deckHovered
    && !directTouch.touchInProgress
  readonly property int outerGap: Math.max(1, Style.gapsOut)
  readonly property int innerGap: Style.spacing.panelGap
  readonly property int usableWidth: Math.max(0, width - outerGap * 2)
  readonly property int usableHeight: Math.max(0, height - outerGap * 2)
  readonly property int staticMediaWidth: Math.round(usableWidth * 0.27)
  readonly property int staticMediaReserve: staticMediaWidth + innerGap
  readonly property int leftDrawerWidth: Math.min(Math.round(usableWidth * 0.46),
    Math.ceil(volumeDrawer.preferredDrawerWidth))
  readonly property int rightDrawerWidth: Math.round(usableWidth * 0.34)

  // Horizontal drawers remain part of the tiling geometry. Vertical gestures
  // own full-surface overlays and therefore never steal height from the center.
  property real reservedLeft: openDrawer === "left" ? leftDrawerWidth + innerGap : 0
  property real reservedRight: openDrawer === "right" ? rightDrawerWidth + innerGap : 0
  readonly property real reservedTop: 0
  readonly property real reservedBottom: 0

  Behavior on reservedLeft { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Behavior on reservedRight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

  visible: isTarget
  anchors { top: true; right: true; bottom: true; left: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omadeck"
  WlrLayershell.layer: WlrLayer.Bottom
  // OmaDeck never requests compositor keyboard focus. Its direct-touch bridge
  // owns the Xeneon evdev node and injects events only into this backing window.
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  NativeTouch.TouchBridge {
    id: directTouch
    deviceNames: root.touchDeviceNames
  }

  Component.onCompleted: {
    directTouch.window = centerCanvas
    directTouch.start()
    if (serviceHost) serviceHost.registerSurface(root)
    console.info("[OmaDeckDrawer] loaded", JSON.stringify(drawerDiagnostics()))
  }

  Component.onDestruction: {
    if (serviceHost) serviceHost.unregisterSurface(root)
  }

  function drawerDiagnostics() {
    return {
      openDrawer: openDrawer,
      openOverlay: openOverlayName,
      commandCenterPage: commandCenterPage,
      lastTransition: lastDrawerTransition,
      sequence: drawerTransitionSequence,
      componentUrl: componentUrl,
      sourceDir: sourceDir,
      build: drawerBuild,
      deckHovered: deckHovered,
      backgroundHovered: backgroundHover.hovered,
      centerHovered: centerCanvas.pointerHovered,
      touchInProgress: directTouch.touchInProgress,
      pointerRevealed: pointerRevealed
    }
  }

  function setOpenDrawer(nextDrawer, reason) {
    if (["", "left", "right"].indexOf(nextDrawer) === -1) return

    lastDrawerTransition = String(reason || "unspecified")
    drawerTransitionSequence++
    openDrawer = nextDrawer
  }

  function toggleDrawer(edge) {
    if (edge === "top") {
      toggleOverlay("notifications")
      return
    }
    if (edge === "bottom") {
      toggleOverlay("overview")
      return
    }
    setOpenDrawer(DrawerGesture.toggleDrawer(openDrawer, edge), "toggle:" + edge)
  }

  function dismissDrawer(edge) {
    setOpenDrawer(DrawerGesture.dismissDrawer(openDrawer, edge), "dismiss:" + edge)
  }

  function closeDrawer() {
    setOpenDrawer("", "ipc:close")
    setOpenOverlay("", "ipc:close")
  }

  function setOpenOverlay(nextOverlay, reason) {
    if (["", "notifications", "overview"].indexOf(nextOverlay) === -1) return
    lastDrawerTransition = String(reason || "unspecified")
    drawerTransitionSequence++
    openOverlayName = nextOverlay
  }

  function openOverlay(name) {
    setOpenOverlay(name, "open-overlay:" + name)
  }

  function toggleOverlay(name) {
    setOpenOverlay(openOverlayName === name ? "" : name, "toggle-overlay:" + name)
  }

  function closeOverlay() {
    setOpenOverlay("", "close-overlay")
  }

  function setCommandCenterPage(page) {
    if (["home", "applications"].indexOf(page) === -1) return
    commandCenterPage = page
  }

  function drawerState(): string {
    return JSON.stringify(drawerDiagnostics())
  }

  function touchState(): string {
    return JSON.stringify({
      active: directTouch.active,
      exclusiveGrab: directTouch.active,
      devicePath: directTouch.devicePath,
      configuredDeviceNames: directTouch.deviceNames,
      status: directTouch.status
    })
  }

  function reconnectTouch() {
    directTouch.stop()
    directTouch.start()
  }

  function showSystemSection(section) {
    if (["performance", "network", "applications", "clipboard", "storage"].indexOf(section) === -1) return
    setOpenDrawer("right", "ipc:system:" + section)
    systemDrawer.selectedClipboard = null
    systemDrawer.selectedClientAddress = ""
    systemDrawer.selectedSection = section
  }

  function showClipboardEntry(index) {
    if (index < 0 || index >= systemDrawer.stats.clipboard.length) return
    setOpenDrawer("right", "ipc:clipboard")
    systemDrawer.selectedSection = "clipboard"
    systemDrawer.selectedClipboard = systemDrawer.stats.clipboard[index]
  }

  function showApplication(index) {
    if (index < 0 || index >= systemDrawer.stats.clients.length) return
    setOpenDrawer("right", "ipc:application")
    systemDrawer.selectedSection = "applications"
    systemDrawer.selectedClientAddress = systemDrawer.stats.clients[index].address
  }

  function systemBack() {
    systemDrawer.goBack()
  }

  function clipboardCopy() {
    systemDrawer.copyClipboard(systemDrawer.selectedClipboard)
  }

  function clipboardDelete() {
    systemDrawer.deleteClipboard(systemDrawer.selectedClipboard)
  }

  function setMediaCompact(compact) {
    setOpenDrawer("left", "ipc:mediaCompact")
    volumeDrawer.setMixerCompact(compact)
  }

  function setMediaCategory(category) {
    setOpenDrawer("left", "ipc:mediaCategory")
    volumeDrawer.setMixerCategory(category)
  }

  Rectangle {
    id: deckBackground
    anchors.fill: parent
    color: Color.background

    HoverHandler {
      id: backgroundHover
    }
  }

  // Volume and System reserve horizontal geometry. Vertical overlays retain
  // that exact underlying state and reveal it again when dismissed.
  EdgeDrawer {
    id: leftDrawer
    objectName: "leftVolumeDrawer"
    edge: "left"
    framed: false
    framelessDismissInset: root.innerGap
    open: root.openDrawer === edge
    pointerRevealed: root.pointerRevealed
    onDismissRequested: root.dismissDrawer(edge)
    x: root.outerGap - root.leftDrawerWidth - root.innerGap + root.reservedLeft
    y: root.outerGap
    width: root.leftDrawerWidth + root.innerGap
    height: root.usableHeight

    VolumeModule {
      id: volumeDrawer
      anchors.fill: parent
    }
  }

  EdgeDrawer {
    id: rightDrawer
    objectName: "rightSystemDrawer"
    edge: "right"
    open: root.openDrawer === edge
    pointerRevealed: root.pointerRevealed
    onDismissRequested: root.dismissDrawer(edge)
    x: parent.width - root.outerGap + root.innerGap - root.reservedRight
    y: root.outerGap
    width: root.rightDrawerWidth
    height: parent.height - root.outerGap * 2

    SystemModule {
      id: systemDrawer
      anchors.fill: parent
      shell: root.shell
      pluginDir: root.pluginDir
    }
  }

  MediaModule {
    id: staticMedia
    x: root.outerGap + root.reservedLeft
    y: root.outerGap
    width: root.staticMediaWidth
    height: root.usableHeight
    shell: root.shell

    HoverHandler { id: nowPlayingHover }
  }

  DeckCenter {
    id: centerCanvas
    surfaceWidth: root.width
    surfaceHeight: root.height
    outerGap: root.outerGap
    usableWidth: root.usableWidth
    usableHeight: root.usableHeight
    reservedLeft: root.staticMediaReserve + root.reservedLeft
    reservedRight: root.reservedRight
    reservedTop: root.reservedTop
    reservedBottom: root.reservedBottom
    layoutController: root.layoutController
    deck: root
    shell: root.shell
    primaryMonitor: root.primaryMonitor
    appearanceController: root.appearanceController
    launcherController: root.launcherController
    weatherController: root.weatherController
    timerController: root.timerController
  }

  DeckOverlay {
    id: notificationOverlay
    objectName: "notificationCenterOverlay"
    x: 0
    width: parent.width
    height: parent.height
    z: 180
    origin: "top"
    title: "Notifications"
    subtitle: ""
    outerGap: root.outerGap
    open: root.openOverlayName === "notifications"
    onDismissRequested: root.closeOverlay()

    NotificationCenterModule {
      anchors.fill: parent
      shell: root.shell
      deck: root
      active: notificationOverlay.open
    }
  }

  DeckOverlay {
    id: overviewOverlay
    objectName: "omadeckOverviewOverlay"
    x: 0
    width: parent.width
    height: parent.height
    z: 180
    origin: "bottom"
    title: "OmaDeck overview"
    subtitle: ""
    outerGap: root.outerGap
    open: root.openOverlayName === "overview"
    onDismissRequested: root.closeOverlay()

    OverviewModule {
      anchors.fill: parent
      deck: root
      primaryMonitor: root.primaryMonitor
    }
  }

  // Generous touch zones begin the drawer gesture. The first foundation uses
  // single-point drags; multi-touch resize/edit handlers come with the layout
  // tree so gesture ownership remains unambiguous.
  EdgeSwipeArea { enabled: root.openOverlayName === ""; edge: "left"; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; onTriggered: root.toggleDrawer(edge) }
  EdgeSwipeArea { enabled: root.openOverlayName === ""; edge: "right"; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; onTriggered: root.toggleDrawer(edge) }
  EdgeSwipeArea { enabled: root.openOverlayName === ""; edge: "top"; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; onTriggered: root.toggleOverlay("notifications") }
  EdgeSwipeArea { enabled: root.openOverlayName === ""; edge: "bottom"; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; onTriggered: root.toggleOverlay("overview") }

  Button {
    visible: root.layoutController && root.layoutController.editMode
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: root.outerGap + Style.spacing.controlPaddingX
    z: 200
    text: "Done"
    iconText: "󰄬"
    selected: true
    foreground: Color.foreground
    onClicked: root.layoutController.finishEdit()
  }
}
