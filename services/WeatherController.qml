import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "WeatherPolicy.js" as WeatherPolicy

Item {
  id: root

  property string pluginDir: ""
  property bool enabled: false
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") !== ""
                                      ? Quickshell.env("XDG_STATE_HOME")
                                      : Quickshell.env("HOME") + "/.local/state"
  readonly property string locationPath: Quickshell.env("OMADECK_WEATHER_LOCATION_FILE") !== ""
                                         ? Quickshell.env("OMADECK_WEATHER_LOCATION_FILE")
                                         : stateHome + "/omarchy/settings/weather.json"
  property bool loading: false
  property string error: ""
  property var current: ({ ok: false })
  property date updatedAt: new Date(0)
  property string locationState: ""
  property int generation: 0
  property bool refreshQueued: false
  property bool requestActive: false

  function refresh(trigger) {
    var source = String(trigger || "manual")
    if (!WeatherPolicy.canHandleTrigger(enabled, source, pluginDir)) return
    if (requestActive) {
      refreshQueued = true
      return
    }
    loading = true
    refreshQueued = false
    requestActive = true
    weatherProcess.requestGeneration = generation
    weatherProcess.launchStarted = false
    weatherOutput.reset()
    weatherProcess.running = true
  }

  function finishRequest(exitCode) {
    if (WeatherPolicy.acceptsResult(enabled, weatherProcess.requestGeneration, generation)) {
      try {
        if (exitCode !== 0 || weatherOutput.truncated)
          throw new Error("weather helper failed or exceeded its output limit")
        var next = JSON.parse(weatherOutput.text)
        if (!next.ok) throw new Error(next.error || "weather unavailable")
        next.condition = normalizeCode(next.code)
        next.conditionLabel = conditionLabel(next.condition)
        var forecast = next.forecast || []
        for (var i = 0; i < forecast.length; i++) {
          forecast[i].condition = normalizeCode(forecast[i].code)
          forecast[i].conditionLabel = conditionLabel(forecast[i].condition)
        }
        next.forecast = forecast
        current = next
        error = ""
        updatedAt = new Date()
      } catch (exception) {
        error = "Weather unavailable"
        console.warn("OmaDeck weather:", exception)
      }
    }
    loading = false
    requestActive = false
    if (enabled && refreshQueued) refresh("periodic")
  }

  function observeLocation(raw) {
    var next = String(raw || "")
    if (next === locationState) return
    if (locationState === "") {
      locationState = next
      return
    }
    locationState = next
    if (!enabled) return
    refreshDelay.restart()
  }

  function probeLocation() {
    if (!enabled || pluginDir === "" || locationProbe.running) return
    locationProbe.running = true
  }

  onEnabledChanged: {
    generation = WeatherPolicy.nextGeneration(generation)
    refreshQueued = false
    refreshDelay.stop()
    if (!enabled) {
      loading = false
      if (weatherProcess.running) {
        weatherProcess.running = false
        forceStopDelay.restart()
      }
      return
    }
    probeLocation()
    refresh("startup")
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
    command: [root.pluginDir + "/scripts/run-weather"]
    property int requestGeneration: -1
    property bool launchStarted: false
    // FailedToStart has no exited signal in Quickshell 0.3.1.
    onRunningChanged: {
      if (!running && !launchStarted && root.requestActive)
        root.finishRequest(-1)
    }
    stdout: BoundedOutputParser {
      id: weatherOutput
      maxBytes: 16 * 1024
    }
    onStarted: {
      launchStarted = true
      weatherOutput.reset()
      weatherLifecycleBackstop.restart()
    }
    onExited: function(exitCode) {
      weatherLifecycleBackstop.stop()
      forceStopDelay.stop()
      root.finishRequest(exitCode)
    }
  }

  // The external supervisor owns the strict ten-second deadline. This later
  // QML deadline protects the keep-loaded shell if the supervisor itself ever
  // fails; Process.running = false sends SIGTERM before escalation.
  Timer {
    id: weatherLifecycleBackstop
    interval: 12 * 1000
    repeat: false
    onTriggered: {
      if (!weatherProcess.running) return
      weatherProcess.running = false
      forceStopDelay.restart()
    }
  }

  Timer {
    id: forceStopDelay
    interval: 500
    repeat: false
    onTriggered: if (weatherProcess.running) weatherProcess.signal(9)
  }

  Process {
    id: locationProbe
    command: [root.pluginDir + "/scripts/weather-location", root.locationPath]
    stdout: BoundedOutputParser {
      id: locationOutput
      maxBytes: 2048
    }
    onStarted: locationOutput.reset()
    onExited: function(exitCode) {
      if (exitCode === 0 && !locationOutput.truncated)
        root.observeLocation(locationOutput.text)
    }
  }

  Timer { id: refreshDelay; interval: 300; repeat: false; onTriggered: root.refresh("location") }

  // Probe only a bounded fingerprint, so location changes never load an
  // arbitrary file into the long-running QML engine.
  Timer {
    interval: 10 * 1000
    running: root.enabled
    repeat: true
    onTriggered: root.probeLocation()
  }

  // Transient provider failures recover promptly instead of waiting for the
  // normal 15-minute forecast interval.
  Timer {
    interval: 60 * 1000
    running: root.enabled && root.error !== ""
    repeat: true
    onTriggered: root.refresh("retry")
  }

  Timer {
    interval: 15 * 60 * 1000
    running: root.enabled
    repeat: true
    onTriggered: root.refresh("periodic")
  }
}
