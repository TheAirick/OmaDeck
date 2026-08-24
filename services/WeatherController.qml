import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property string pluginDir: ""
  readonly property string locationPath: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
  property bool loading: false
  property string error: ""
  property var current: ({ ok: false })
  property date updatedAt: new Date(0)
  property string locationState: ""

  function refresh() {
    if (!weatherProcess.running && pluginDir !== "") {
      loading = true
      weatherProcess.running = true
    }
  }

  function observeLocation(raw) {
    var next = String(raw || "")
    if (next === locationState) return
    locationState = next
    refreshDelay.restart()
  }

  function normalizeCode(code) {
    var value = Number(code)
    // Open-Meteo WMO interpretation codes.
    if (value === 0) return "clear"
    if (value === 1 || value === 2) return "partly-cloudy"
    if (value === 3) return "cloudy"
    if (value === 45 || value === 48) return "fog"
    if ([51, 53, 55, 56, 57].indexOf(value) !== -1) return "drizzle"
    if ([61, 63, 65, 66, 67, 80, 81, 82].indexOf(value) !== -1) return "rain"
    if ([71, 73, 75, 77, 85, 86].indexOf(value) !== -1) return "snow"
    if (value === 96 || value === 99) return "hail"
    if (value === 95) return "thunderstorm"
    // wttr.in codes used only by the offline/provider fallback path.
    if ([113].indexOf(value) !== -1) return "clear"
    if ([116].indexOf(value) !== -1) return "partly-cloudy"
    if ([119, 122].indexOf(value) !== -1) return "cloudy"
    if ([143, 248, 260].indexOf(value) !== -1) return "fog"
    if ([176, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 353, 356, 359].indexOf(value) !== -1) return "rain"
    if ([179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(value) !== -1) return "snow"
    if ([350, 362, 365, 374, 377].indexOf(value) !== -1) return "hail"
    if ([200, 386, 389, 392, 395].indexOf(value) !== -1) return value === 395 ? "hail" : "thunderstorm"
    return "cloudy"
  }

  function conditionLabel(condition) {
    return ({
      "clear": "Clear",
      "partly-cloudy": "Partly cloudy",
      "cloudy": "Cloudy",
      "fog": "Foggy",
      "drizzle": "Drizzle",
      "rain": "Rain",
      "snow": "Snow",
      "hail": "Hail",
      "thunderstorm": "Thunderstorms"
    })[condition] || "Weather"
  }

  function temperature(value, unit) {
    var celsius = Number(value)
    if (isNaN(celsius)) return "—"
    return Math.round(unit === "celsius" ? celsius : (celsius * 9 / 5 + 32)) + "°"
  }

  function wind(value, unit) {
    var kph = Number(value)
    if (isNaN(kph)) return "—"
    return unit === "celsius" ? Math.round(kph) + " km/h" : Math.round(kph * 0.621371) + " mph"
  }

  Process {
    id: weatherProcess
    command: [root.pluginDir + "/scripts/weather-json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var next = JSON.parse(text)
          if (!next.ok) throw new Error(next.error || "weather unavailable")
          next.condition = root.normalizeCode(next.code)
          next.conditionLabel = root.conditionLabel(next.condition)
          var forecast = next.forecast || []
          for (var i = 0; i < forecast.length; i++) {
            forecast[i].condition = root.normalizeCode(forecast[i].code)
            forecast[i].conditionLabel = root.conditionLabel(forecast[i].condition)
          }
          next.forecast = forecast
          root.current = next
          root.error = ""
          root.updatedAt = new Date()
        } catch (exception) {
          root.error = "Weather unavailable"
          console.warn("OmaDeck weather:", exception)
        }
      }
    }
    onExited: root.loading = false
  }

  FileView {
    id: locationFile
    path: root.locationPath
    watchChanges: true
    printErrors: false
    onLoaded: root.observeLocation(text())
    onLoadFailed: {
      if (root.locationState === "") return
      root.locationState = ""
      refreshDelay.restart()
    }
    onFileChanged: reload()
  }

  Timer { id: refreshDelay; interval: 300; repeat: false; onTriggered: root.refresh() }

  // FileView cannot watch a location file that did not exist at startup. A
  // cheap periodic reload detects its first creation without polling weather.
  Timer {
    interval: 10 * 1000
    running: true
    repeat: true
    onTriggered: locationFile.reload()
  }

  // Transient provider failures recover promptly instead of waiting for the
  // normal 15-minute forecast interval.
  Timer {
    interval: 60 * 1000
    running: root.error !== ""
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 15 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
