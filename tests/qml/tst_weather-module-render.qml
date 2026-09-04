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

  function collectByObjectName(item, objectName, result) {
    if (!item) return
    if (item.objectName === objectName) result.push(item)
    for (var index = 0; item.children && index < item.children.length; index++)
      collectByObjectName(item.children[index], objectName, result)
  }

  function rectIn(item, ancestor) {
    var origin = item.mapToItem(ancestor, 0, 0)
    var corner = item.mapToItem(ancestor, item.width, item.height)
    return {
      x: Math.min(origin.x, corner.x),
      y: Math.min(origin.y, corner.y),
      width: Math.abs(corner.x - origin.x),
      height: Math.abs(corner.y - origin.y)
    }
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

  function test_omarchyPanelGeometry() {
    var module = createTemporaryObject(weatherModuleComponent, testCase, {
      width: 430,
      height: 200,
      enabled: true,
      weatherController: controllerFor("current"),
      visualStyle: "scene",
      detailMode: "standard",
      temperatureUnit: "fahrenheit"
    })
    verify(module !== null)
    wait(1)

    var column = findChild(module, "omarchyWeatherColumn")
    var hero = findChild(module, "omarchyWeatherHero")
    var heroLeft = findChild(module, "omarchyWeatherHeroLeft")
    var heroRight = findChild(module, "omarchyWeatherHeroRight")
    var stats = findChild(module, "omarchyWeatherStats")
    var divider = findChild(module, "omarchyWeatherDivider")
    var forecast = findChild(module, "omarchyWeatherForecast")
    var heroIcon = findChild(module, "omarchyWeatherHeroIcon")
    var heroTemperature = findChild(module, "omarchyWeatherHeroTemperature")
    var cells = []
    collectByObjectName(module, "omarchyWeatherForecastCell", cells)

    verify(column !== null && hero !== null && heroLeft !== null && heroRight !== null)
    verify(stats !== null && divider !== null && forecast !== null)
    verify(heroIcon !== null && heroTemperature !== null)
    compare(heroIcon.font.pixelSize, 64)
    compare(heroTemperature.font.pixelSize, 56)
    compare(cells.length, 3)
    var columnBounds = rectIn(column, module)
    var leftBounds = rectIn(heroLeft, module)
    var rightBounds = rectIn(heroRight, module)
    var forecastBounds = rectIn(forecast, module)
    verify(columnBounds.x >= -0.5 && columnBounds.y >= -0.5)
    verify(columnBounds.x + columnBounds.width <= module.width + 0.5)
    verify(columnBounds.y + columnBounds.height <= module.height + 0.5)
    verify(leftBounds.x + leftBounds.width <= rightBounds.x + 0.5)
    verify(forecastBounds.x >= -0.5 && forecastBounds.y >= -0.5)
    verify(forecastBounds.x + forecastBounds.width <= module.width + 0.5)
    verify(forecastBounds.y + forecastBounds.height <= module.height + 0.5)
  }

  function test_omarchyAuthorityGeometryAt480() {
    var module = createTemporaryObject(weatherModuleComponent, testCase, {
      width: 480,
      height: 200,
      enabled: true,
      weatherController: controllerFor("current"),
      visualStyle: "scene",
      detailMode: "standard",
      temperatureUnit: "fahrenheit"
    })
    verify(module !== null)
    wait(1)

    var nativeContent = findChild(module, "omarchyWeatherNativeContent")
    var hero = findChild(module, "omarchyWeatherHero")
    var heroRight = findChild(module, "omarchyWeatherHeroRight")
    var stats = findChild(module, "omarchyWeatherStats")
    var forecastRow = findChild(module, "omarchyWeatherForecastRow")
    verify(nativeContent !== null && hero !== null && heroRight !== null)
    verify(stats !== null && forecastRow !== null)
    compare(nativeContent.width, 480)
    compare(nativeContent.scale, 1)
    compare(hero.width - (heroRight.x + heroRight.width), 20)
    compare(stats.spacing, 36)
    compare(forecastRow.spacing, 44)
    verify(forecastRow.width <= 480)
  }

  function test_constrainedSceneKeepsDetailsAndForecast() {
    var module = createTemporaryObject(weatherModuleComponent, testCase, {
      width: 230,
      height: 200,
      enabled: true,
      weatherController: controllerFor("current"),
      visualStyle: "scene",
      detailMode: "standard",
      temperatureUnit: "fahrenheit"
    })
    verify(module !== null)
    wait(1)

    var column = findChild(module, "constrainedWeatherColumn")
    var details = findChild(module, "constrainedWeatherDetails")
    var divider = findChild(module, "constrainedWeatherDivider")
    var forecast = findChild(module, "constrainedWeatherForecast")
    verify(column !== null && details !== null && divider !== null && forecast !== null)
    var columnBounds = rectIn(column, module)
    verify(columnBounds.x >= -0.5 && columnBounds.y >= -0.5)
    verify(columnBounds.x + columnBounds.width <= module.width + 0.5)
    verify(columnBounds.y + columnBounds.height <= module.height + 0.5)
    compare(divider.height, 1)
    compare(forecast.height, 44)
    grabImage(module).save("/tmp/omadeck-weather-constrained.png")
  }

  function test_omarchyLiveCompanionGeometry() {
    var module = createTemporaryObject(weatherModuleComponent, testCase, {
      width: 384,
      height: 140,
      enabled: true,
      weatherController: controllerFor("current"),
      visualStyle: "scene",
      detailMode: "standard",
      temperatureUnit: "fahrenheit"
    })
    verify(module !== null)
    wait(1)

    var nativeContent = findChild(module, "omarchyWeatherNativeContent")
    var divider = findChild(module, "omarchyWeatherDivider")
    var forecast = findChild(module, "omarchyWeatherForecast")
    var cells = []
    collectByObjectName(module, "omarchyWeatherForecastCell", cells)
    verify(nativeContent !== null && divider !== null && forecast !== null)
    compare(divider.visible, true)
    compare(forecast.visible, true)
    compare(cells.length, 3)
    var contentBounds = rectIn(nativeContent, module)
    verify(contentBounds.x >= -0.5 && contentBounds.y >= -0.5)
    verify(contentBounds.x + contentBounds.width <= module.width + 0.5)
    verify(contentBounds.y + contentBounds.height <= module.height + 0.5)
    grabImage(module).save("/tmp/omadeck-weather-live-companion.png")
  }

  function test_omarchyWideValuesFitWithoutOverlap() {
    var wide = currentWeather()
    wide.temperatureC = 1234
    wide.feelsLikeC = -1234
    wide.windKph = 12345
    wide.humidity = 999
    wide.location = "A VERY LONG NORMALIZED WEATHER LOCATION NAME"
    for (var forecastIndex = 0; forecastIndex < wide.forecast.length; forecastIndex++) {
      wide.forecast[forecastIndex].highC = 123456789
      wide.forecast[forecastIndex].lowC = -123456789
    }

    var geometries = [{ width: 400, height: 160 }, { width: 430, height: 200 }]
    for (var geometryIndex = 0; geometryIndex < geometries.length; geometryIndex++) {
      var geometry = geometries[geometryIndex]
      var module = createTemporaryObject(weatherModuleComponent, testCase, {
        width: geometry.width,
        height: geometry.height,
        enabled: true,
        weatherController: { current: wide, loading: false, error: "" },
        visualStyle: "scene",
        detailMode: "standard",
        temperatureUnit: "fahrenheit"
      })
      verify(module !== null)
      wait(1)

      var nativeContent = findChild(module, "omarchyWeatherNativeContent")
      var heroLeft = findChild(module, "omarchyWeatherHeroLeft")
      var heroRight = findChild(module, "omarchyWeatherHeroRight")
      var forecastRow = findChild(module, "omarchyWeatherForecastRow")
      var cells = []
      collectByObjectName(module, "omarchyWeatherForecastCell", cells)
      verify(nativeContent !== null && heroLeft !== null && heroRight !== null)
      verify(forecastRow !== null && cells.length === 3)
      var leftBounds = rectIn(heroLeft, module)
      var rightBounds = rectIn(heroRight, module)
      var contentBounds = rectIn(nativeContent, module)
      var forecastBounds = rectIn(forecastRow, module)
      verify(leftBounds.x + leftBounds.width <= rightBounds.x + 0.5)
      verify(contentBounds.x >= -0.5 && contentBounds.y >= -0.5)
      verify(contentBounds.x + contentBounds.width <= module.width + 0.5)
      verify(contentBounds.y + contentBounds.height <= module.height + 0.5)
      verify(forecastBounds.x >= -0.5 && forecastBounds.y >= -0.5)
      verify(forecastBounds.x + forecastBounds.width <= module.width + 0.5)
      verify(forecastBounds.y + forecastBounds.height <= module.height + 0.5)
      for (var cellIndex = 0; cellIndex < cells.length; cellIndex++) {
        var cellBounds = rectIn(cells[cellIndex], module)
        verify(cellBounds.x >= -0.5 && cellBounds.y >= -0.5)
        verify(cellBounds.x + cellBounds.width <= module.width + 0.5)
        verify(cellBounds.y + cellBounds.height <= module.height + 0.5)
      }
      verify(nativeContent.scale < 1)
      verify(nativeContent.scale > 0)
    }
  }

  function test_omarchyRoutingBoundaryAndNullSafety() {
    var fallback = createTemporaryObject(weatherModuleComponent, testCase, {
      width: 349,
      height: 120,
      enabled: true,
      weatherController: controllerFor("current"),
      visualStyle: "scene",
      detailMode: "standard",
      temperatureUnit: "fahrenheit"
    })
    var native = createTemporaryObject(weatherModuleComponent, testCase, {
      width: 350,
      height: 120,
      enabled: true,
      weatherController: controllerFor("current"),
      visualStyle: "scene",
      detailMode: "standard",
      temperatureUnit: "fahrenheit"
    })
    var empty = createTemporaryObject(omarchyWeatherComponent, testCase, {
      width: 430,
      height: 200,
      weather: null,
      forecastDays: []
    })
    verify(fallback !== null && native !== null && empty !== null)
    wait(1)
    compare(findChild(fallback, "omarchyWeatherColumn"), null)
    verify(findChild(native, "omarchyWeatherColumn") !== null)
    verify(findChild(empty, "omarchyWeatherColumn") !== null)
  }

  Component {
    id: weatherModuleComponent
    Modules.WeatherModule {}
  }

  Component {
    id: omarchyWeatherComponent
    Components.OmarchyWeatherVisual {}
  }
}
