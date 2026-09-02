const assert = require("node:assert/strict")
const { spawnSync } = require("node:child_process")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const test = require("node:test")

const root = path.join(__dirname, "..")
const source = relative => fs.readFileSync(path.join(root, relative), "utf8")

test("native builds stage privately and atomically install verified artifacts", () => {
  const build = source("scripts/build-native")
  const cmake = source("native/CMakeLists.txt")

  assert.match(build, /umask 077/)
  assert.match(build, /mktemp -d --tmpdir="\$runtime_base" omadeck-build\.XXXXXXXX/)
  assert.match(build, /-DOMADECK_ARTIFACT_ROOT="\$artifact_root"/)
  assert.match(build, /sha256sum -- "\$staged"/)
  assert.match(build, /mv -T -- "\$temporary" "\$destination"/)
  assert.match(build, /Refusing to replace unexpected artifact target/)
  assert.match(cmake, /OMADECK_ARTIFACT_ROOT/)
  assert.doesNotMatch(cmake, /CMAKE_CURRENT_SOURCE_DIR}\/OmaDeck\/Touch/)
  assert.doesNotMatch(cmake, /CMAKE_CURRENT_SOURCE_DIR}\/bin/)
})

test("the tray pins a verified inode and has bounded lifecycle recovery", () => {
  const runner = source("scripts/run-tray")
  const doctor = source("scripts/omadeck-doctor")
  const service = source("Service.qml")
  const tray = source("native/TrayApp.cpp")

  assert.match(runner, /exec 9< "\$tray_binary"/)
  assert.match(runner, /"\$SHA256SUM" \/proc\/self\/fd\/9/)
  assert.match(runner, /readonly SHA256SUM=\/usr\/bin\/sha256sum/)
  assert.match(runner, /readonly SETPRIV=\/usr\/bin\/setpriv/)
  assert.match(runner, /export PATH=\/usr\/bin:\/usr\/share\/omarchy\/bin/)
  assert.match(runner, /"\$SETPRIV" --pdeathsig TERM \/proc\/self\/fd\/9/)
  assert.match(service, /trayRestartFailures/)
  assert.match(service, /Math\.min\(30000/)
  assert.match(service, /trayController\.signal\(9\)/)
  assert.match(service, /Component\.onDestruction/)
  assert.match(tray, /QStringLiteral\("\/usr\/share\/omarchy\/bin\/omarchy-shell"\)/)
  assert.match(tray, /QStringLiteral\("\/usr\/share\/omarchy\/bin\/omarchy"\)/)
  assert.doesNotMatch(tray, /QStringLiteral\("omarchy(?:-shell)?"\)/)
  assert.match(doctor, /readonly HYPRCTL=\/usr\/bin\/hyprctl/)
  assert.match(doctor, /readonly OMARCHY_SHELL=\/usr\/share\/omarchy\/bin\/omarchy-shell/)
  assert.match(doctor, /export PATH=\/usr\/bin:\/usr\/share\/omarchy\/bin/)
  assert.doesNotMatch(doctor, /command -v/)
})

test("system stats use secure state and bounded process groups", () => {
  const stats = source("scripts/system-stats")

  assert.match(stats, /os\.O_NOFOLLOW/)
  assert.match(stats, /dir_fd=directory/)
  assert.match(stats, /os\.replace\(temporary, name, src_dir_fd=directory, dst_dir_fd=directory\)/)
  assert.match(stats, /start_new_session=True/)
  assert.match(stats, /os\.killpg\(process\.pid, signal\.SIGKILL\)/)
  assert.match(stats, /MAX_CLIENTS = 64/)
  assert.match(stats, /MAX_CLIPBOARD_ITEMS = 20/)
  assert.match(stats, /MAX_OUTPUT_BYTES = 256 \* 1024/)
  assert.match(stats, /os\.environ\["PATH"\] = "\/usr\/bin:\/usr\/share\/omarchy\/bin"/)
  assert.match(stats, /SENSORS = "\/usr\/bin\/sensors"/)
  assert.match(stats, /HYPRCTL = "\/usr\/bin\/hyprctl"/)
  assert.match(stats, /PS = "\/usr\/bin\/ps"/)
  assert.match(stats, /not trusted_executable\(arguments\[0\]\)/)
  assert.doesNotMatch(stats, /run_bounded\(\["(?:sensors|ip|hyprctl|ps)"/)
})

test("weather has an external absolute lifecycle supervisor and QML backstop", () => {
  const runner = source("scripts/run-weather")
  const worker = source("scripts/weather-json")
  const controller = source("services/WeatherController.qml")

  assert.match(runner, /^#!\/usr\/bin\/bash/)
  assert.match(runner, /readonly TIMEOUT=\/usr\/bin\/timeout/)
  assert.match(runner, /export PATH=\/usr\/bin:\/usr\/share\/omarchy\/bin/)
  assert.match(runner, /--signal=TERM --kill-after=1s 10s "\$weather_helper"/)
  assert.match(worker, /^#!\/usr\/bin\/python3/)
  assert.match(controller, /command: \[root\.pluginDir \+ "\/scripts\/run-weather"\]/)
  assert.match(controller, /id: weatherLifecycleBackstop/)
  assert.match(controller, /interval: 12 \* 1000/)
  assert.match(controller, /weatherProcess\.signal\(9\)/)
})

test("ambient PATH entries cannot replace continuously invoked system commands", t => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "omadeck-path-"))
  const marker = path.join(temporary, "executed")
  t.after(() => fs.rmSync(temporary, { recursive: true, force: true }))
  for (const name of ["sensors", "nvidia-smi", "ip", "hyprctl", "ps"]) {
    fs.writeFileSync(
      path.join(temporary, name),
      `#!/usr/bin/bash\n/usr/bin/touch ${JSON.stringify(marker)}\nexit 99\n`,
      { mode: 0o755 },
    )
  }

  const result = spawnSync(path.join(root, "scripts/system-stats"), [], {
    encoding: "utf8",
    env: { ...process.env, PATH: temporary, XDG_RUNTIME_DIR: temporary },
    timeout: 10000,
  })
  assert.equal(result.status, 0, result.stderr)
  assert.equal(fs.existsSync(marker), false)
  assert.doesNotThrow(() => JSON.parse(result.stdout))
})

test("weather supervisor terminates a blocked worker on its wall-clock deadline", t => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "omadeck-weather-"))
  t.after(() => fs.rmSync(temporary, { recursive: true, force: true }))
  fs.writeFileSync(
    path.join(temporary, "run-weather"),
    source("scripts/run-weather").replace("--kill-after=1s 10s", "--kill-after=0.1s 0.1s"),
    { mode: 0o755 },
  )
  fs.writeFileSync(
    path.join(temporary, "weather-json"),
    "#!/usr/bin/bash\n/usr/bin/sleep 30\n",
    { mode: 0o755 },
  )

  const started = Date.now()
  const result = spawnSync(path.join(temporary, "run-weather"), [], {
    encoding: "utf8",
    timeout: 2000,
  })
  assert.equal(result.status, 124, result.stderr)
  assert.ok(Date.now() - started < 1500)
})

test("long-running QML consumers retain only bounded output prefixes", () => {
  const parser = source("components/BoundedOutputParser.qml")
  const weather = source("services/WeatherController.qml")
  const system = source("modules/SystemModule.qml")

  assert.match(parser, /splitMarker: ""/)
  assert.match(parser, /property int maxBytes:/)
  assert.match(parser, /property bool truncated:/)
  assert.match(weather, /stdout: BoundedOutputParser/)
  assert.match(system, /stdout: BoundedOutputParser/)
  assert.doesNotMatch(weather, /stdout: StdioCollector/)
  assert.doesNotMatch(system, /stdout: StdioCollector/)
})
