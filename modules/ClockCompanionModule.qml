import QtQuick
import qs.Commons
import "ClockCompanionPolicy.js" as ClockCompanionPolicy

Item {
  id: root

  property var controller: null
  property var weather: null
  property var timer: null

  readonly property bool showWeather: controller ? controller.showWeather : true
  readonly property string weatherStyle: controller ? controller.weatherStyle : "scene"
  readonly property string weatherDetail: controller ? controller.weatherDetail : "standard"
  readonly property string temperatureUnit: controller ? controller.temperatureUnit : "fahrenheit"
  readonly property string timerStatus: timer ? timer.status : "idle"
  readonly property bool timerSetupOpen: timerPresenter.setupOpen
  readonly property bool timerPanelOpen: timerPresenter.open
  readonly property string occupant: ClockCompanionPolicy.occupant(root.timerPanelOpen)

  clip: true

  function openTimer() { timerPresenter.openForCurrentStatus() }

  Item {
    id: companionSlot
    objectName: "companionSlot"
    anchors.fill: parent
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
      visible: root.timerPanelOpen
      timer: root.timer
      companionMode: true
    }
  }
}
