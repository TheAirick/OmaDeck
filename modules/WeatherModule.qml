import QtQuick
import "../components"

Item {
  id: root

  property var weatherController: null
  property string visualStyle: "scene"
  property string detailMode: "standard"
  property string temperatureUnit: "fahrenheit"
  readonly property var current: weatherController ? weatherController.current : null
  readonly property bool loading: weatherController ? weatherController.loading : false
  readonly property string error: weatherController ? weatherController.error : ""

  visible: root.enabled
  clip: true

  WeatherVisual {
    anchors.fill: parent
    weather: root.current
    loading: root.loading
    error: root.error
    visualStyle: root.visualStyle
    detailMode: root.detailMode
    temperatureUnit: root.temperatureUnit
  }
}
