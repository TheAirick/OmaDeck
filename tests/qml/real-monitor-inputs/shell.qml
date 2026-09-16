import QtQuick
import Quickshell
import "../../../services" as Stores

Item {
  id: root
  property int stage: 0
  property int attempts: 0
  Stores.MonitorInputController { id: store; pluginDir: Quickshell.env("OMADECK_MONITOR_FIXTURE") }
  function report() { console.log("MONITOR_STATE " + JSON.stringify(store.snapshot())); Qt.quit() }
  Timer {
    interval: 50; running: true; repeat: true
    onTriggered: {
      if (++root.attempts > 160) { console.error("MONITOR_FAILURE timeout"); Qt.quit(); return }
      if (!store.loaded || !store.directoryReady) return
      if (Quickshell.env("OMADECK_MONITOR_PHASE") === "read") { root.report(); return }
      if (Quickshell.env("OMADECK_MONITOR_PHASE").indexOf("check") === 0) {
        if (root.stage === 0) {
          store.setupStatus = { state: "ready" }
          if (!store.checkSetup() || store.setupStatus !== null) { console.error("MONITOR_FAILURE check start"); Qt.quit(); return }
          root.stage = 1
        } else if (!store.busy) {
          var failed = Quickshell.env("OMADECK_MONITOR_PHASE") === "check-failure"
          if (failed ? store.setupStatus !== null || store.notice !== "Fixture setup check failed"
            : !store.setupStatus || store.setupStatus.state !== "ready") {
            console.error("MONITOR_FAILURE check result"); Qt.quit(); return
          }
          root.report()
        }
        return
      }
      if (root.stage === 0) {
        if (!store.scan()) { console.error("MONITOR_FAILURE scan"); Qt.quit(); return }
        root.stage = 1
      } else if (root.stage === 1 && !store.busy) {
        if (store.detectedMonitors.length !== 1 || !store.addMonitor("a".repeat(64))
            || !store.setShown(true) || !store.setSource("a".repeat(64), "11", true, "Laptop")
            || !store.switchInput("a".repeat(64), "11")) {
          console.error("MONITOR_FAILURE setup"); Qt.quit(); return
        }
        if (store.setShown(false)) { console.error("MONITOR_FAILURE mutation during switch"); Qt.quit(); return }
        root.stage = 2
      } else if (root.stage === 2 && !store.busy) {
        if (store.notice !== "Fixture monitor disconnected" || !store.showControls) {
          console.error("MONITOR_FAILURE failure state"); Qt.quit(); return
        }
        root.report()
      }
    }
  }
}
