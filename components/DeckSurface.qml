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

  property var shell: null
  property var pluginRoot: null
  property var layoutController: null
  property var appearanceController: null
  property var weatherController: null
  property string targetScreen: "DP-3"
  property string primaryMonitor: "DP-1"
  property string openDrawer: ""
  property string lastDrawerTransition: "initial"
  property int drawerTransitionSequence: 0

  readonly property string drawerBuild: "persistent-drawers-v2"
  readonly property string componentUrl: String(Qt.resolvedUrl("DeckSurface.qml"))
  readonly property string sourceDir: pluginRoot && pluginRoot.pluginDir
    ? String(pluginRoot.pluginDir) : ""

  readonly property bool isTarget: screen && screen.name === targetScreen
  readonly property bool deckHovered: backgroundHover.hovered || centerHover.hovered
    || leftDrawer.pointerHovered || rightDrawer.pointerHovered
    || topDrawer.pointerHovered || bottomDrawer.pointerHovered
  readonly property bool pointerRevealed: deckHovered
    && !directTouch.touchInProgress
  readonly property int outerGap: Math.max(1, Style.gapsOut)
  readonly property int innerGap: Style.spacing.panelGap
  readonly property int usableWidth: Math.max(0, width - outerGap * 2)
  readonly property int usableHeight: Math.max(0, height - outerGap * 2)
  readonly property int leftDrawerWidth: Math.round(usableWidth * 0.34)
  readonly property int rightDrawerWidth: Math.round(usableWidth * 0.34)
  readonly property int topDrawerHeight: Style.space(78)
  readonly property int bottomDrawerHeight: Style.space(116)

  // Revealed modules reserve space in the same geometry as the center layout.
  // Animating these four boundaries makes the split tree re-tile instead of
  // translating intact panels beyond the physical display.
  property real reservedLeft: openDrawer === "left" ? leftDrawerWidth + innerGap : 0
  property real reservedRight: openDrawer === "right" ? rightDrawerWidth + innerGap : 0
  property real reservedTop: openDrawer === "top" ? topDrawerHeight + innerGap : 0
  property real reservedBottom: openDrawer === "bottom" ? bottomDrawerHeight + innerGap : 0

  Behavior on reservedLeft { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Behavior on reservedRight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Behavior on reservedTop { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Behavior on reservedBottom { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

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
  }

  Component.onCompleted: {
    directTouch.window = centerCanvas
    directTouch.start()
    console.info("[OmaDeckDrawer] loaded", JSON.stringify(drawerDiagnostics()))
  }

  function drawerDiagnostics() {
    return {
      openDrawer: openDrawer,
      lastTransition: lastDrawerTransition,
      sequence: drawerTransitionSequence,
      componentUrl: componentUrl,
      sourceDir: sourceDir,
      build: drawerBuild,
      deckHovered: deckHovered,
      backgroundHovered: backgroundHover.hovered,
      centerHovered: centerHover.hovered,
      touchInProgress: directTouch.touchInProgress,
      pointerRevealed: pointerRevealed
    }
  }

  function setOpenDrawer(nextDrawer, reason) {
    if (["", "left", "right", "top", "bottom"].indexOf(nextDrawer) === -1) return

    lastDrawerTransition = String(reason || "unspecified")
    drawerTransitionSequence++
    openDrawer = nextDrawer
  }

  function toggleDrawer(edge) {
    setOpenDrawer(DrawerGesture.toggleDrawer(openDrawer, edge), "toggle:" + edge)
  }

  function dismissDrawer(edge) {
    setOpenDrawer(DrawerGesture.dismissDrawer(openDrawer, edge), "dismiss:" + edge)
  }

  function closeDrawer() {
    setOpenDrawer("", "ipc:close")
  }

  IpcHandler {
    enabled: root.isTarget
    target: "pretty.omadeck"

    function drawer(edge: string): void {
      if (["left", "right", "top", "bottom"].indexOf(edge) !== -1) root.toggleDrawer(edge)
    }

    function closeDrawer(): void {
      root.closeDrawer()
    }

    function drawerState(): string {
      return JSON.stringify(root.drawerDiagnostics())
    }

    function touchState(): string {
      return JSON.stringify({
        active: directTouch.active,
        exclusiveGrab: directTouch.active,
        devicePath: directTouch.devicePath,
        status: directTouch.status
      })
    }

    function reconnectTouch(): void {
      directTouch.stop()
      directTouch.start()
    }

    function edit(enabled: bool): void {
      if (!root.layoutController) return
      if (enabled) root.layoutController.beginEdit("")
      else root.layoutController.finishEdit()
    }

    function ratio(path: string, value: real): void {
      if (root.layoutController) root.layoutController.setRatio(path, value)
    }

    function appearanceState(): string {
      if (!root.appearanceController || !root.appearanceController.loaded)
        return JSON.stringify({ ok: false, error: "Appearance settings are not ready" })
      var state = root.appearanceController.snapshot()
      state.ok = true
      return JSON.stringify(state)
    }

    function setAppearance(key: string, value: string): string {
      if (!root.appearanceController || !root.appearanceController.loaded)
        return JSON.stringify({ ok: false, error: "Appearance settings are not ready" })

      var booleanKeys = ["use24Hour", "showSeconds", "showWeather"]
      var stringKeys = ["clockStyle", "weatherStyle", "weatherDetail", "temperatureUnit"]
      if (booleanKeys.indexOf(key) === -1 && stringKeys.indexOf(key) === -1)
        return JSON.stringify({ ok: false, error: "Unknown appearance setting" })
      if (booleanKeys.indexOf(key) !== -1 && value !== "true" && value !== "false")
        return JSON.stringify({ ok: false, error: "Invalid boolean value" })

      var parsedValue = booleanKeys.indexOf(key) !== -1 ? value === "true" : value
      var persisted = root.appearanceController.setOption(key, parsedValue)
      var state = root.appearanceController.snapshot()
      if (!persisted)
        return JSON.stringify({ ok: false, error: "Appearance setting could not be saved", state: state })
      if (state[key] !== parsedValue)
        return JSON.stringify({ ok: false, error: "Appearance setting was rejected", state: state })
      return JSON.stringify({ ok: true, key: key, value: state[key], state: state })
    }

    function refreshWeather(): string {
      if (!root.appearanceController || !root.appearanceController.loaded)
        return JSON.stringify({ ok: false, error: "Appearance settings are not ready" })
      if (!root.appearanceController.showWeather)
        return JSON.stringify({ ok: false, error: "Weather is disabled" })
      if (!root.weatherController)
        return JSON.stringify({ ok: false, error: "Weather service is unavailable" })
      root.weatherController.refresh()
      return JSON.stringify({ ok: true })
    }

    function system(section: string): void {
      if (["performance", "network", "applications", "clipboard", "storage"].indexOf(section) === -1) return
      root.setOpenDrawer("right", "ipc:system:" + section)
      systemDrawer.selectedClipboard = null
      systemDrawer.selectedClientAddress = ""
      systemDrawer.selectedSection = section
    }

    function clipboard(index: int): void {
      if (index < 0 || index >= systemDrawer.stats.clipboard.length) return
      root.setOpenDrawer("right", "ipc:clipboard")
      systemDrawer.selectedSection = "clipboard"
      systemDrawer.selectedClipboard = systemDrawer.stats.clipboard[index]
    }

    function application(index: int): void {
      if (index < 0 || index >= systemDrawer.stats.clients.length) return
      root.setOpenDrawer("right", "ipc:application")
      systemDrawer.selectedSection = "applications"
      systemDrawer.selectedClientAddress = systemDrawer.stats.clients[index].address
    }

    function systemBack(): void {
      systemDrawer.goBack()
    }

    function clipboardCopy(): void {
      systemDrawer.copyClipboard(systemDrawer.selectedClipboard)
    }

    function clipboardDelete(): void {
      systemDrawer.deleteClipboard(systemDrawer.selectedClipboard)
    }

    function mediaCompact(compact: bool): void {
      root.setOpenDrawer("left", "ipc:mediaCompact")
      mediaDrawer.setMixerCompact(compact)
    }

    function mediaCategory(category: string): void {
      root.setOpenDrawer("left", "ipc:mediaCategory")
      mediaDrawer.setMixerCategory(category)
    }
  }

  Rectangle {
    id: deckBackground
    anchors.fill: parent
    color: Color.background

    HoverHandler {
      id: backgroundHover
    }
  }

  // Edge modules and the center split tree share one bounded tiling region.
  EdgeDrawer {
    id: leftDrawer
    edge: "left"
    open: root.openDrawer === edge
    pointerRevealed: root.pointerRevealed
    onDismissRequested: root.dismissDrawer(edge)
    x: root.outerGap - root.leftDrawerWidth - root.innerGap + root.reservedLeft
    y: root.outerGap
    width: root.leftDrawerWidth
    height: root.usableHeight

    MediaModule {
      id: mediaDrawer
      anchors.fill: parent
      shell: root.shell
    }
  }

  EdgeDrawer {
    id: rightDrawer
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
    }
  }

  EdgeDrawer {
    id: topDrawer
    edge: "top"
    open: root.openDrawer === edge
    pointerRevealed: root.pointerRevealed
    onDismissRequested: root.dismissDrawer(edge)
    x: root.outerGap
    y: root.outerGap - root.topDrawerHeight - root.innerGap + root.reservedTop
    width: root.usableWidth
    height: root.topDrawerHeight

    WorkspaceModule {
      anchors.fill: parent
      compact: true
      singleRow: true
      primaryMonitor: root.primaryMonitor
    }
  }

  EdgeDrawer {
    id: bottomDrawer
    edge: "bottom"
    open: root.openDrawer === edge
    pointerRevealed: root.pointerRevealed
    onDismissRequested: root.dismissDrawer(edge)
    x: root.outerGap
    y: parent.height - root.outerGap + root.innerGap - root.reservedBottom
    width: root.usableWidth
    height: root.bottomDrawerHeight

    AppLauncherModule {
      anchors.fill: parent
      shell: root.shell
      primaryMonitor: root.primaryMonitor
    }
  }

  Item {
    id: centerCanvas
    x: root.outerGap + root.reservedLeft
    y: root.outerGap + root.reservedTop
    width: Math.max(0, root.usableWidth - root.reservedLeft - root.reservedRight)
    height: Math.max(0, root.usableHeight - root.reservedTop - root.reservedBottom)

    Rectangle {
      anchors.fill: parent
      color: Color.background
    }

    SplitNode {
      anchors.fill: parent
      controller: root.layoutController
      path: ""
      deck: root
      shell: root.shell
      primaryMonitor: root.primaryMonitor
      appearanceController: root.appearanceController
      weatherController: root.weatherController
    }

    HoverHandler {
      id: centerHover
    }

  }

  // Generous touch zones begin the drawer gesture. The first foundation uses
  // single-point drags; multi-touch resize/edit handlers come with the layout
  // tree so gesture ownership remains unambiguous.
  EdgeSwipeArea { edge: "left"; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; onTriggered: root.toggleDrawer(edge) }
  EdgeSwipeArea { edge: "right"; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; onTriggered: root.toggleDrawer(edge) }
  EdgeSwipeArea { edge: "top"; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; onTriggered: root.toggleDrawer(edge) }
  EdgeSwipeArea { edge: "bottom"; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; onTriggered: root.toggleDrawer(edge) }

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
