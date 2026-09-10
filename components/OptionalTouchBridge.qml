import QtQuick
import Quickshell.Io

Item {
  id: root

  property var window: null
  property var deviceNames: []
  property string pluginDir: ""
  property url nativeSource: Qt.resolvedUrl("NativeTouchBridge.qml")
  property bool wantsActive: false
  // Direct injection bypasses the compositor's session-lock input routing.
  // Only use it when the host exposes a synchronous lock-state guard.
  property bool directRoutingAllowed: true
  property bool nativeArtifactPresent: false

  readonly property var bridge: bridgeLoader.status === Loader.Ready ? bridgeLoader.item : null
  readonly property bool nativeAvailable: bridge !== null
  readonly property bool hostGuardAvailable: !!bridge && bridge.hostGuardAvailable === true
  readonly property bool hostInputAllowed: !!bridge && bridge.hostInputAllowed === true
  readonly property bool routingAllowed: directRoutingAllowed || hostGuardAvailable
  readonly property string mode: nativeAvailable && routingAllowed ? "native" : "compositor"
  readonly property bool active: nativeAvailable && bridge.active
  readonly property bool touchInProgress: nativeAvailable && bridge.touchInProgress
  readonly property string devicePath: nativeAvailable ? bridge.devicePath : ""
  readonly property string activeDeviceName: nativeAvailable ? bridge.activeDeviceName : ""
  readonly property var availableDeviceNames: nativeAvailable ? bridge.availableDeviceNames : []
  readonly property string status: !routingAllowed
    ? "Compositor-managed touch: host input guard unavailable; map touchscreen in Hyprland"
    : hostGuardAvailable && !hostInputAllowed
    ? "Direct touch blocked by the host lock input guard"
    : nativeAvailable
    ? bridge.status
    : "Native touch bridge unavailable; using compositor-managed input"
  readonly property string nativeLibraryPath: pluginDir === "" ? ""
    : pluginDir + "/native/OmaDeck/Touch/libomadecktouchplugin.so"

  function syncBridge() {
    if (!bridge) return
    bridge.window = window
    bridge.deviceNames = deviceNames
    if ("requireHostGuard" in bridge) bridge.requireHostGuard = !directRoutingAllowed
    if (wantsActive && routingAllowed) bridge.start()
    else bridge.stop()
  }

  function start() {
    wantsActive = true
    if (bridge && routingAllowed) return bridge.start()
    return true
  }

  function stop() {
    wantsActive = false
    if (bridge) bridge.stop()
  }

  function refreshDevices() {
    if (bridge) bridge.refreshDevices()
  }

  onWindowChanged: if (bridge) bridge.window = window
  onDeviceNamesChanged: if (bridge) bridge.deviceNames = deviceNames
  onRoutingAllowedChanged: syncBridge()
  onDirectRoutingAllowedChanged: {
    if (bridge && "requireHostGuard" in bridge) bridge.requireHostGuard = !directRoutingAllowed
  }
  onNativeLibraryPathChanged: probeNativeBridge()

  function probeNativeBridge() {
    nativeArtifactPresent = false
    if (nativeLibraryPath === "" || nativeSource.toString() === "") return
    nativeProbe.running = true
  }

  Process {
    id: nativeProbe
    command: ["/usr/bin/test", "-f", root.nativeLibraryPath]
    onExited: function(exitCode) {
      root.nativeArtifactPresent = exitCode === 0
    }
  }

  Loader {
    id: bridgeLoader
    active: root.nativeArtifactPresent && root.nativeSource.toString() !== ""
    source: active ? root.nativeSource : ""
    onLoaded: root.syncBridge()
  }

  Component.onCompleted: probeNativeBridge()
}
