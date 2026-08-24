import QtQuick
import qs.Commons

Item {
  id: root

  property var weather: null
  property string visualStyle: "scene"
  property string detailMode: "standard"
  property string temperatureUnit: "fahrenheit"
  property bool loading: false
  property string error: ""

  readonly property bool available: weather && weather.ok
  readonly property string condition: available ? String(weather.condition || "cloudy") : "cloudy"
  readonly property bool isDay: !available || weather.isDay !== false
  readonly property string unitLetter: temperatureUnit === "celsius" ? "C" : "F"
  readonly property var forecastDays: {
    var days = available && weather.forecast ? weather.forecast : []
    return days.slice(0, detailMode === "full" ? 3 : 2)
  }

  function glyphFor(conditionName, day) {
    var name = String(conditionName || "cloudy")
    if (name === "clear") return day === false ? "" : ""
    if (name === "partly-cloudy") return day === false ? "" : ""
    if (name === "cloudy") return ""
    if (name === "fog") return day === false ? "" : ""
    if (name === "drizzle") return day === false ? "" : ""
    if (name === "rain") return ""
    if (name === "snow") return ""
    if (name === "hail") return ""
    if (name === "thunderstorm") return ""
    return ""
  }

  function tempNumber(value) {
    var celsius = Number(value)
    if (value === undefined || value === null || isNaN(celsius)) return "—"
    return String(Math.round(temperatureUnit === "celsius" ? celsius : (celsius * 9 / 5 + 32)))
  }

  function temp(value, includeUnit) {
    var valueText = tempNumber(value)
    return valueText === "—" ? valueText : valueText + "°" + (includeUnit ? unitLetter : "")
  }

  function wind(value) {
    var kph = Number(value)
    if (value === undefined || value === null || isNaN(kph)) return "—"
    return temperatureUnit === "celsius" ? Math.round(kph) + " km/h" : Math.round(kph * 0.621371) + " mph"
  }

  function dayName(dateText) {
    var date = new Date(String(dateText || "") + "T12:00:00")
    return isNaN(date.getTime()) ? "DAY" : Qt.formatDate(date, "ddd").toUpperCase()
  }

  Text {
    visible: !root.available
    anchors.centerIn: parent
    text: root.loading ? "󰔟  Updating weather…" : "󰖪  Weather unavailable"
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Loader {
    anchors.fill: parent
    visible: root.available
    sourceComponent: root.visualStyle === "minimal" ? minimalWeather
      : root.visualStyle === "glyph" ? glyphWeather : detailedWeather
  }

  Component {
    id: detailedWeather

    Column {
      anchors.centerIn: parent
      width: parent.width
      spacing: Style.spacing.controlGap

      Row {
        id: currentRow
        width: parent.width
        height: root.detailMode === "compact" ? Math.max(Style.space(76), root.height * 0.48)
          : Math.max(Style.space(60), root.height * 0.32)
        spacing: Style.spacing.panelGap

        Row {
          id: hero
          width: root.detailMode === "compact" ? parent.width : Math.min(parent.width * 0.48, Style.space(245))
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.controlGap

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: Style.space(3)
            text: root.glyphFor(root.condition, root.isDay)
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Math.min(currentRow.height * 0.72, Style.space(66))
          }

          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              id: heroTemperature
              text: root.tempNumber(root.weather.temperatureC)
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Math.min(currentRow.height * 0.68, Style.space(58))
              font.bold: true
            }
            Text {
              text: "°" + root.unitLetter
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.display
              anchors.top: heroTemperature.top
              anchors.topMargin: Style.space(7)
            }
          }
        }

        Row {
          visible: root.detailMode !== "compact"
          width: Math.max(0, parent.width - x)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Math.max(Style.spacing.controlGap, (width - feelsMetric.width - windMetric.width - humidMetric.width) / 2)

          WeatherMetric {
            id: feelsMetric
            label: "FEELS"
            value: root.temp(root.weather.feelsLikeC, true)
          }
          WeatherMetric {
            id: windMetric
            label: "WIND"
            value: root.wind(root.weather.windKph)
          }
          WeatherMetric {
            id: humidMetric
            label: "HUMID"
            value: Math.round(Number(root.weather.humidity || 0)) + "%"
          }
        }
      }

      Row {
        visible: root.detailMode !== "compact"
        width: parent.width
        height: Style.space(26)
        spacing: Style.spacing.controlGap

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: ""
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, parent.width - x - highLow.width - Style.spacing.controlGap)
          text: String(root.weather.location || "Current location").toUpperCase()
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.letterSpacing: 0.8
          elide: Text.ElideRight
        }
        Text {
          id: highLow
          anchors.verticalCenter: parent.verticalCenter
          text: "H " + root.temp(root.weather.highC, false) + "   L " + root.temp(root.weather.lowC, false)
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Rectangle {
        visible: root.detailMode !== "compact" && root.forecastDays.length > 0
        width: parent.width
        height: 1
        color: Color.foreground
        opacity: 0.12
      }

      Row {
        visible: root.detailMode !== "compact" && root.forecastDays.length > 0
        width: parent.width
        height: Style.space(44)
        spacing: Style.spacing.controlGap

        Repeater {
          model: root.forecastDays

          Item {
            required property var modelData
            width: (parent.width - Math.max(0, (root.forecastDays.length - 1)) * parent.spacing) / Math.max(1, root.forecastDays.length)
            height: parent.height

            Row {
              anchors.centerIn: parent
              spacing: Style.spacing.labelGap

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.glyphFor(modelData.condition, true)
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.display
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)
                Text {
                  text: root.dayName(modelData.date)
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.8
                }
                Text {
                  text: root.temp(modelData.highC, false) + "  " + root.temp(modelData.lowC, false)
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: glyphWeather

    Row {
      anchors.centerIn: parent
      spacing: Style.spacing.panelGap

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyphFor(root.condition, root.isDay)
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Math.min(root.height * 0.58, Style.space(76))
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.labelGap
        Text {
          text: root.temp(root.weather.temperatureC, true)
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.displayLarge
          font.bold: true
        }
        Text {
          text: root.weather.conditionLabel + (root.detailMode === "compact" ? "" : "  ·  " + root.weather.location)
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
        Text {
          visible: root.detailMode === "full"
          text: "Feels " + root.temp(root.weather.feelsLikeC, true) + "  ·  " + root.wind(root.weather.windKph) + "  ·  " + Math.round(Number(root.weather.humidity || 0)) + "% humidity"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  Component {
    id: minimalWeather

    Row {
      anchors.centerIn: parent
      spacing: Style.spacing.controlGap

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyphFor(root.condition, root.isDay)
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.displayLarge
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.temp(root.weather.temperatureC, true)
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.weather.conditionLabel
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Text {
        visible: root.detailMode !== "compact"
        anchors.verticalCenter: parent.verticalCenter
        text: "H " + root.temp(root.weather.highC, false) + "  L " + root.temp(root.weather.lowC, false)
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  component WeatherMetric: Column {
    required property string label
    required property string value
    spacing: Style.space(3)

    Text {
      text: parent.label
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 0.8
    }
    Text {
      text: parent.value
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }
}
