import QtQuick
import qs.Commons

Item {
  id: root

  property var weather: null
  property var forecastDays: []
  property var glyphFor: null
  property var tempNumber: null
  property var temp: null
  property var wind: null
  property var dayName: null
  property string unitLetter: "F"

  readonly property var safeWeather: weather || ({})
  readonly property real contentScale: Math.min(1,
    width / Math.max(1, nativeContent.width),
    height / Math.max(1, nativeContent.height))

  Item {
    id: nativeContent
    objectName: "omarchyWeatherNativeContent"
    anchors.centerIn: parent
    width: Math.max(Style.space(480), forecastRow.implicitWidth,
      Style.space(16) + heroLeft.implicitWidth + Style.space(24)
        + heroRight.implicitWidth + Style.space(20))
    height: weatherColumn.implicitHeight
    scale: root.contentScale
    transformOrigin: Item.Center

    Column {
      id: weatherColumn
      objectName: "omarchyWeatherColumn"
      width: parent.width
      spacing: Style.space(14)

      Item {
        id: weatherHero
        objectName: "omarchyWeatherHero"
        width: parent.width
        height: Math.max(heroLeft.height, heroRight.height)

        Row {
          id: heroLeft
          objectName: "omarchyWeatherHeroLeft"
          anchors.left: parent.left
          anchors.leftMargin: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(16)

          Text {
            id: heroIcon
            objectName: "omarchyWeatherHeroIcon"
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: Style.space(5)
            text: root.glyphFor ? root.glyphFor(root.safeWeather.condition, root.safeWeather.isDay) : "—"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: 64
          }

          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              id: heroTemperature
              objectName: "omarchyWeatherHeroTemperature"
              text: root.tempNumber ? root.tempNumber(root.safeWeather.temperatureC) : "—"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: 56
              font.bold: true
            }
            Text {
              text: "°" + root.unitLetter
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.display
              anchors.top: heroTemperature.top
              anchors.topMargin: Style.space(10)
            }
          }
        }

        Column {
          id: heroRight
          objectName: "omarchyWeatherHeroRight"
          width: weatherStats.implicitWidth
          anchors.right: parent.right
          anchors.rightMargin: Style.space(20)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(12)

          Row {
            width: parent.width
            spacing: Style.space(6)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: ""
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.max(0, parent.width - x)
              text: String(root.safeWeather.location || "Current location").toUpperCase()
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.letterSpacing: 1
              elide: Text.ElideRight
            }
          }

          Row {
            id: weatherStats
            objectName: "omarchyWeatherStats"
            spacing: Style.space(36)

            WeatherMetric {
              label: "FEELS"
              value: root.temp ? root.temp(root.safeWeather.feelsLikeC, true) : "—"
            }
            WeatherMetric {
              label: "WIND"
              value: root.wind ? root.wind(root.safeWeather.windKph) : "—"
            }
            WeatherMetric {
              label: "HUMID"
              value: Math.round(Number(root.safeWeather.humidity || 0)) + "%"
            }
          }
        }
      }

      Rectangle {
        objectName: "omarchyWeatherDivider"
        visible: root.forecastDays.length > 0
        width: parent.width
        height: Style.spacing.hairline
        color: Color.foreground
        opacity: 0.12
      }

      Item {
        objectName: "omarchyWeatherForecast"
        visible: root.forecastDays.length > 0
        width: parent.width
        height: forecastRow.height

        Row {
          id: forecastRow
          objectName: "omarchyWeatherForecastRow"
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(44)

          Repeater {
            model: root.forecastDays

            Row {
              id: forecastCell
              objectName: "omarchyWeatherForecastCell"
              required property var modelData
              spacing: Style.space(10)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.glyphFor ? root.glyphFor(forecastCell.modelData.condition, true) : "—"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.display
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)
                Text {
                  text: root.dayName ? root.dayName(forecastCell.modelData.date).toUpperCase() : "DAY"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1
                }
                Row {
                  spacing: Style.space(6)
                  Text {
                    text: root.temp ? root.temp(forecastCell.modelData.highC, false) : "—"
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    text: root.temp ? root.temp(forecastCell.modelData.lowC, false) : "—"
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  component WeatherMetric: Column {
    required property string label
    required property string value
    spacing: Style.space(5)

    Text {
      text: parent.label
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 1
    }
    Text {
      text: parent.value
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
    }
  }
}
