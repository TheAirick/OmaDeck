import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../modules"
import "../services"
import "DrawerGesture.js" as DrawerGesture

PanelWindow {
  id: root

  readonly property string lockServiceId: shell && shell.pluginRegistry
    && typeof shell.pluginRegistry.resolveEnabledId === "function"
    ? shell.pluginRegistry.resolveEnabledId("omarchy.lock") : "omarchy.lock"
  readonly property var lockService: shell && typeof shell.serviceFor === "function"
    ? shell.serviceFor(lockServiceId) : null
  // Newer hosts keep authentication services private. Their optional native
  // guard publishes only permission, without exposing the authentication object.
  // If neither guard exists, release input to the compositor's lock routing.
  readonly property bool interactionAllowed: !!shell && (lockService
    ? lockService.locked === false && lockService.strandedLockResolved === true
      && lockService.strandedLock === false
    : directTouch.hostGuardAvailable ? directTouch.hostInputAllowed
    : directTouch.mode === "compositor" && !directTouch.active)
  Binding {
    target: root.contentItem
    property: "enabled"
    value: root.interactionAllowed
  }

  property var serviceHost: null
  property var shell: null
  property string pluginDir: ""
  property var layoutController: null
  property var appearanceController: null
  property var launcherController: null
  property var hardwareController: null
  property var monitorInputController: null
  property var weatherController: null
  property var timerController: null
  property string targetScreen: "DP-3"
  property string primaryMonitor: "DP-1"
  property var touchDeviceNames: []
  property string openDrawer: ""
  property string openOverlayName: ""
  // Keep the dashboard inert through the entire open/close animation. A
  // painted overlay does not stop passive TapHandlers in siblings below it.
  readonly property bool dashboardInputAllowed: openOverlayName === ""
    && !notificationOverlay.visible && !overviewOverlay.visible && !preferencesOverlay.visible
  property string commandCenterPage: "home"
  property string lastDrawerTransition: "initial"
  property int drawerTransitionSequence: 0
  property url nativeTouchSource: Qt.resolvedUrl("NativeTouchBridge.qml")

  readonly property string drawerBuild: "preferences-overlay-v1"
  readonly property string componentUrl: String(Qt.resolvedUrl("DeckSurface.qml"))
  readonly property string sourceDir: pluginDir

  readonly property bool isTarget: screen && screen.name === targetScreen
  readonly property var availableTouchDeviceNames: directTouch.availableDeviceNames
  readonly property string activeTouchDeviceName: directTouch.activeDeviceName
  readonly property bool deckHovered: backgroundHover.hovered || centerCanvas.pointerHovered
    || leftDrawer.pointerHovered || rightDrawer.pointerHovered
    || notificationOverlay.pointerHovered || overviewOverlay.pointerHovered
    || preferencesOverlay.pointerHovered
  readonly property bool pointerRevealed: deckHovered
    && !directTouch.touchInProgress
  readonly property int outerGap: Math.max(1, Style.gapsOut)
  readonly property int innerGap: Style.spacing.panelGap
  readonly property int usableWidth: Math.max(0, width - outerGap * 2)
  readonly property int usableHeight: Math.max(0, height - outerGap * 2)
  readonly property bool customizing: !!(layoutController && layoutController.editMode)
  readonly property var hostMedia: shell && typeof shell.serviceFor === "function"
    ? shell.serviceFor("omarchy.media") : null
  readonly property var dashboardMedia: hostMedia || nativeMedia
  property var timerCompanion: null
  readonly property bool timerPanelOpen: !!(timerCompanion && timerCompanion.timerPanelOpen)
  MprisMediaAdapter { id: nativeMedia; enabled: !root.hostMedia }
  function openTimerPanel() { if (timerCompanion) timerCompanion.openTimer() }

  function beginCustomize() {
    if (!layoutController) return
    closeDrawer()
    layoutController.beginEdit("")
  }
  readonly property int leftDrawerWidth: Math.min(Math.round(usableWidth * 0.46),
    Math.ceil(volumeDrawer.preferredDrawerWidth))
  readonly property int rightDrawerWidth: Math.round(usableWidth * 0.34)

  // Horizontal drawers remain part of the tiling geometry. Vertical gestures
  // own full-surface overlays and therefore never steal height from the center.
  property real reservedLeft: openDrawer === "left" ? leftDrawerWidth + innerGap : 0
  property real reservedRight: openDrawer === "right" ? rightDrawerWidth + innerGap : 0
  readonly property real reservedTop: customizing ? Style.space(68) : 0
  readonly property real reservedBottom: 0

  Behavior on reservedLeft { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Behavior on reservedRight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

  visible: isTarget
  anchors { top: true; right: true; bottom: true; left: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omadeck"
  WlrLayershell.layer: launcherKeyboardRequested ? WlrLayer.Top : WlrLayer.Bottom
  // Request keys only during explicit launcher text entry. Direct touch
  // bypasses compositor pointer focus. Exclusive keys need the top layer;
  // closing, changing category or locking
  // releases keyboard ownership immediately.
  readonly property bool launcherKeyboardRequested: interactionAllowed && openOverlayName === "preferences" && preferencesPresenter.selectedCategory === "launcher" && preferencesPresenter.keyboardRequested
  WlrLayershell.keyboardFocus: launcherKeyboardRequested ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  function editLauncher(addApp) {
    showPreferences("launcher")
    if (addApp) preferencesPresenter.browseLauncherApps()
  }

  OptionalTouchBridge {
    id: directTouch
    objectName: "deckTouchBridge"
    directRoutingAllowed: !!root.lockService
    pluginDir: root.pluginDir
    nativeSource: root.nativeTouchSource
    deviceNames: root.touchDeviceNames
  }

  Component.onCompleted: {
    // Input belongs to the whole surface: modal overlays disable the center,
    // while the root continues to enforce the existing session-lock guard.
    directTouch.window = root.contentItem
    directTouch.start()
    if (serviceHost) serviceHost.registerSurface(root)
    console.info("[OmaDeckDrawer] loaded", JSON.stringify(drawerDiagnostics()))
  }

  Component.onDestruction: {
    if (serviceHost) serviceHost.unregisterSurface(root)
  }

  function drawerDiagnostics() {
    return {
      interactionAllowed: interactionAllowed,
      dashboardInputAllowed: dashboardInputAllowed,
      inputMode: directTouch.mode,
      mediaProvider: root.hostMedia ? "omarchy" : "mpris",
      mediaHasPlayer: !!root.dashboardMedia.activePlayer,
      lockServiceAvailable: !!lockService,
      hostInputGuardAvailable: directTouch.hostGuardAvailable,
      hostInputAllowed: directTouch.hostInputAllowed,
      lockResolved: lockService ? lockService.strandedLockResolved : false,
      systemRefreshActive: systemDrawer.active,
      systemLastUpdatedMs: systemDrawer.lastUpdatedMs,
      systemUpdateFailed: systemDrawer.statsError !== "",
      audioRefreshActive: volumeDrawer.active,
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
    if (["", "notifications", "overview", "preferences"].indexOf(nextOverlay) === -1) return
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

  function showPreferences(category) {
    if (category === "customize") { beginCustomize(); return }
    var setup = category === "monitor-setup"
    if (setup) category = "monitors"
    if (!preferencesPresenter.categories.some(function(row) { return row.id === category })) return
    preferencesPresenter.selectedCategory = category
    openOverlay("preferences")
    if (setup) preferencesPresenter.startMonitorSetup()
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
      nativeAvailable: directTouch.nativeAvailable,
      mode: directTouch.mode,
      hostInputGuardAvailable: directTouch.hostGuardAvailable,
      hostInputAllowed: directTouch.hostInputAllowed,
      interactionAllowed: interactionAllowed,
      devicePath: directTouch.devicePath,
      activeDeviceName: directTouch.activeDeviceName,
      availableDeviceNames: directTouch.availableDeviceNames,
      configuredDeviceNames: directTouch.deviceNames,
      status: directTouch.status
    })
  }

  function refreshTouchDevices() {
    directTouch.refreshDevices()
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
    enabled: root.dashboardInputAllowed && !root.customizing
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
      active: leftDrawer.open && root.interactionAllowed
      anchors.fill: parent
    }
  }

  EdgeDrawer {
    id: rightDrawer
    enabled: root.dashboardInputAllowed && !root.customizing
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
      active: rightDrawer.open && root.interactionAllowed
      anchors.fill: parent
      shell: root.shell
      pluginDir: root.pluginDir
    }
  }

  DeckCenter {
    id: centerCanvas
    enabled: root.dashboardInputAllowed
    surfaceWidth: root.width
    surfaceHeight: root.height
    outerGap: root.outerGap
    usableWidth: root.usableWidth
    usableHeight: root.usableHeight
    reservedLeft: root.reservedLeft
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
    overlayId: "notification"
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
    overlayId: "overview"
    title: "Workspaces"
    subtitle: ""
    outerGap: root.outerGap
    open: root.openOverlayName === "overview"
    onDismissRequested: root.closeOverlay()

    OverviewModule {
      active: overviewOverlay.open && root.interactionAllowed
      appearanceController: root.appearanceController
      shell: root.shell
      anchors.fill: parent
      deck: root
      primaryMonitor: root.primaryMonitor
    }
  }

  DeckOverlay {
    id: preferencesOverlay
    objectName: "preferencesOverlay"
    x: 0
    width: parent.width
    height: parent.height
    z: 190
    origin: "top"
    overlayId: "preferences"
    title: "OmaDeck preferences"
    subtitle: ""
    outerGap: root.outerGap
    open: root.openOverlayName === "preferences"
    onDismissRequested: root.closeOverlay()

    PreferencesModule {
      id: preferencesPresenter
      anchors.fill: parent
      deck: root
      appearanceController: root.appearanceController
      layoutController: root.layoutController
      hardwareController: root.hardwareController
      monitorInputController: root.monitorInputController
      weatherController: root.weatherController
      timerController: root.timerController
    }
  }

  // Generous touch zones begin the drawer gesture. The first foundation uses
  // single-point drags; multi-touch resize/edit handlers come with the layout
  // tree so gesture ownership remains unambiguous.
  EdgeSwipeArea { enabled: root.dashboardInputAllowed && !root.customizing; edge: "left"; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; onTriggered: root.toggleDrawer(edge) }
  EdgeSwipeArea { enabled: root.dashboardInputAllowed && !root.customizing; edge: "right"; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; onTriggered: root.toggleDrawer(edge) }
  EdgeSwipeArea { enabled: root.dashboardInputAllowed && !root.customizing; edge: "top"; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; onTriggered: root.toggleOverlay("notifications") }
  EdgeSwipeArea { enabled: root.dashboardInputAllowed && !root.customizing; edge: "bottom"; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; onTriggered: root.toggleOverlay("overview") }

  // Keep failed-save feedback reachable even after the editing UI closes.
  // Controllers retain dirty state and own the retry; never expose raw errors.
  Column {
    enabled: root.dashboardInputAllowed
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.margins: root.outerGap + Style.spacing.controlPaddingX
    spacing: Style.spacing.controlGap
    z: 201

    Button {
      objectName: "layoutSaveRetry"
      visible: !!(root.layoutController && root.layoutController.saveError)
      text: "Layout not saved · Retry"
      onClicked: root.layoutController.persist()
    }

    Button {
      objectName: "launcherSaveRetry"
      visible: !!(root.launcherController && root.launcherController.saveError)
      text: "Applications not saved · Retry"
      onClicked: root.launcherController.persist()
    }
  }

  Item {
    visible: root.customizing
    enabled: root.dashboardInputAllowed
    x: root.outerGap
    y: root.outerGap
    width: root.usableWidth
    height: root.reservedTop - root.innerGap
    z: 200
    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.controlPaddingX
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(0, editActions.x - x - Style.spacing.controlGap)
      text: "Customize · Drag panels to move, tap two to swap, drag dividers to resize"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
    }
    Row {
      id: editActions
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.controlGap
      Button {
        objectName: "cancelCustomize"
        text: "Cancel"
        height: Style.space(48)
        bordered: false
        onClicked: root.layoutController.cancelEdit()
      }
      Button {
        objectName: "finishCustomize"
        text: "Done"
        height: Style.space(48)
        selected: true
        foreground: Color.foreground
        onClicked: root.layoutController.finishEdit()
      }
    }
  }
}
