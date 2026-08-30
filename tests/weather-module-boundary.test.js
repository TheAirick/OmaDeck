const assert = require("node:assert/strict")
const childProcess = require("node:child_process")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const repositoryRoot = path.join(__dirname, "..")

function source(relativePath) {
  return fs.readFileSync(path.join(repositoryRoot, relativePath), "utf8")
}

function componentBlock(qml, componentId) {
  const marker = new RegExp(`Component\\s*\\{\\s*id:\\s*${componentId}\\b`)
  const match = marker.exec(qml)
  assert.ok(match, `missing ${componentId}`)

  const start = match.index
  const openingBrace = qml.indexOf("{", start)
  let depth = 0
  for (let index = openingBrace; index < qml.length; index += 1) {
    if (qml[index] === "{") depth += 1
    if (qml[index] === "}") depth -= 1
    if (depth === 0) return qml.slice(start, index + 1)
  }
  assert.fail(`unterminated ${componentId}`)
}

function objectBlock(qml, typeName) {
  const marker = new RegExp(`\\b${typeName}\\s*\\{`)
  const match = marker.exec(qml)
  assert.ok(match, `missing ${typeName}`)

  const openingBrace = qml.indexOf("{", match.index)
  let depth = 0
  for (let index = openingBrace; index < qml.length; index += 1) {
    if (qml[index] === "{") depth += 1
    if (qml[index] === "}") depth -= 1
    if (depth === 0) return qml.slice(match.index, index + 1)
  }
  assert.fail(`unterminated ${typeName}`)
}

function binding(qml, propertyName) {
  const match = new RegExp(`^\\s*${propertyName}:\\s*(.+)$`, "m").exec(qml)
  assert.ok(match, `missing ${propertyName} binding`)
  return match[1].trim()
}

function resolvedVisualStyle(expression, requestedStyle) {
  if (expression === "root.weatherStyle") return requestedStyle
  if (expression === "root.weatherStyle === \"scene\" ? \"minimal\" : root.weatherStyle") {
    return requestedStyle === "scene" ? "minimal" : requestedStyle
  }
  assert.fail(`unsupported visualStyle binding: ${expression}`)
}

