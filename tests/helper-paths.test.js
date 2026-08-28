const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const repositoryRoot = path.join(__dirname, "..")
const service = fs.readFileSync(path.join(repositoryRoot, "Service.qml"), "utf8")
const deckSurface = fs.readFileSync(
  path.join(repositoryRoot, "components/DeckSurface.qml"),
  "utf8",
)
const appLauncher = fs.readFileSync(
  path.join(repositoryRoot, "modules/AppLauncherModule.qml"),
  "utf8",
)
const systemModule = fs.readFileSync(
  path.join(repositoryRoot, "modules/SystemModule.qml"),
  "utf8",
)
const weatherController = fs.readFileSync(
  path.join(repositoryRoot, "services/WeatherController.qml"),
  "utf8",
)

const qmlSources = [service, deckSurface, appLauncher, systemModule, weatherController]

function componentBlock(source, componentName) {
  const start = source.indexOf(`${componentName} {`)
  assert.notEqual(start, -1, `${componentName} must exist`)
  const nextComponent = source.indexOf("\n    }", start)
  return source.slice(start, nextComponent === -1 ? source.length : nextComponent)
}

test("Service resolves one canonical plugin directory and passes it to DeckSurface", () => {
  assert.match(service, /readonly property string pluginDir:/)
  assert.match(service, /manifest\s*&&\s*manifest\.__sourceDir/)
  assert.match(service, /Qt\.resolvedUrl\("\."\)/)
  assert.match(componentBlock(service, "DeckSurface"), /pluginDir:\s*root\.pluginDir/)
})

test("DeckSurface forwards the canonical plugin directory to helper-owning modules", () => {
  assert.match(deckSurface, /property string pluginDir:\s*""/)
  assert.match(componentBlock(deckSurface, "SystemModule"), /pluginDir:\s*root\.pluginDir/)
  assert.match(componentBlock(deckSurface, "AppLauncherModule"), /pluginDir:\s*root\.pluginDir/)
})

test("plugin helpers are derived from the canonical plugin directory", () => {
  assert.match(componentBlock(service, "WeatherController"), /pluginDir:\s*root\.pluginDir/)
  assert.match(service, /command:\s*\[root\.pluginDir\s*\+\s*"\/scripts\/run-tray"/)
  assert.match(appLauncher, /property string pluginDir:\s*""/)
  assert.match(appLauncher, /launcherScript:\s*root\.pluginDir\s*\+\s*"\/scripts\/focus-or-launch"/)
  assert.match(systemModule, /property string pluginDir:\s*""/)
  assert.match(systemModule, /command:\s*\[root\.pluginDir\s*\+\s*"\/scripts\/system-stats"\]/)
  assert.match(weatherController, /command:\s*\[root\.pluginDir\s*\+\s*"\/scripts\/weather-json"\]/)

  for (const source of qmlSources) {
    assert.doesNotMatch(source, /Projects\/Omadeck/)
    assert.doesNotMatch(source, /\.config\/omarchy\/plugins\/pretty\.omadeck\/scripts/)
  }
})
