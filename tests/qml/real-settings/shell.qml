import QtQuick
import Quickshell
import "../../../services" as Stores

// Real Quickshell/FileView integration, not the tests/qml/imports stubs.
// The Node harness supplies private HOME/XDG directories; no shell UI is loaded.
Item {
  id: root
  property int attempts: 0
  property bool written: false

  Stores.AppearanceController { id: appearance }
  Stores.HardwareController {
    id: hardware
    availableScreenNames: ["fixture-original", "fixture-primary", "fixture-deck"]
    availableTouchDeviceNames: ["Fixture Touchscreen"]
  }
  Stores.LayoutController { id: layout }
  Stores.LauncherController { id: launcher }
  Stores.TimerController { id: timer }

  function report() {
    console.log("READINESS_STATE " + JSON.stringify({
      appearance: appearance.snapshot(),
      hardware: hardware.snapshot(),
      layout: layout.layout,
      launcher: launcher.entryIds,
      timerSound: timer.selectedSoundId,
      timerStatus: timer.timerState.status
    }))
    Qt.quit()
  }

  Timer {
    interval: 50
    running: true
    repeat: true
    onTriggered: {
      root.attempts++
      if (root.attempts > 160) {
        console.error("READINESS_FAILURE controllers did not load")
        Qt.quit()
        return
      }
      if (!appearance.loaded || !hardware.loaded || !layout.loaded
          || !launcher.loaded || !timer.loaded || !timer.soundSettingsLoaded) return
      if (Quickshell.env("OMADECK_SETTINGS_PHASE") === "read") {
        if (!appearance.setOption("use24Hour", appearance.use24Hour)
            || !hardware.setTargetScreen(hardware.targetScreen)) {
          console.error("READINESS_FAILURE selecting a persisted option reported failure")
          Qt.quit()
          return
        }
        root.report()
        return
      }
      if (root.written) return
      root.written = true
      var saves = {
        time: appearance.setOption("use24Hour", true),
        unit: appearance.setOption("temperatureUnit", "celsius"),
        screen: hardware.setTargetScreen("fixture-deck"),
        primary: hardware.setPrimaryMonitor("fixture-primary"),
        touch: hardware.setTouchDevice("Fixture Touchscreen"),
        sound: timer.selectSoundId("bell")
      }
      if (Object.values(saves).some(function(value) { return !value })) {
        console.error("READINESS_FAILURE blocking save rejected " + JSON.stringify(saves))
        Qt.quit()
        return
      }
      layout.setRatio("", 0.62)
      launcher.remove("browser")
      settle.start()
    }
  }
  Timer { id: settle; interval: 600; onTriggered: root.report() }
}
