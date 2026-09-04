import QtQuick
import Quickshell
import "services"
Item {
  id: root
  property int phase: 0
  property bool selectionsRecovered: false
  AppearanceController { id: appearance }
  HardwareController { id: hardware; availableScreenNames: ["fixture-old", "fixture-new"] }
  LayoutController { id: layout }
  LauncherController { id: launcher }
  TimerController { id: countdown }
  WeatherController { id: weather; pluginDir: "/nonexistent-omadeck-test" }
  Component.onCompleted: Qt.callLater(function() { weather.enabled = true })
  Timer {
    interval: 50
    running: true
    repeat: true
    onTriggered: {
      if (root.phase === 0 && layout.loaded && launcher.loaded && countdown.soundSettingsLoaded
          && appearance.loaded && hardware.loaded) {
        root.phase = 1
        layout.setRatio("", 0.6)
        launcher.remove("terminal")
        appearance.setOption("use24Hour", true)
        hardware.setTargetScreen("fixture-new")
      } else if (root.phase === 1 && layout.saveError !== "" && launcher.saveError !== ""
                 && countdown.lastSaveError !== "" && !weather.loading && weather.error !== ""
                 && appearance.lastSaveError !== "" && hardware.lastSaveError !== "") {
        root.phase = 2
        console.log("FAULTS_OBSERVED")
        retrySelections.restart()
      } else if (root.phase === 2 && !layout.savePending && !launcher.savePending
                 && countdown.timerState.notificationSent && root.selectionsRecovered) {
        root.phase = 3
        console.log("RECOVERED")
        finish.restart()
      }
    }
  }
  Timer { id: finish; interval: 1200; onTriggered: Qt.quit() }
  Timer {
    id: retrySelections
    interval: 500
    onTriggered: {
      var appearanceSaved = appearance.setOption("use24Hour", true)
      var hardwareSaved = hardware.setTargetScreen("fixture-new")
      root.selectionsRecovered = appearanceSaved && hardwareSaved
      if (!root.selectionsRecovered) console.error("SELECTION_RETRY_FAILED")
    }
  }
}
