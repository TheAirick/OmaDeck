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


test("WeatherModule presents one WeatherVisual for the Clock companion boundary", () => {
  const modulePath = path.join(repositoryRoot, "modules/WeatherModule.qml")
  assert.equal(fs.existsSync(modulePath), true, "WeatherModule.qml must exist")

  const weatherModule = source("modules/WeatherModule.qml")
  const companion = source("modules/ClockCompanionModule.qml")

  assert.equal((weatherModule.match(/WeatherVisual\s*\{/g) || []).length, 1)
  assert.match(weatherModule, /property var weatherController:\s*null/)
  assert.doesNotMatch(weatherModule, /property bool enabled:/)
  assert.match(weatherModule, /property string visualStyle:\s*"scene"/)
  assert.match(weatherModule, /property string detailMode:\s*"standard"/)
  assert.match(weatherModule, /property string temperatureUnit:\s*"fahrenheit"/)
  assert.match(weatherModule, /visible:\s*root\.enabled/)

  assert.match(companion, /WeatherModule\s*\{/)
  assert.doesNotMatch(companion, /WeatherVisual\s*\{/)
})

test("the compact Clock delegates one static Weather presenter", () => {
  const companion = source("modules/ClockCompanionModule.qml")

  assert.equal((companion.match(/WeatherModule\s*\{/g) || []).length, 1)
  assert.doesNotMatch(companion, /WeatherVisual\s*\{/)
  assert.match(companion, /enabled:\s*root\.showWeather/)
  assert.match(companion, /weatherController:\s*root\.weather/)
  assert.match(companion, /detailMode:\s*root\.weatherDetail/)
  assert.match(companion, /temperatureUnit:\s*root\.temperatureUnit/)
  assert.match(companion, /visualStyle:\s*root\.weatherStyle/)
})

test("scene weather follows the installed Omarchy panel hierarchy and scale", () => {
  const weatherVisual = source("components/WeatherVisual.qml")
  const scene = source("components/OmarchyWeatherVisual.qml")

  for (const objectName of [
    "omarchyWeatherColumn",
    "omarchyWeatherHero",
    "omarchyWeatherHeroLeft",
    "omarchyWeatherHeroRight",
    "omarchyWeatherStats",
    "omarchyWeatherDivider",
    "omarchyWeatherForecast",
  ]) assert.match(scene, new RegExp(`objectName:\\s*"${objectName}"`))

  assert.match(scene, /id:\s*heroIcon[\s\S]*font\.pixelSize:\s*64/)
  assert.match(scene, /id:\s*heroTemperature[\s\S]*font\.pixelSize:\s*56/)
  assert.match(scene, /label:\s*"FEELS"[\s\S]*label:\s*"WIND"[\s\S]*label:\s*"HUMID"/)
  assert.match(scene, /spacing:\s*Style\.space\(14\)/)
  assert.match(scene, /height:\s*Style\.spacing\.hairline/)
  assert.match(scene, /spacing:\s*Style\.space\(36\)/)
  assert.match(scene, /anchors\.rightMargin:\s*Style\.space\(20\)/)
  assert.match(scene, /id:\s*forecastRow[\s\S]*spacing:\s*Style\.space\(44\)/)
  assert.match(scene, /width:\s*Math\.max\(Style\.space\(480\)/)
  assert.match(weatherVisual, /return days\.slice\(0, effectiveDetail === "full" \? 3 : 2\)/)
  assert.match(weatherVisual, /id:\s*omarchyWeather[\s\S]*OmarchyWeatherVisual\s*\{/)
  assert.match(weatherVisual, /root\.width >= Style\.space\(350\)[\s\S]*root\.height >= Style\.space\(110\)/)
  assert.match(weatherVisual, /root\.weather\.forecast\.slice\(0, 3\)/)
})

test("the constrained scene renderer remains byte-identical to the reviewed layout candidate", () => {
  const reviewedWeatherVisual = childProcess.execFileSync(
    "git",
    ["show", "b7e178cb9a7f50cdf72477c28652e13a2868c207:components/WeatherVisual.qml"],
    { cwd: repositoryRoot, encoding: "utf8" },
  )
  assert.equal(
    componentBlock(source("components/WeatherVisual.qml"), "detailedWeather"),
    componentBlock(reviewedWeatherVisual, "detailedWeather"),
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

test("the extracted module preserves its controller-to-visual render contract in the companion", () => {
  const companion = source("modules/ClockCompanionModule.qml")
  const weatherModule = source("modules/WeatherModule.qml")
  const moduleVisual = objectBlock(weatherModule, "WeatherVisual")
  const delegate = objectBlock(companion, "WeatherModule")

  assert.equal(binding(weatherModule, "visible"), "root.enabled")
  assert.equal(binding(weatherModule, "clip"), "true")
  assert.equal(binding(moduleVisual, "anchors.fill"), "parent")
  assert.equal(binding(moduleVisual, "weather"), "root.current")
  assert.equal(binding(moduleVisual, "loading"), "root.loading")
  assert.equal(binding(moduleVisual, "error"), "root.error")
  assert.equal(binding(delegate, "enabled"), "root.showWeather")
  assert.equal(binding(delegate, "anchors.fill"), "parent")
  assert.equal(binding(delegate, "visible"), "root.showWeather")
  assert.equal(binding(delegate, "visualStyle"), "root.weatherStyle")
  assert.equal(binding(delegate, "detailMode"), "root.weatherDetail")
  assert.equal(binding(delegate, "temperatureUnit"), "root.temperatureUnit")
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
  assert.match(result.stdout, /Totals: 281 passed, 0 failed/)
  assert.doesNotMatch(result.stdout + result.stderr, /TypeError|Cannot read propert/)
})
