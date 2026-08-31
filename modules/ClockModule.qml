import QtQuick
import qs.Commons

Item {
  id: root

  clip: true

  property var controller: null
  property var weather: null
  property var timer: null
  property bool interactionEnabled: true
  property date now: new Date()

  readonly property string clockStyle: controller ? controller.clockStyle : "hero"
  readonly property bool use24Hour: controller ? controller.use24Hour : false
  readonly property bool showSeconds: controller ? controller.showSeconds : false
  readonly property bool showWeather: controller ? controller.showWeather : true
  readonly property string weatherStyle: controller ? controller.weatherStyle : "scene"
  readonly property string weatherDetail: controller ? controller.weatherDetail : "standard"
  readonly property string temperatureUnit: controller ? controller.temperatureUnit : "fahrenheit"
  readonly property string timerStatus: timer ? timer.status : "idle"
  readonly property string timerRemainingText: timer ? timer.remainingText : "0:00"
  readonly property real timerProgress: timer ? timer.progress : 0

  function timeText() {
    var pattern = use24Hour ? (showSeconds ? "HH:mm:ss" : "HH:mm") : (showSeconds ? "h:mm:ss AP" : "h:mm AP")
    return Qt.formatDateTime(now, pattern)
  }

  function secondaryText(datePattern) {
    if (timerStatus === "paused") return "Paused · " + timerRemainingText
    if (timerStatus === "completed") return "● Time's up"
    if (timerStatus === "active") return "● " + timerRemainingText
    return Qt.formatDateTime(now, datePattern)
  }

  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

  Loader {
    anchors.fill: parent
    sourceComponent: root.clockStyle === "split" ? splitClock : root.clockStyle === "compact" ? compactClock : heroClock
  }

  TapHandler {
    enabled: root.interactionEnabled && !timerPresenter.open
    onTapped: timerPresenter.openForCurrentStatus()
  }

  Rectangle {
    id: timerProgressRail
    visible: root.timerStatus === "active" || root.timerStatus === "paused"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 4
    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
    z: 20

    Rectangle {
      height: parent.height
      width: parent.width * root.timerProgress
      color: Color.accent
      opacity: root.timerStatus === "paused" ? 0.62 : 0.9

      Behavior on width {
        NumberAnimation { duration: 100; easing.type: Easing.Linear }
      }
    }
  }

  TimerModule {
    id: timerPresenter
    anchors.fill: parent
    timer: root.timer
    z: 50
  }

  Component {
    id: heroClock
    Column {
      anchors.fill: parent
      spacing: Style.spacing.controlGap

      Item {
        width: parent.width
        height: root.showWeather ? Math.max(90, parent.height * 0.48) : parent.height
        Column {
          anchors.centerIn: parent
          spacing: Style.spacing.labelGap
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeText()
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Math.min(root.width * 0.17, root.height * 0.30)
            font.weight: Font.DemiBold
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.secondaryText("dddd, MMMM d")
            color: root.timerStatus !== "idle" ? Color.accent : Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }
      }

      WeatherModule {
        enabled: root.showWeather
        width: parent.width
        height: Math.max(0, parent.height - y)
        weatherController: root.weather
        visualStyle: root.weatherStyle
        detailMode: root.weatherDetail
        temperatureUnit: root.temperatureUnit
      }
    }
  }

  Component {
    id: splitClock
    Row {
      anchors.fill: parent
      spacing: Style.spacing.panelGap

      Column {
        width: root.showWeather ? Math.max(160, parent.width * 0.43) : parent.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.labelGap
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.timeText()
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Math.min(parent.width * 0.26, root.height * 0.24)
          font.weight: Font.DemiBold
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.secondaryText("ddd, MMM d")
          color: root.timerStatus !== "idle" ? Color.accent : Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      WeatherModule {
        enabled: root.showWeather
        width: Math.max(0, parent.width - x)
        height: parent.height
        weatherController: root.weather
        visualStyle: root.weatherStyle
        detailMode: root.weatherDetail
        temperatureUnit: root.temperatureUnit
      }
    }
  }

  Component {
    id: compactClock
    Column {
      anchors.centerIn: parent
      width: parent.width
      spacing: Style.spacing.controlGap

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        height: Math.max(56, Style.space(56))
        spacing: Style.spacing.panelGap
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.timeText()
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Math.min(root.width * 0.13, Style.font.displayLarge * 1.35)
          font.weight: Font.DemiBold
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.secondaryText("ddd, MMM d")
          color: root.timerStatus !== "idle" ? Color.accent : Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      WeatherModule {
        enabled: root.showWeather
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, Style.space(430))
        height: Math.max(64, Style.space(70))
        weatherController: root.weather
        visualStyle: root.weatherStyle === "scene" ? "minimal" : root.weatherStyle
        detailMode: root.weatherDetail
        temperatureUnit: root.temperatureUnit
      }
    }
  }

}
