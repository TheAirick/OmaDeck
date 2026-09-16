import QtQuick
import Quickshell
import "./services"

ShellRoot {
  id: root
  property int phase: 0
  property int ticks: 0
  property int closedTicks: 0
  NotificationController { id: controller; pluginDir: Quickshell.env("HOME"); active: true }
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      if (++root.ticks > 200) { console.error("NOTIFICATION_FAILURE phase=" + root.phase + " error=" + controller.historyError + " loaded=" + controller.historyLoaded + " entries=" + controller.entries.length + " busy=" + controller.busy + " controls=" + JSON.stringify(controller.controlState)); Qt.exit(1); return }
      var entries = controller.entries
      if (root.phase === 0 && entries.length === 1 && controller.historyLoaded && controller.dndAvailable && !controller.busy) {
        root.phase = 1; console.log("HISTORY_READ")
      } else if (root.phase === 1 && entries.length === 2 && entries[0].live) {
        root.phase = 2; console.log("POPUP_READ")
      } else if (root.phase === 2 && entries[0].body === "Updated body") {
        root.phase = 3; console.log("POPUP_UPDATED")
      } else if (root.phase === 3 && entries.length === 2 && !entries[0].live) {
        root.phase = 4; controller.active = false; console.log("DRAWER_CLOSED")
      } else if (root.phase === 4 && ++root.closedTicks === 10) {
        if (entries.length !== 2) { console.error("NOTIFICATION_FAILURE watched while closed"); Qt.exit(1); return }
        root.phase = 5; controller.active = true
      } else if (root.phase === 5 && entries.length === 3 && !controller.busy) {
        root.phase = 6; console.log("DRAWER_REOPENED"); controller.clearAll()
      } else if (root.phase === 6 && entries.length === 0 && !controller.busy && !controller.loading) {
        root.phase = 7
      } else if (root.phase === 7) {
        if (entries.length) { console.error("NOTIFICATION_FAILURE clear repopulated"); Qt.exit(1); return }
        controller.active = false; console.log("NOTIFICATIONS_VERIFIED"); Qt.quit()
      }
    }
  }
}
