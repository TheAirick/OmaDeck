const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')

test('real output resolver discards late results during rapid sink changes and disappearance', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'omadeck-audio-resolver-'))
  try {
    fs.mkdirSync(path.join(dir, 'runtime'), { mode: 0o700 })
    const source = fs.readFileSync(path.join(__dirname, '../modules/AudioMixerModule.qml'), 'utf8')
    const functions = source.slice(source.indexOf('  function validSinkName('), source.indexOf('  onLiveStreamsChanged:'))
    const handlers = source.slice(source.indexOf('  onDefaultSinkChanged:'), source.indexOf('  Component.onCompleted:'))
    // Run the production lifecycle with real Process/Timers, replacing only the
    // external resolver command and PipeWire-owned input with synthetic devices.
    const lifecycle = source.slice(source.indexOf('  Process {\n    id: sinkResolver'), source.indexOf('  component VerticalVolume:'))
      .replace(/command: \[[\s\S]*?\]/, 'command: ["/usr/bin/python3", root.helper]')
    fs.copyFileSync(path.join(__dirname, '../components/BoundedOutputParser.qml'), path.join(dir, 'BoundedOutputParser.qml'))
    fs.writeFileSync(path.join(dir, 'resolve.py'), `import pathlib,sys,time
p=pathlib.Path(__file__).with_name('calls')
n=len(p.read_text().splitlines()) if p.exists() else 0
value=['sinkA','sinkC','vanished-output','sinkD'][n]
with p.open('a') as f: f.write(value+'\\n')
time.sleep(0.25)
print(value)
`)
    fs.writeFileSync(path.join(dir, 'shell.qml'), `import QtQuick
import Quickshell
import Quickshell.Io
Item {
  id: root
  property string helper: ${JSON.stringify(path.join(dir, 'resolve.py'))}
  property bool active: false
  property var defaultSink: ({name: "sinkA"})
  property string volumeSinkName: ""
  property int stage: 0
  property int ticks: 0
  function check(ok, message) { if (!ok) { console.log("FAIL " + message); Qt.exit(1) } }
  onVolumeSinkNameChanged: root.check(volumeSinkName !== "sinkA" && volumeSinkName !== "vanished-output", "late result applied")
${functions}
${handlers}
${lifecycle}
  Timer {
    interval: 50; running: true; repeat: true
    onTriggered: {
      root.ticks++
      if (root.stage === 0 && root.ticks > 4) {
        root.check(!sinkResolver.running, "closed startup must not spawn")
        root.active = true; root.stage = 1
      } else if (root.stage === 1 && sinkResolver.running) {
        root.defaultSink = {name: "sinkB"}; root.defaultSink = {name: "sinkC"}; root.stage = 2
      } else if (root.stage === 2 && root.volumeSinkName === "sinkC") {
        root.defaultSink = null; root.stage = 3
      } else if (root.stage === 3 && sinkResolver.running) {
        root.defaultSink = {name: "sinkD"}; root.stage = 4
      } else if (root.stage === 4 && root.volumeSinkName === "sinkD") {
        root.active = false; root.ticks = 0; root.stage = 5
      } else if (root.stage === 5 && root.ticks > 8) {
        root.check(!sinkResolver.running, "no leaked resolver")
        console.log("AUDIO_RESOLVER_PASSED"); Qt.quit()
      }
    }
  }
  Timer { interval: 7000; running: true; onTriggered: { console.log("FAIL timeout stage " + root.stage); Qt.exit(1) } }
}`)
    const env = { ...process.env, HOME: dir, XDG_CONFIG_HOME: path.join(dir, 'config'),
      XDG_CACHE_HOME: path.join(dir, 'cache'), XDG_RUNTIME_DIR: path.join(dir, 'runtime'),
      QT_QPA_PLATFORM: 'offscreen', QT_QPA_PLATFORMTHEME: 'basic', QT_QUICK_BACKEND: 'software', QML_DISABLE_DISK_CACHE: '1' }
    for (const name of ['DBUS_SESSION_BUS_ADDRESS', 'WAYLAND_DISPLAY', 'DISPLAY',
      'QML_IMPORT_PATH', 'QML2_IMPORT_PATH', 'QS_CONFIG_PATH', 'QS_CONFIG_NAME', 'QS_MANIFEST']) delete env[name]
    const result = spawnSync('/usr/bin/qs', ['--no-color', '-p', path.join(dir, 'shell.qml')], {
      env, encoding: 'utf8', timeout: 10000, maxBuffer: 1024 * 1024,
    })
    const output = result.stdout + result.stderr
    assert.equal(result.status, 0, output)
    assert.match(output, /AUDIO_RESOLVER_PASSED/)
    assert.doesNotMatch(output, /FAIL |TypeError|ReferenceError/)
    assert.deepEqual(fs.readFileSync(path.join(dir, 'calls'), 'utf8').split('\n'), ['sinkA', 'sinkC', 'vanished-output', 'sinkD', ''])
  } finally { fs.rmSync(dir, { recursive: true, force: true }) }
})
