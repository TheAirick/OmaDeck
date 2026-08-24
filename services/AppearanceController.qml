import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string configDir: Quickshell.env("HOME") + "/.config/omadeck"
  readonly property string settingsPath: configDir + "/appearance.json"

  property string clockStyle: "hero"
  property bool use24Hour: false
  property bool showSeconds: false
  property bool showWeather: true
  property string weatherStyle: "scene"
  property string weatherDetail: "standard"
  property string temperatureUnit: "fahrenheit"
  property bool loaded: false
  property bool directoryReady: false

  function oneOf(value, choices, fallback) {
    return choices.indexOf(String(value || "")) !== -1 ? String(value) : fallback
  }

  function load(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (!parsed || parsed.version !== 1) throw new Error("unsupported appearance settings")
      clockStyle = oneOf(parsed.clockStyle, ["hero", "split", "compact"], "hero")
      use24Hour = parsed.use24Hour === true
      showSeconds = parsed.showSeconds === true
      showWeather = parsed.showWeather !== false
      weatherStyle = oneOf(parsed.weatherStyle, ["scene", "glyph", "minimal"], "scene")
      weatherDetail = oneOf(parsed.weatherDetail, ["compact", "standard", "full"], "standard")
      temperatureUnit = oneOf(parsed.temperatureUnit, ["fahrenheit", "celsius"], "fahrenheit")
      loaded = true
    } catch (error) {
      console.warn("OmaDeck: invalid appearance settings, using defaults:", error)
      loaded = true
      scheduleSave()
    }
  }

  function snapshot() {
    return {
      version: 1,
      clockStyle: clockStyle,
      use24Hour: use24Hour,
      showSeconds: showSeconds,
      showWeather: showWeather,
      weatherStyle: weatherStyle,
      weatherDetail: weatherDetail,
      temperatureUnit: temperatureUnit
    }
  }

  function setOption(key, value) {
    if (key === "clockStyle") clockStyle = oneOf(value, ["hero", "split", "compact"], clockStyle)
    else if (key === "use24Hour") use24Hour = value === true
    else if (key === "showSeconds") showSeconds = value === true
    else if (key === "showWeather") showWeather = value === true
    else if (key === "weatherStyle") weatherStyle = oneOf(value, ["scene", "glyph", "minimal"], weatherStyle)
    else if (key === "weatherDetail") weatherDetail = oneOf(value, ["compact", "standard", "full"], weatherDetail)
    else if (key === "temperatureUnit") temperatureUnit = oneOf(value, ["fahrenheit", "celsius"], temperatureUnit)
    else return
    scheduleSave()
  }

  function scheduleSave() {
    if (directoryReady) saveDelay.restart()
  }

  function persist() {
    if (directoryReady) settingsFile.setText(JSON.stringify(snapshot(), null, 2) + "\n")
  }

  Process {
    id: mkdirProcess
    command: ["mkdir", "-p", root.configDir]
    onExited: {
      root.directoryReady = true
      settingsFile.reload()
    }
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: {
      if (!root.directoryReady) return
      root.loaded = true
      root.persist()
    }
    onFileChanged: reload()
  }

  Timer { id: saveDelay; interval: 180; repeat: false; onTriggered: root.persist() }

  Component.onCompleted: mkdirProcess.running = true
}
