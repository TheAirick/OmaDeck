const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const deckSurface = fs.readFileSync(
  path.join(__dirname, "../components/DeckSurface.qml"),
  "utf8",
)
const trayApp = fs.readFileSync(
  path.join(__dirname, "../native/TrayApp.cpp"),
  "utf8",
)
const clockModule = fs.readFileSync(
  path.join(__dirname, "../modules/ClockModule.qml"),
  "utf8",
)
const appearanceController = fs.readFileSync(
  path.join(__dirname, "../services/AppearanceController.qml"),
  "utf8",
)

test("the tray can read and update the authoritative appearance controller over IPC", () => {
  assert.match(deckSurface, /function appearanceState\(\): string/)
  assert.match(deckSurface, /appearanceController\.snapshot\(\)/)
  assert.match(deckSurface, /function setAppearance\(key: string, value: string\): string/)
  assert.match(deckSurface, /appearanceController\.loaded/)
  assert.match(deckSurface, /appearanceController\.setOption\(key, parsedValue\)/)
  assert.match(deckSurface, /JSON\.stringify\(\{ ok: true/)
  assert.match(deckSurface, /function refreshWeather\(\): string/)
  assert.match(deckSurface, /appearanceController\.showWeather/)
  assert.match(deckSurface, /weatherController\.refresh\(\)/)
  assert.match(appearanceController, /function restoreSnapshot\(state\)/)
  assert.match(appearanceController, /var before = snapshot\(\)/)
  assert.match(appearanceController, /blockWrites:\s*true/)
  assert.match(appearanceController, /onSaved:\s*root\.lastSaveSucceeded = true/)
  assert.match(appearanceController, /onSaveFailed:/)
  assert.match(appearanceController, /if \(!saved\)[\s\S]*restoreSnapshot\(before\)/)
  assert.match(appearanceController, /return saved/)
})

test("the taskbar tray owns one Clock and Weather settings panel", () => {
  assert.match(trayApp, /Clock & weather settings…/)
  assert.match(trayApp, /void showAppearanceSettings\(\)/)
  assert.match(trayApp, /appearanceState/)
  assert.match(trayApp, /setAppearance/)
  assert.match(trayApp, /refreshWeather/)
  assert.match(trayApp, /omarchy\.weather/)
  assert.match(trayApp, /QComboBox/)
  assert.match(trayApp, /QCheckBox/)
  assert.match(trayApp, /setFixedSize\(460, 430\)/)
  assert.match(trayApp, /<h2>Clock & Weather<\/h2>/)
  assert.match(trayApp, /class SafeComboBox final : public QComboBox/)
  assert.match(trayApp, /void wheelEvent\(QWheelEvent \*event\) override/)
  assert.match(trayApp, /if \(!hasFocus\(\)\)/)
  assert.match(trayApp, /QSignalBlocker blocker\(combo\)/)
  assert.match(trayApp, /void reloadAppearanceSettings\(\)/)
  assert.match(trayApp, /if \(!setAppearanceOption/)
  assert.match(trayApp, /refreshWeather->setEnabled\(enabled\)/)
  assert.match(trayApp, /weatherVisual->setEnabled\(enabled\)/)
  assert.match(trayApp, /OmaDeck IPC could not start:/)
  assert.match(trayApp, /process\.kill\(\)[\s\S]*process\.waitForFinished/)
  assert.match(trayApp, /accepted\.isBool\(\)/)
  assert.match(trayApp, /accepted\.isString\(\)/)
  assert.match(trayApp, /state\.value\(QStringLiteral\("version"\)\)\.isDouble\(\)/)
})

test("Clock and Weather no longer duplicate settings controls on the deck", () => {
  assert.doesNotMatch(clockModule, /property bool editing/)
  assert.doesNotMatch(clockModule, /id: settingsButton|component SettingRow/)
  assert.doesNotMatch(clockModule, /openLocationSettings|Clock & weather/)
  assert.doesNotMatch(clockModule, /root\.editing/)
})
