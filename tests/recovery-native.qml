import QtQuick
import Quickshell
import "services"
Item {
  id: root
  property int phase: 0
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
      if (root.phase === 0 && layout.loaded && launcher.loaded && countdown.soundSettingsLoaded) {
        root.phase = 1
        layout.setRatio("", 0.6)
        launcher.remove("terminal")
      } else if (root.phase === 1 && layout.saveError !== "" && launcher.saveError !== ""
                 && countdown.lastSaveError !== "" && !weather.loading && weather.error !== "") {
        root.phase = 2
        console.log("FAULTS_OBSERVED")
      } else if (root.phase === 2 && !layout.savePending && !launcher.savePending
                 && countdown.timerState.notificationSent) {
        root.phase = 3
        console.log("RECOVERED")
        finish.restart()
      }
    }
  }
  Timer { id: finish; interval: 1200; onTriggered: Qt.quit() }
}
