import QtQuick

Item {
  property var window: null
  property var deviceNames: []
  property bool active: false
  property bool hostGuardAvailable: false
  property bool hostInputAllowed: false
  property bool requireHostGuard: true
  property bool touchInProgress: false
  property string devicePath: active ? "/dev/input/fixture" : ""
  property string activeDeviceName: active ? "Fixture Touch" : ""
  property var availableDeviceNames: ["Fixture Touch"]
  property string status: active ? "Isolated direct touch" : "Stopped"
  property int starts: 0
  function start() { starts++; active = true; return true }
  function stop() { active = false; touchInProgress = false }
  function refreshDevices() {}
}
