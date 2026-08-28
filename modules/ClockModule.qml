import QtQuick
import qs.Commons
import "../components"

Item {
  id: root

  clip: true

  property var controller: null
  property var weather: null
  property date now: new Date()

  readonly property string clockStyle: controller ? controller.clockStyle : "hero"
  readonly property bool use24Hour: controller ? controller.use24Hour : false
  readonly property bool showSeconds: controller ? controller.showSeconds : false
  readonly property bool showWeather: controller ? controller.showWeather : true
  readonly property string weatherStyle: controller ? controller.weatherStyle : "scene"
  readonly property string weatherDetail: controller ? controller.weatherDetail : "standard"
  readonly property string temperatureUnit: controller ? controller.temperatureUnit : "fahrenheit"

  function timeText() {
    var pattern = use24Hour ? (showSeconds ? "HH:mm:ss" : "HH:mm") : (showSeconds ? "h:mm:ss AP" : "h:mm AP")
    return Qt.formatDateTime(now, pattern)
  }

  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

  Loader {
    anchors.fill: parent
    sourceComponent: root.clockStyle === "split" ? splitClock : root.clockStyle === "compact" ? compactClock : heroClock
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
            text: Qt.formatDateTime(root.now, "dddd, MMMM d")
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }
      }

      WeatherVisual {
        visible: root.showWeather
        width: parent.width
        height: Math.max(0, parent.height - y)
        weather: root.weather ? root.weather.current : null
        loading: root.weather ? root.weather.loading : false
        error: root.weather ? root.weather.error : ""
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
          text: Qt.formatDateTime(root.now, "ddd, MMM d")
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      WeatherVisual {
        visible: root.showWeather
        width: Math.max(0, parent.width - x)
        height: parent.height
        weather: root.weather ? root.weather.current : null
        loading: root.weather ? root.weather.loading : false
        error: root.weather ? root.weather.error : ""
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
          text: Qt.formatDateTime(root.now, "ddd, MMM d")
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      WeatherVisual {
        visible: root.showWeather
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, Style.space(430))
        height: Math.max(64, Style.space(70))
        weather: root.weather ? root.weather.current : null
        loading: root.weather ? root.weather.loading : false
        error: root.weather ? root.weather.error : ""
        visualStyle: root.weatherStyle === "scene" ? "minimal" : root.weatherStyle
        detailMode: root.weatherDetail
        temperatureUnit: root.temperatureUnit
      }
    }
  }

}
