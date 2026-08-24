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
  readonly property bool wet: ["drizzle", "rain", "thunderstorm", "hail"].indexOf(condition) !== -1
  readonly property bool frozen: ["snow", "hail"].indexOf(condition) !== -1
  readonly property bool cloudy: ["partly-cloudy", "cloudy", "fog", "drizzle", "rain", "snow", "hail", "thunderstorm"].indexOf(condition) !== -1

  function glyph() {
    if (!available) return loading ? "󰔟" : "󰖪"
    if (condition === "clear") return isDay ? "" : ""
    if (condition === "partly-cloudy") return isDay ? "" : ""
    if (condition === "cloudy") return ""
    if (condition === "fog") return ""
    if (condition === "drizzle") return ""
    if (condition === "rain") return ""
    if (condition === "snow") return ""
    if (condition === "hail") return ""
    if (condition === "thunderstorm") return ""
    return "󰖐"
  }

  function temp(value) {
    if (!available || value === undefined || value === null) return "—"
    var celsius = Number(value)
    return Math.round(temperatureUnit === "celsius" ? celsius : (celsius * 9 / 5 + 32)) + "°"
  }

  function wind(value) {
    var kph = Number(value)
    if (isNaN(kph)) return "—"
    return temperatureUnit === "celsius" ? Math.round(kph) + " km/h" : Math.round(kph * 0.621371) + " mph"
  }

  Item {
    id: scene
    visible: root.visualStyle === "scene" && root.available
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Math.min(parent.width * 0.42, parent.height * 1.15)
    clip: true

    Rectangle {
      visible: root.condition === "clear" || root.condition === "partly-cloudy"
      width: Math.min(scene.width, scene.height) * 0.42
      height: width
      radius: width / 2
      x: scene.width * 0.16
      y: scene.height * 0.16
      color: Color.accent
      opacity: 0.9
      SequentialAnimation on opacity {
        running: parent.visible
        loops: Animation.Infinite
        NumberAnimation { to: 0.62; duration: 1800; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.9; duration: 1800; easing.type: Easing.InOutSine }
      }
    }

    Item {
      visible: root.cloudy
      width: scene.width * 0.72
      height: scene.height * 0.46
      x: scene.width * 0.14
      y: scene.height * 0.30

      Rectangle { x: parent.width * 0.05; y: parent.height * 0.44; width: parent.width * 0.9; height: parent.height * 0.42; radius: height / 2; color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.82) }
      Rectangle { x: parent.width * 0.18; y: parent.height * 0.17; width: parent.height * 0.62; height: width; radius: width / 2; color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.82) }
      Rectangle { x: parent.width * 0.48; y: 0; width: parent.height * 0.78; height: width; radius: width / 2; color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.82) }
    }

    Repeater {
      model: root.wet && root.condition !== "hail" ? 5 : 0
      Rectangle {
        required property int index
        width: 3
        height: scene.height * 0.16
        radius: width / 2
        x: scene.width * (0.2 + index * 0.13)
        y: scene.height * 0.68
        rotation: 12
        color: root.condition === "thunderstorm" ? Color.accent : Qt.rgba(0.45, 0.72, 0.95, 0.92)
        SequentialAnimation on y {
          running: parent.visible
          loops: Animation.Infinite
          PauseAnimation { duration: index * 100 }
          NumberAnimation { from: scene.height * 0.64; to: scene.height * 0.98; duration: 650; easing.type: Easing.InQuad }
        }
      }
    }

    Repeater {
      model: root.frozen ? 7 : 0
      Text {
        required property int index
        text: root.condition === "hail" ? "●" : "✦"
        color: root.condition === "hail" ? Qt.rgba(0.70, 0.85, 0.98, 1) : Color.foreground
        font.pixelSize: Math.max(8, scene.height * 0.1)
        x: scene.width * (0.12 + (index % 5) * 0.17)
        SequentialAnimation on y {
          running: parent.visible
          loops: Animation.Infinite
          PauseAnimation { duration: index * 120 }
          NumberAnimation { from: scene.height * 0.54; to: scene.height; duration: 1100 + index * 40; easing.type: Easing.Linear }
        }
      }
    }

    Text {
      visible: root.condition === "thunderstorm"
      anchors.centerIn: parent
      anchors.verticalCenterOffset: scene.height * 0.18
      text: "ϟ"
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: Math.max(18, scene.height * 0.28)
      font.bold: true
    }
  }

  Row {
    anchors.left: root.visualStyle === "scene" && root.available ? scene.right : parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: root.visualStyle === "scene" && root.available ? Style.spacing.controlGap : 0
    anchors.rightMargin: root.visualStyle === "scene" ? Style.spacing.panelGap : 0
    spacing: Style.spacing.controlGap

    Text {
      visible: root.visualStyle !== "scene" || !root.available
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph()
      color: root.available ? Color.accent : Color.muted
      font.family: Style.font.family
      font.pixelSize: root.visualStyle === "glyph" ? Math.min(root.height * 0.45, Style.font.displayLarge * 1.8) : Style.font.displayLarge
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - x
      spacing: Style.spacing.labelGap

      Row {
        width: parent.width
        spacing: Style.spacing.controlGap
        Text {
          id: temperatureLabel
          text: root.available ? root.temp(root.weather.temperatureC) : (root.loading ? "Updating…" : "Weather unavailable")
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: !root.available ? Style.font.subtitle
            : root.visualStyle === "minimal" ? Style.font.subtitle : Style.font.displayLarge
          font.weight: Font.DemiBold
        }
        Text {
          visible: root.available && root.detailMode !== "compact"
          width: Math.max(0, parent.width - x)
          anchors.baseline: temperatureLabel.baseline
          text: root.weather.conditionLabel || "Weather"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
      }

      Text {
        visible: root.available
        width: parent.width
        text: root.detailMode === "compact" ? (root.weather.conditionLabel || "Weather")
          : root.detailMode === "full"
            ? root.weather.location + "  ·  Feels " + root.temp(root.weather.feelsLikeC) + "  ·  Wind " + root.wind(root.weather.windKph) + "  ·  Humidity " + Math.round(Number(root.weather.humidity || 0)) + "%"
            : root.weather.location + "  ·  H " + root.temp(root.weather.highC) + "  L " + root.temp(root.weather.lowC)
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }
}
