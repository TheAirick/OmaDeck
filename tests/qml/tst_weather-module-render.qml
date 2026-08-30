import QtQuick
import QtTest
import "../../components" as Components
import "../../modules" as Modules

TestCase {
  id: testCase
  name: "WeatherModuleRenderParity"
  when: windowShown

  width: 1900
  height: 900
  visible: true

  Component {
    id: acceptedBaseline

    Item {
      property var weatherController: null
      property string visualStyle: "scene"
      property string detailMode: "standard"
      property string temperatureUnit: "fahrenheit"

      visible: enabled
      clip: true

      Components.WeatherVisual {
        anchors.fill: parent
        weather: parent.weatherController ? parent.weatherController.current : null
        loading: parent.weatherController ? parent.weatherController.loading : false
        error: parent.weatherController ? parent.weatherController.error : ""
        visualStyle: parent.visualStyle
        detailMode: parent.detailMode
        temperatureUnit: parent.temperatureUnit
      }
    }
  }

  function currentWeather() {
    return {
      ok: true,
      condition: "partly-cloudy",
      conditionLabel: "Partly cloudy",
      isDay: true,
      temperatureC: 21.4,
      feelsLikeC: 20.8,
      windKph: 17.2,
      humidity: 62,
      location: "Fixture City",
      highC: 24.1,
      lowC: 13.9,
      forecast: [
        { date: "2026-08-31", condition: "rain", highC: 19.2, lowC: 12.4 },
        { date: "2026-09-01", condition: "clear", highC: 22.7, lowC: 11.8 },
        { date: "2026-09-02", condition: "cloudy", highC: 20.3, lowC: 10.9 }
      ]
    }
  }

  function controllerFor(state) {
    if (state === "loading") return { current: { ok: false }, loading: true, error: "" }
    if (state === "unavailable") return { current: { ok: false }, loading: false, error: "Fixture failure" }
    return { current: currentWeather(), loading: false, error: "" }
  }

  function geometryFor(clockStyle) {
    if (clockStyle === "hero") return { width: 800, height: 240 }
    if (clockStyle === "split") return { width: 440, height: 400 }
    return { width: 430, height: 70 }
  }

  function effectiveStyle(clockStyle, requestedStyle) {
    return clockStyle === "compact" && requestedStyle === "scene"
      ? "minimal"
      : requestedStyle
  }

  function contractRows() {
    var rows = []
    var clockStyles = ["hero", "split", "compact"]
    var weatherStates = ["loading", "unavailable", "current", "disabled"]
    var visualStyles = ["scene", "glyph", "minimal"]
    var detailModes = ["compact", "standard", "full"]
    var temperatureUnits = ["fahrenheit", "celsius"]

    for (var clockIndex = 0; clockIndex < clockStyles.length; clockIndex++) {
      for (var stateIndex = 0; stateIndex < weatherStates.length; stateIndex++) {
        for (var styleIndex = 0; styleIndex < visualStyles.length; styleIndex++) {
          for (var detailIndex = 0; detailIndex < detailModes.length; detailIndex++) {
            for (var unitIndex = 0; unitIndex < temperatureUnits.length; unitIndex++) {
              var clockStyle = clockStyles[clockIndex]
              var state = weatherStates[stateIndex]
              var requestedStyle = visualStyles[styleIndex]
              var detailMode = detailModes[detailIndex]
              var temperatureUnit = temperatureUnits[unitIndex]
              rows.push({
                tag: [clockStyle, state, requestedStyle, detailMode, temperatureUnit].join("-"),
                clockStyle: clockStyle,
                state: state,
                visualStyle: effectiveStyle(clockStyle, requestedStyle),
                detailMode: detailMode,
                temperatureUnit: temperatureUnit
              })
            }
          }
        }
      }
    }
    return rows
  }

  function objectsFor(data) {
    var geometry = geometryFor(data.clockStyle)
    var properties = {
      width: geometry.width,
      height: geometry.height,
      enabled: data.state !== "disabled",
      weatherController: controllerFor(data.state),
      visualStyle: data.visualStyle,
      detailMode: data.detailMode,
      temperatureUnit: data.temperatureUnit
    }
    var before = createTemporaryObject(acceptedBaseline, testCase, properties)
    var after = createTemporaryObject(weatherModuleComponent, testCase, properties)
    verify(before !== null)
    verify(after !== null)
    return { before: before, after: after }
  }

  function test_contract_data() {
    return contractRows()
  }

  function test_contract(data) {
    var objects = objectsFor(data)
    var before = objects.before
    var after = objects.after
    compare(after.width, before.width)
    compare(after.height, before.height)
    compare(after.visible, before.visible)

    var beforeVisual = before.children[0]
    var afterVisual = after.children[0]
    verify(beforeVisual !== null)
    verify(afterVisual !== null)
    compare(afterVisual.loading, beforeVisual.loading)
    compare(afterVisual.error, beforeVisual.error)
    compare(afterVisual.visualStyle, beforeVisual.visualStyle)
    compare(afterVisual.detailMode, beforeVisual.detailMode)
    compare(afterVisual.temperatureUnit, beforeVisual.temperatureUnit)
    compare(afterVisual.available, beforeVisual.available)
    compare(afterVisual.effectiveDetail, beforeVisual.effectiveDetail)
    compare(JSON.stringify(afterVisual.weather), JSON.stringify(beforeVisual.weather))
  }

  function test_renderParity_data() {
    var rows = contractRows()
    return rows.filter(function(row) {
      if (row.state === "disabled") return false
      if (row.state === "current") return true
      return row.visualStyle === "scene"
        && row.detailMode === "standard"
        && row.temperatureUnit === "fahrenheit"
    })
  }

  function test_renderParity(data) {
    var objects = objectsFor(data)
    var before = objects.before
    var after = objects.after

    wait(1)
    verify(grabImage(after).equals(grabImage(before)), data.tag)
  }

  Component {
    id: weatherModuleComponent
    Modules.WeatherModule {}
  }
}
