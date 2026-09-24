const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')

test('real System snapshot lifecycle stays idle when closed and recovers failed starts and stale data', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'omadeck-system-refresh-'))
  try {
    const source = fs.readFileSync(path.join(__dirname, '../modules/SystemModule.qml'), 'utf8')
    const state = source.slice(source.indexOf('  property bool active:'), source.indexOf('  property var shell:'))
    const processBlock = source.slice(source.indexOf('  Process {\n    id: statsProcess'), source.indexOf('  FileView {'))
    const timers = source.slice(source.indexOf('  Timer {\n    id: statsRefreshTimer'), source.indexOf('  Component.onCompleted: if (active)'))
    fs.mkdirSync(path.join(dir, 'runtime'), { mode: 0o700 })
    fs.mkdirSync(path.join(dir, 'scripts'))
    fs.copyFileSync(path.join(__dirname, '../components/BoundedOutputParser.qml'), path.join(dir, 'BoundedOutputParser.qml'))
    fs.writeFileSync(path.join(dir, 'scripts/system-stats'), `#!/usr/bin/python3
import json,pathlib,signal,time,os
p=pathlib.Path(__file__).parent/'count'
n=int(p.read_text())+1 if p.exists() else 1
p.write_text(str(n))
if n == 2:
    print('{bad-json')
elif n == 5:
    print('x' * (512 * 1024))
elif n == 6:
    (p.parent/'hung-pid').write_text(str(os.getpid()))
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    time.sleep(30)
else:
    print(json.dumps(dict(performance=dict(cpu=n,gpu=0,memory=0),network=dict(down=0,up=0),storage={},clients=[],clipboard=[])))
`, { mode: 0o700 })
    fs.writeFileSync(path.join(dir, 'shell.qml'), `import QtQuick
import Quickshell
import Quickshell.Io
Item {
  id: root
  property string pluginDir: ${JSON.stringify(dir)}
  property var stats: ({})
  property var clientAddresses: []
  property var clipboardRows: []
  property var cpuHistory: []
  property var gpuHistory: []
  property var memoryHistory: []
  property var downloadHistory: []
  property var uploadHistory: []
  function appendSample(history, value) { return history.concat([Number(value || 0)]).slice(-45) }
${state}
${processBlock}
${timers}
  property int stage: 0
  property int ticks: 0
  property double savedStamp: 0
  property var savedCommand: []
  function check(ok, message) { if (!ok) { console.log("FAIL " + message); Qt.exit(1) } }
  Timer {
    interval: 50; running: true; repeat: true
    onTriggered: {
      root.ticks++
      if (root.stage === 0 && root.ticks > 5) {
        root.check(!root.statsBusy && root.lastUpdatedMs === 0 && !statsProcess.running, "closed startup")
        root.active = true; root.stage = 1
      } else if (root.stage === 1 && root.lastUpdatedMs > 0) {
        root.check(root.stats.performance.cpu === 1, "first snapshot")
        root.savedStamp = root.lastUpdatedMs
        root.active = false; root.ticks = 0; root.stage = 2
      } else if (root.stage === 2 && root.ticks > 45) {
        root.check(root.lastUpdatedMs === root.savedStamp && !statsProcess.running, "hidden polling")
        root.active = true; root.stage = 3
      } else if (root.stage === 3 && root.statsError !== "") {
        root.check(root.stats.performance.cpu === 1 && root.lastUpdatedMs === root.savedStamp, "preserve last good")
        root.check(root.statsStatus.indexOf("Update failed") === 0, "visible failure")
        root.requestStats(); root.stage = 4
      } else if (root.stage === 4 && !root.statsBusy && root.statsError === "") {
        root.check(root.stats.performance.cpu === 3, "successful recovery")
        root.savedCommand = statsProcess.command
        statsProcess.command = ["/missing-omadeck-fixture-command"]
        root.requestStats(); root.stage = 5
      } else if (root.stage === 5 && !root.statsBusy && root.statsError !== "") {
        root.check(root.stats.performance.cpu === 3, "failed start retains data")
        statsProcess.command = root.savedCommand
        root.requestStats(); root.stage = 6
      } else if (root.stage === 6 && !root.statsBusy && root.statsError === "") {
        root.check(root.stats.performance.cpu === 4 && root.statsFailures === 0, "failed start recovery")
        root.statusNowMs = root.lastUpdatedMs + 7000
        root.check(root.statsStale && root.statsStatus.indexOf("Stale") === 0, "age indicates staleness")
        root.savedStamp = root.lastUpdatedMs
        root.requestStats(); root.stage = 7
      } else if (root.stage === 7 && !root.statsBusy && root.statsError !== "") {
        root.check(statsOutput.truncated && statsOutput.text.length <= 256 * 1024, "bounded oversized response")
        root.check(root.stats.performance.cpu === 4 && root.lastUpdatedMs === root.savedStamp, "oversize preserves snapshot")
        root.requestStats(); root.ticks = 0; root.stage = 8
      } else if (root.stage === 8 && !root.statsBusy && root.statsError !== "") {
        root.check(root.ticks > 200 && root.ticks < 320, "whole-helper kill deadline")
        root.check(root.lastUpdatedMs === root.savedStamp, "timeout preserves snapshot")
        root.requestStats(); root.stage = 9
      } else if (root.stage === 9 && !root.statsBusy && root.statsError === "") {
        root.check(root.stats.performance.cpu === 7 && !statsOutput.truncated, "timeout and overflow recovery")
        console.log("SYSTEM_REFRESH_PASSED"); Qt.quit()
      }
    }
  }
  Timer { interval: 25000; running: true; onTriggered: { console.log("FAIL timeout stage " + root.stage); Qt.exit(1) } }
}`)
    const env = { ...processEnv(dir) }
    const result = spawnSync('/usr/bin/qs', ['--no-color', '-p', path.join(dir, 'shell.qml')], {
      env, encoding: 'utf8', timeout: 28000, maxBuffer: 1024 * 1024,
    })
    const output = result.stdout + result.stderr
    assert.equal(result.status, 0, output)
    assert.match(output, /SYSTEM_REFRESH_PASSED/)
    const hungPid = Number(fs.readFileSync(path.join(dir, 'scripts/hung-pid'), 'utf8'))
    assert.throws(() => process.kill(hungPid, 0), { code: 'ESRCH' }, 'timed-out helper must be reaped')
    assert.doesNotMatch(output, /FAIL |TypeError|ReferenceError/)
  } finally { fs.rmSync(dir, { recursive: true, force: true }) }
})

function processEnv(dir) {
  const env = { ...process.env, HOME: dir, XDG_CONFIG_HOME: path.join(dir, 'config'),
    XDG_CACHE_HOME: path.join(dir, 'cache'), XDG_RUNTIME_DIR: path.join(dir, 'runtime'),
    QT_QPA_PLATFORM: 'offscreen', QT_QPA_PLATFORMTHEME: 'basic', QT_QUICK_BACKEND: 'software', QML_DISABLE_DISK_CACHE: '1' }
  for (const name of ['DBUS_SESSION_BUS_ADDRESS', 'WAYLAND_DISPLAY', 'DISPLAY',
    'QML_IMPORT_PATH', 'QML2_IMPORT_PATH', 'QS_CONFIG_PATH', 'QS_CONFIG_NAME', 'QS_MANIFEST']) delete env[name]
  return env
}
