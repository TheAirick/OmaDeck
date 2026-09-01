import QtQuick
import qs.Commons

Item {
  id: root

  property var controller: null
  property var timer: null
  property bool interactionEnabled: true
  property date now: new Date()

  readonly property bool use24Hour: controller ? controller.use24Hour : false
  readonly property bool showSeconds: controller ? controller.showSeconds : false
  readonly property string timerStatus: timer ? timer.status : "idle"
  readonly property real timerProgress: timer ? timer.progress : 0

  signal setupRequested()

  clip: true

  function timeText() {
    var pattern = use24Hour ? (showSeconds ? "HH:mm:ss" : "HH:mm") : (showSeconds ? "h:mm:ss AP" : "h:mm AP")
    return Qt.formatDateTime(now, pattern)
  }

  function timerSummary() {
    if (timerStatus === "paused") return "Timer paused"
    if (timerStatus === "completed") return "Time's up"
    if (timerStatus === "active") return "Timer running"
    return Qt.formatDateTime(now, "ddd, MMM d")
  }

  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

  Item {
    id: compactClock
    objectName: "compactClock"
    anchors.fill: parent

    Column {
      anchors.centerIn: parent
      width: parent.width
      spacing: Style.spacing.labelGap

      Text {
        objectName: "clockTime"
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.timeText()
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Math.min(root.width * 0.18, root.height * 0.62, Style.font.displayLarge * 2.2)
        font.weight: Font.DemiBold
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.timerSummary()
        color: root.timerStatus !== "idle" ? Color.accent : Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }

    TapHandler {
      enabled: root.interactionEnabled && root.timerStatus === "idle"
      onTapped: root.setupRequested()
    }

    Rectangle {
      visible: root.timerStatus === "active" || root.timerStatus === "paused"
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 4
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)

      Rectangle {
        height: parent.height
        width: parent.width * root.timerProgress
        color: Color.accent
        opacity: root.timerStatus === "paused" ? 0.62 : 0.9
        Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.Linear } }
      }
    }
  }
}
