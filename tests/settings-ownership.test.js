const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const service = fs.readFileSync(
  path.join(__dirname, "../Service.qml"),
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
const preferencesModule = fs.readFileSync(
  path.join(__dirname, "../modules/PreferencesModule.qml"),
  "utf8",
)
const hardwareController = fs.readFileSync(
  path.join(__dirname, "../services/HardwareController.qml"),
  "utf8",
)

test("the tray can read and update the authoritative appearance controller over IPC", () => {
  assert.match(service, /function appearanceState\(\): string/)
  assert.match(service, /appearanceStore\.snapshot\(\)/)
  assert.match(service, /function setAppearance\(key: string, value: string\): string/)
  assert.match(service, /appearanceStore\.loaded/)
  assert.match(service, /appearanceStore\.setOption\(key, parsedValue\)/)
  assert.match(service, /JSON\.stringify\(\{ ok: true/)
  assert.match(service, /function refreshWeather\(\): string/)
  assert.match(service, /appearanceStore\.showWeather/)
  assert.match(service, /weatherStore\.refresh\(\)/)
  assert.match(appearanceController, /function restoreSnapshot\(state\)/)
  assert.match(appearanceController, /var before = snapshot\(\)/)
  assert.match(appearanceController, /blockWrites:\s*true/)
  assert.match(appearanceController, /onSaved:\s*root\.lastSaveSucceeded = true/)
  assert.match(appearanceController, /onSaveFailed:/)
  assert.match(appearanceController, /if \(!saved\)[\s\S]*restoreSnapshot\(before\)/)
  assert.match(appearanceController, /return saved/)
})

test("the taskbar tray projects Clock and Weather controls through the shared controller", () => {
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

test("Preferences projects OmaDeck appearance controls through the same controller", () => {
  assert.match(preferencesModule, /appearanceController\.setOption\(key, value\)/)
  assert.doesNotMatch(preferencesModule, /FileView|Process\s*\{|writeAdapter|JSON\.stringify/)
  for (const key of [
    "clockStyle", "use24Hour", "showSeconds", "showWeather",
    "weatherStyle", "weatherDetail", "temperatureUnit",
  ]) assert.match(preferencesModule, new RegExp(`applyAppearance\\("${key}"`))
})

test("Preferences delegates Shell controls to Omarchy's existing services", () => {
  for (const serviceId of ["omarchy.notifications", "omarchy.nightlight", "omarchy.idle"])
    assert.match(preferencesModule, new RegExp(`firstPartyServiceFor\\("${serviceId.replace(".", "\\.")}"\\)`))
  assert.match(preferencesModule, /notificationService\.setDoNotDisturb\(value\)/)
  assert.match(preferencesModule, /nightlightService\.setNightlight\(value\)/)
  assert.match(preferencesModule, /idleService\.setIdleEnabled\(!value\)/)
  assert.doesNotMatch(preferencesModule, /FileView|Process\s*\{|execDetached|persistShellConfig/)
})

test("Preferences uses the host-owned config mutator for direct bar and idle settings", () => {
  assert.match(preferencesModule, /shell\.mutateShellConfig\(mutator\)/)
  assert.match(preferencesModule, /config\.bar\.position = value/)
  assert.match(preferencesModule, /config\.bar\.transparent = value === true/)
  assert.match(preferencesModule, /\[60, 150, 300, 600, 900\]/)
  assert.match(preferencesModule, /\[300, 600, 900, 1800, 3600\]/)
  assert.match(preferencesModule, /config\.idle\[key\] = seconds/)
  assert.doesNotMatch(preferencesModule, /FileView|Process\s*\{|execDetached|persistShellConfig/)
})

test("Preferences hands complex settings to installed Omarchy panels and menus", () => {
  assert.match(preferencesModule, /shell\.summon\("omarchy\.menu"/)
  for (const route of [
    "style.theme", "style.background", "style.font", "trigger.toggle",
    "learn.keybindings", "setup.monitors", "trigger.hardware", "setup.input",
    "setup.default", "apps", "system", "setup.plugin", "setup.config", "update",
  ]) assert.match(preferencesModule, new RegExp(route.replace(".", "\\.")))
  for (const panel of ["omarchy.monitor", "omarchy.audio", "omarchy.bluetooth", "omarchy.power"])
    assert.match(preferencesModule, new RegExp(panel.replace(".", "\\.")))
})

test("Preferences delegates detected hardware choices to one validated controller", () => {
  for (const method of ["setTargetScreen", "setPrimaryMonitor", "setTouchDevice"])
    assert.match(preferencesModule, new RegExp(`hardwareController\\.${method}\\(value\\)`))
  assert.match(hardwareController, /HardwarePolicy\.includesExact\(availableScreenNames, value\)/)
  assert.match(hardwareController, /HardwarePolicy\.includesExact\(availableTouchDeviceNames, value\)/)
  assert.match(hardwareController, /atomicWrites:\s*true/)
  assert.match(hardwareController, /blockWrites:\s*true/)
  assert.match(hardwareController, /if \(next === null \|\| !persist\(\)\)[\s\S]*restoreSnapshot\(before\)/)
  assert.doesNotMatch(preferencesModule, /\/dev\/input|hyprctl\s+monitors|FileView|Process\s*\{/)
})

test("Clock and Weather no longer duplicate settings controls on the deck", () => {
  assert.doesNotMatch(clockModule, /property bool editing/)
  assert.doesNotMatch(clockModule, /id: settingsButton|component SettingRow/)
  assert.doesNotMatch(clockModule, /openLocationSettings|Clock & weather/)
  assert.doesNotMatch(clockModule, /root\.editing/)
})
