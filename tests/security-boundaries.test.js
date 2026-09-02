const assert = require("node:assert/strict")
const fs = require("node:fs")
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
  const service = source("Service.qml")

  assert.match(runner, /exec 9< "\$tray_binary"/)
  assert.match(runner, /sha256sum \/proc\/self\/fd\/9/)
  assert.match(runner, /setpriv --pdeathsig TERM \/proc\/self\/fd\/9/)
  assert.match(service, /trayRestartFailures/)
  assert.match(service, /Math\.min\(30000/)
  assert.match(service, /trayController\.signal\(9\)/)
  assert.match(service, /Component\.onDestruction/)
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
