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
  property bool lastSaveSucceeded: false
  property string lastSaveError: ""
  property string confirmedText: ""

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

  function restoreSnapshot(state) {
    clockStyle = state.clockStyle
    use24Hour = state.use24Hour
    showSeconds = state.showSeconds
    showWeather = state.showWeather
    weatherStyle = state.weatherStyle
    weatherDetail = state.weatherDetail
    temperatureUnit = state.temperatureUnit
  }

  function setOption(key, value) {
    if (!directoryReady) return false
    var before = snapshot()
    saveDelay.stop()
    if (key === "clockStyle") clockStyle = oneOf(value, ["hero", "split", "compact"], clockStyle)
    else if (key === "use24Hour") use24Hour = value === true
    else if (key === "showSeconds") showSeconds = value === true
    else if (key === "showWeather") showWeather = value === true
    else if (key === "weatherStyle") weatherStyle = oneOf(value, ["scene", "glyph", "minimal"], weatherStyle)
    else if (key === "weatherDetail") weatherDetail = oneOf(value, ["compact", "standard", "full"], weatherDetail)
    else if (key === "temperatureUnit") temperatureUnit = oneOf(value, ["fahrenheit", "celsius"], temperatureUnit)
    else return false

    var saved = persist()
    if (!saved) restoreSnapshot(before)
    return saved
  }

  function scheduleSave() {
    if (directoryReady) saveDelay.restart()
  }

  function persist() {
    if (!directoryReady) return false
    var serialized = JSON.stringify(snapshot(), null, 2) + "\n"
    // FileView skips identical writes without emitting saved. Only acknowledge
    // a no-op when these exact bytes were read from disk or saved successfully.
    if (serialized === confirmedText) {
      lastSaveSucceeded = true
      lastSaveError = ""
      return true
    }
    lastSaveSucceeded = false
    lastSaveError = ""
    try {
      settingsFile.setText(serialized)
      if (lastSaveSucceeded) confirmedText = serialized
    } catch (error) {
      console.warn("OmaDeck: failed to persist appearance settings:", error)
      lastSaveError = String(error)
    }
    return lastSaveSucceeded
  }

  Process {
    id: mkdirProcess
    command: ["/usr/bin/mkdir", "-p", root.configDir]
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
    blockWrites: true
    printErrors: false
    onSaved: root.lastSaveSucceeded = true
    onSaveFailed: function(error) {
      root.confirmedText = ""
      root.lastSaveSucceeded = false
      root.lastSaveError = String(error)
    }
    onLoaded: {
      root.confirmedText = text()
      root.load(root.confirmedText)
    }
    onLoadFailed: {
      root.confirmedText = ""
      if (!root.directoryReady) return
      root.loaded = true
      root.persist()
    }
    onFileChanged: reload()
  }

  Timer { id: saveDelay; interval: 180; repeat: false; onTriggered: root.persist() }

  Component.onCompleted: mkdirProcess.running = true
}
