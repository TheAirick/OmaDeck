const assert = require("node:assert/strict")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const { spawnSync } = require("node:child_process")
const test = require("node:test")

const root = path.resolve(__dirname, "..")

test("real Quickshell controllers persist settings across isolated process recreation", () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), "omadeck-settings-"))
  try {
    for (const directory of [".config", ".cache", ".local/state", "runtime"])
      fs.mkdirSync(path.join(home, directory), { recursive: true, mode: 0o700 })
    const fixture = path.join(home, "fixture")
    fs.mkdirSync(path.join(fixture, "services"), { recursive: true })
    for (const file of ["AppearanceController.qml", "HardwareController.qml", "HardwarePolicy.js",
      "LayoutController.qml", "LayoutPolicy.js", "LauncherController.qml", "LauncherPolicy.js",
      "TimerController.qml", "TimerPolicy.js"])
      fs.copyFileSync(path.join(root, "services", file), path.join(fixture, "services", file))
    fs.writeFileSync(path.join(fixture, "shell.qml"),
      fs.readFileSync(path.join(root, "tests/qml/real-settings/shell.qml"), "utf8")
        .replace('"../../../services"', '"./services"'))
    const env = {
      ...process.env,
      HOME: home,
      XDG_CONFIG_HOME: path.join(home, ".config"),
      XDG_CACHE_HOME: path.join(home, ".cache"),
      XDG_STATE_HOME: path.join(home, ".local/state"),
      XDG_RUNTIME_DIR: path.join(home, "runtime"),
      QT_QPA_PLATFORM: "offscreen",
      QT_QPA_PLATFORMTHEME: "basic",
      QT_QUICK_BACKEND: "software",
      QML_DISABLE_DISK_CACHE: "1",
    }
    // Do not attach the fixture to the desktop session, display, or test mocks.
    for (const name of ["DBUS_SESSION_BUS_ADDRESS", "WAYLAND_DISPLAY", "DISPLAY",
      "QML_IMPORT_PATH", "QML2_IMPORT_PATH", "QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST"])
      delete env[name]
    function run(phase) {
      const result = spawnSync("/usr/bin/qs", ["--no-color", "--path",
        path.join(fixture, "shell.qml")], {
        env: { ...env, OMADECK_SETTINGS_PHASE: phase },
        encoding: "utf8", timeout: 15000, maxBuffer: 1024 * 1024,
      })
      const output = result.stdout + result.stderr
      assert.equal(result.error, undefined, output)
      assert.equal(result.status, 0, output)
      assert.doesNotMatch(output, /READINESS_FAILURE|Failed to load configuration/)
      const match = output.match(/READINESS_STATE (\{[^\n]+\})/)
      assert.ok(match, output)
      return JSON.parse(match[1])
    }
    const written = run("write")
    assert.equal(written.appearance.use24Hour, true)
    assert.equal(written.appearance.temperatureUnit, "celsius")
    assert.equal(written.hardware.targetScreen, "fixture-deck")
    assert.deepEqual(written.hardware.touchDeviceNames, ["Fixture Touchscreen"])
    assert.equal(written.layout.root.ratio, 0.62)
    assert.equal(written.launcher.includes("browser"), false)
    assert.equal(written.timerSound, "bell")
    assert.equal(written.timerStatus, "idle")
    const settings = path.join(home, ".config/omadeck")
    for (const file of ["appearance.json", "hardware.json", "layout.json", "launcher.json", "timer-settings.json"])
      assert.doesNotThrow(() => JSON.parse(fs.readFileSync(path.join(settings, file), "utf8")))
    assert.deepEqual(run("read"), written)
  } finally {
    fs.rmSync(home, { recursive: true, force: true })
  }
})
