import QtQuick
import qs.Commons
import "ClockCompanionPolicy.js" as ClockCompanionPolicy

Item {
  id: root

  property var controller: null
  property var weather: null
  property var timer: null
  property bool interactionEnabled: true
  property date now: new Date()

  readonly property bool use24Hour: controller ? controller.use24Hour : false
  readonly property bool showSeconds: controller ? controller.showSeconds : false
  readonly property bool showWeather: controller ? controller.showWeather : true
  readonly property string weatherStyle: controller ? controller.weatherStyle : "scene"
  readonly property string weatherDetail: controller ? controller.weatherDetail : "standard"
  readonly property string temperatureUnit: controller ? controller.temperatureUnit : "fahrenheit"
  readonly property string timerStatus: timer ? timer.status : "idle"
  readonly property real timerProgress: timer ? timer.progress : 0
  readonly property string occupant: ClockCompanionPolicy.occupant(root.timerStatus, timerPresenter.setupOpen)
  readonly property int panelGap: Style.spacing.panelGap
  readonly property real splitHeight: Math.max(0, height - panelGap)
  readonly property real clockHeight: Math.round(splitHeight * 0.37)
  readonly property real companionHeight: Math.max(0, splitHeight - clockHeight)

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
    width: parent.width
    height: root.clockHeight

    Column {
      anchors.centerIn: parent
      width: parent.width
      spacing: Style.spacing.labelGap

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.timeText()
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Math.min(root.width * 0.14, root.clockHeight * 0.46, Style.font.displayLarge * 1.35)
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
      enabled: root.interactionEnabled && root.timerStatus === "idle" && !timerPresenter.setupOpen
      onTapped: timerPresenter.openSetup()
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

  Item {
    id: companionSlot
    objectName: "companionSlot"
    y: root.clockHeight + root.panelGap
    width: parent.width
    height: root.companionHeight
    clip: true

    Item {
      id: weatherPresenter
      objectName: "weatherPresenter"
      anchors.fill: parent
      visible: root.occupant === "weather"

      WeatherModule {
        anchors.fill: parent
        visible: root.showWeather
        enabled: root.showWeather
        weatherController: root.weather
        visualStyle: root.weatherStyle
        detailMode: root.weatherDetail
        temperatureUnit: root.temperatureUnit
      }

      Text {
        anchors.centerIn: parent
        visible: !root.showWeather
        text: "Weather disabled"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }

    TimerModule {
      id: timerPresenter
      objectName: "timerPresenter"
      anchors.fill: parent
      visible: root.occupant === "timer"
      timer: root.timer
      companionMode: true
    }
  }
}