test("WeatherModule presents one WeatherVisual for the Hero Clock boundary", () => {
  const modulePath = path.join(repositoryRoot, "modules/WeatherModule.qml")
  assert.equal(fs.existsSync(modulePath), true, "WeatherModule.qml must exist")

  const weatherModule = source("modules/WeatherModule.qml")
  const heroClock = componentBlock(source("modules/ClockModule.qml"), "heroClock")

  assert.equal((weatherModule.match(/WeatherVisual\s*\{/g) || []).length, 1)
  assert.match(weatherModule, /property var weatherController:\s*null/)
  assert.doesNotMatch(weatherModule, /property bool enabled:/)
  assert.match(weatherModule, /property string visualStyle:\s*"scene"/)
  assert.match(weatherModule, /property string detailMode:\s*"standard"/)
  assert.match(weatherModule, /property string temperatureUnit:\s*"fahrenheit"/)
  assert.match(weatherModule, /visible:\s*root\.enabled/)

  assert.match(heroClock, /WeatherModule\s*\{/)
  assert.doesNotMatch(heroClock, /WeatherVisual\s*\{/)
})

test("every Clock style delegates Weather presentation through WeatherModule", () => {
  const clockModule = source("modules/ClockModule.qml")

  assert.equal((clockModule.match(/WeatherModule\s*\{/g) || []).length, 3)
  assert.doesNotMatch(clockModule, /WeatherVisual\s*\{/)

  for (const componentId of ["heroClock", "splitClock", "compactClock"]) {
    const style = componentBlock(clockModule, componentId)
    assert.match(style, /WeatherModule\s*\{/)
    assert.match(style, /enabled:\s*root\.showWeather/)
    assert.match(style, /weatherController:\s*root\.weather/)
    assert.match(style, /detailMode:\s*root\.weatherDetail/)
    assert.match(style, /temperatureUnit:\s*root\.temperatureUnit/)
  }

  assert.match(componentBlock(clockModule, "heroClock"), /visualStyle:\s*root\.weatherStyle/)
  assert.match(componentBlock(clockModule, "splitClock"), /visualStyle:\s*root\.weatherStyle/)
  assert.match(
    componentBlock(clockModule, "compactClock"),
    /visualStyle:\s*root\.weatherStyle === "scene" \? "minimal" : root\.weatherStyle/,
  )
})

test("WeatherModule exposes controller state without owning lifecycle or settings", () => {
  const weatherModule = source("modules/WeatherModule.qml")
  const service = source("Service.qml")

  assert.match(weatherModule, /readonly property var current:\s*weatherController \? weatherController\.current : null/)
  assert.match(weatherModule, /readonly property bool loading:\s*weatherController \? weatherController\.loading : false/)
  assert.match(weatherModule, /readonly property string error:\s*weatherController \? weatherController\.error : ""/)
  assert.match(weatherModule, /weather:\s*root\.current/)
  assert.match(weatherModule, /loading:\s*root\.loading/)
  assert.match(weatherModule, /error:\s*root\.error/)

  for (const forbidden of [
    /\bProcess\s*\{/,
    /\bFileView\s*\{/,
    /\bTimer\s*\{/,
    /provider|location|poll|refresh|retry/i,
    /IpcHandler|settings|dynamic|Qt\.createComponent/i,
  ]) {
    assert.doesNotMatch(weatherModule, forbidden)
  }

  assert.equal((service.match(/WeatherController\s*\{/g) || []).length, 1)
  assert.match(service, /WeatherController\s*\{\s*id:\s*weatherStore/)
  assert.match(service, /enabled:\s*appearanceStore\.loaded && appearanceStore\.showWeather/)
})

test("the extracted module preserves the accepted render contract for every Clock and Weather state", () => {
  const fixturePath = path.join(__dirname, "fixtures/weather-clock-render-contract.json")
  assert.equal(fs.existsSync(fixturePath), true, "accepted render-contract fixture must exist")

  const baseline = JSON.parse(fs.readFileSync(fixturePath, "utf8"))
  const clockModule = source("modules/ClockModule.qml")
  const weatherModule = source("modules/WeatherModule.qml")
  const moduleVisual = objectBlock(weatherModule, "WeatherVisual")

  assert.equal(baseline.commit, "d1f8bfecac3ba0c27a2b184c86cc3f1ffa52a5e6")
  assert.equal(binding(weatherModule, "visible"), "root.enabled")
  assert.equal(binding(weatherModule, "clip"), "true")
  assert.equal(binding(moduleVisual, "anchors.fill"), "parent")
  assert.equal(binding(moduleVisual, "weather"), "root.current")
  assert.equal(binding(moduleVisual, "loading"), "root.loading")
  assert.equal(binding(moduleVisual, "error"), "root.error")

  let comparedContracts = 0
  for (const [clockStyle, expected] of Object.entries(baseline.clockStyles)) {
    const delegate = objectBlock(componentBlock(clockModule, expected.componentId), "WeatherModule")
    assert.equal(binding(delegate, "enabled"), "root.showWeather")
    assert.equal(binding(delegate, "width"), expected.width)
    assert.equal(binding(delegate, "height"), expected.height)
    assert.equal(binding(delegate, "visualStyle"), expected.visualStyle)
    if (expected.horizontalAnchor) {
      assert.equal(binding(delegate, "anchors.horizontalCenter"), expected.horizontalAnchor)
    }

    for (const state of baseline.weatherStates) {
      for (const requestedStyle of baseline.visualStyles) {
        for (const detailMode of baseline.detailModes) {
          for (const temperatureUnit of baseline.temperatureUnits) {
            const before = {
              clockStyle,
              visible: state !== "disabled",
              weatherState: state,
              visualStyle: expected.sceneFallsBackToMinimal && requestedStyle === "scene"
                ? "minimal"
                : requestedStyle,
              detailMode,
              temperatureUnit,
            }
            const after = {
              clockStyle,
              visible: binding(delegate, "enabled") === "root.showWeather"
                && binding(weatherModule, "visible") === "root.enabled"
                && state !== "disabled",
              weatherState: state,
              visualStyle: resolvedVisualStyle(binding(delegate, "visualStyle"), requestedStyle),
              detailMode: binding(delegate, "detailMode") === "root.weatherDetail"
                ? detailMode
                : "invalid",
              temperatureUnit: binding(delegate, "temperatureUnit") === "root.temperatureUnit"
                ? temperatureUnit
                : "invalid",
            }
            assert.deepEqual(after, before)
            comparedContracts += 1
          }
        }
      }
    }
  }
  assert.equal(comparedContracts, 216)
})

test("the render contract fixture matches the accepted baseline commit", () => {
  const baseline = JSON.parse(source("tests/fixtures/weather-clock-render-contract.json"))
  const acceptedClock = childProcess.execFileSync(
    "git",
    ["show", `${baseline.commit}:modules/ClockModule.qml`],
    { cwd: repositoryRoot, encoding: "utf8" },
  )

  for (const expected of Object.values(baseline.clockStyles)) {
    const weatherVisual = objectBlock(componentBlock(acceptedClock, expected.componentId), "WeatherVisual")
    assert.equal(binding(weatherVisual, "visible"), "root.showWeather")
    assert.equal(binding(weatherVisual, "width"), expected.width)
    assert.equal(binding(weatherVisual, "height"), expected.height)
    assert.equal(binding(weatherVisual, "weather"), "root.weather ? root.weather.current : null")
    assert.equal(binding(weatherVisual, "loading"), "root.weather ? root.weather.loading : false")
    assert.equal(binding(weatherVisual, "error"), "root.weather ? root.weather.error : \"\"")
    assert.equal(binding(weatherVisual, "visualStyle"), expected.visualStyle)
    assert.equal(binding(weatherVisual, "detailMode"), "root.weatherDetail")
    assert.equal(binding(weatherVisual, "temperatureUnit"), "root.temperatureUnit")
    if (expected.horizontalAnchor) {
      assert.equal(binding(weatherVisual, "anchors.horizontalCenter"), expected.horizontalAnchor)
    }
  }
})

const qmlTestRunner = "/usr/lib/qt6/bin/qmltestrunner"
test("offscreen QML rendering matches the accepted presentation boundary", {
  skip: !fs.existsSync(qmlTestRunner),
}, () => {
  const result = childProcess.spawnSync(qmlTestRunner, [
    "-silent",
    "-input",
    "tests/qml/tst_weather-module-render.qml",
    "-import",
    "tests/qml/imports",
  ], {
    cwd: repositoryRoot,
    encoding: "utf8",
    env: {
      ...process.env,
      QT_QPA_PLATFORM: "offscreen",
      QSG_RHI_BACKEND: "software",
    },
  })

  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`)
  assert.match(result.stdout, /Totals: 276 passed, 0 failed/)
})
