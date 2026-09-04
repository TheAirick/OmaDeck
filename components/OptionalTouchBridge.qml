import QtQuick
import Quickshell.Io

Item {
  id: root

  property var window: null
  property var deviceNames: []
  property string pluginDir: ""
  property url nativeSource: Qt.resolvedUrl("NativeTouchBridge.qml")
  property bool wantsActive: false
  property bool nativeArtifactPresent: false

  readonly property var bridge: bridgeLoader.status === Loader.Ready ? bridgeLoader.item : null
  readonly property bool nativeAvailable: bridge !== null
  readonly property string mode: nativeAvailable ? "native" : "compositor"
  readonly property bool active: nativeAvailable && bridge.active
  readonly property bool touchInProgress: nativeAvailable && bridge.touchInProgress
  readonly property string devicePath: nativeAvailable ? bridge.devicePath : ""
  readonly property string activeDeviceName: nativeAvailable ? bridge.activeDeviceName : ""
  readonly property var availableDeviceNames: nativeAvailable ? bridge.availableDeviceNames : []
  readonly property string status: nativeAvailable
    ? bridge.status
    : "Native touch bridge unavailable; using compositor-managed input"
  readonly property string nativeLibraryPath: pluginDir === "" ? ""
    : pluginDir + "/native/OmaDeck/Touch/libomadecktouchplugin.so"

  function syncBridge() {
    if (!bridge) return
    bridge.window = window
    bridge.deviceNames = deviceNames
    if (wantsActive) bridge.start()
  }

  function start() {
    wantsActive = true
    if (bridge) return bridge.start()
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
