const assert = require("node:assert/strict")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const { spawnSync, execFileSync } = require("node:child_process")
const test = require("node:test")

const root = path.resolve(__dirname, "..")
const layoutPolicy = {}
require("node:vm").runInNewContext(fs.readFileSync(path.join(root, "services/LayoutPolicy.js"), "utf8")
  .replace(/^\.pragma library\s*/m, ""), layoutPolicy)
const convertLayout = value => JSON.parse(JSON.stringify(layoutPolicy.dashboardLayout(value)))

// The marketplace/default-branch snapshot, deliberately pinned for rollback coverage.
const priorRelease = "36578b3ba701db709b69ac6dccb32e61d53e34a0"
for (const upgrade of [false, true]) test(upgrade
  ? "published settings survive upgrade to candidate and rollback without data loss"
  : "real Quickshell controllers persist settings across isolated process recreation", () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), "omadeck-settings-"))
  try {
    for (const directory of [".config", ".cache", ".local/state", "runtime"])
      fs.mkdirSync(path.join(home, directory), { recursive: true, mode: 0o700 })
    const fixture = path.join(home, "fixture")
    fs.mkdirSync(path.join(fixture, "services"), { recursive: true })
    function installControllers(ref) {
      for (const file of ["AppearanceController.qml", "HardwareController.qml", "HardwarePolicy.js",
        "LayoutController.qml", "LayoutPolicy.js", "LauncherController.qml", "LauncherPolicy.js",
        "TimerController.qml", "TimerPolicy.js"])
        if (ref) fs.writeFileSync(path.join(fixture, "services", file),
          execFileSync("git", ["show", `${ref}:services/${file}`], { cwd: root }))
        else fs.copyFileSync(path.join(root, "services", file), path.join(fixture, "services", file))
    }
    installControllers(upgrade ? priorRelease : null)
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
      const state = JSON.parse(match[1])
      // Published versions predate this additive, false-by-default preference.
      state.appearance = { workspaceCloseOnActivate: false, ...state.appearance }
      return state
    }
    if (!upgrade) {
      assert.equal(run("snapshot").appearance.workspaceCloseOnActivate, false)
      assert.equal(run("workspace-write").appearance.workspaceCloseOnActivate, true)
      assert.equal(run("read").appearance.workspaceCloseOnActivate, true, "close preference survives process recreation")
      assert.equal(run("workspace-clear").appearance.workspaceCloseOnActivate, false)
      assert.equal(run("read").appearance.workspaceCloseOnActivate, false)
      assert.equal(run("snapshot").timerSound, "ocean", "fresh settings default to Ocean")
      assert.equal(run("snapshot").timerSound, "ocean", "Ocean survives controller recreation")
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
    for (const file of ["appearance.json", "hardware.json", upgrade ? "layout.json" : "dashboard-layout.json", upgrade ? "launcher.json" : "launcher-v2.json", "timer-settings.json"])
      assert.doesNotThrow(() => JSON.parse(fs.readFileSync(path.join(settings, file), "utf8")))
    assert.deepEqual(run(upgrade ? "snapshot" : "read"), written)
    if (!upgrade) {
      const savedLayout = fs.readFileSync(path.join(settings, "dashboard-layout.json"), "utf8")
      const preview = run("customize-preview")
      assert.notDeepEqual(preview.layout, written.layout, "preview exercises movement and resizing")
      assert.equal(fs.readFileSync(path.join(settings, "dashboard-layout.json"), "utf8"), savedLayout,
        "an unfinished preview never writes to disk")
      assert.deepEqual(run("read"), written, "an interrupted edit restores the last saved layout")
      assert.deepEqual(run("customize-cancel"), written, "Cancel restores the original tree and sizes")
      assert.equal(fs.readFileSync(path.join(settings, "dashboard-layout.json"), "utf8"), savedLayout)
      const finished = run("customize-done")
      assert.deepEqual(finished, preview, "Done saves the preview")
      assert.deepEqual(run("read"), finished, "Done survives process recreation")
    }
    if (upgrade) {
      const files = fs.readdirSync(settings).filter(file => file.endsWith(".json"))
      const saved = Object.fromEntries(files.map(file => [file, fs.readFileSync(path.join(settings, file), "utf8")]))
      installControllers(null)
      const migrated = { ...written, layout: convertLayout(written.layout) }
      assert.deepEqual(run("read"), migrated, "candidate migrates the previous visual layout")
      const edited = run("write")
      assert.deepEqual(edited, { ...migrated, layout: {
        ...migrated.layout, root: { ...migrated.layout.root, ratio: 0.62 }
      } }, "candidate writes the full dashboard separately")
      assert.deepEqual(run("read"), edited, "new layout survives recreation")
      assert.equal(fs.readFileSync(path.join(settings, "layout.json"), "utf8"), saved["layout.json"],
        "migration never writes the prior release layout file")
      installControllers(priorRelease)
      assert.deepEqual(run("snapshot"), written, "published controllers must read candidate settings")
      for (const file of files) {
        const normalize = value => file === "appearance.json" ? { workspaceCloseOnActivate: false, ...value } : value
        assert.deepEqual(normalize(JSON.parse(fs.readFileSync(path.join(settings, file), "utf8"))),
          normalize(JSON.parse(saved[file])), `rollback preserves ${file}`)
      }
    }
  } finally {
    fs.rmSync(home, { recursive: true, force: true })
  }
})
