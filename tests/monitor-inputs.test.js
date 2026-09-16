const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const os = require('node:os')
const path = require('node:path')
const test = require('node:test')
const { spawnSync } = require('node:child_process')

const policy = {}
vm.runInNewContext(fs.readFileSync('services/MonitorInputPolicy.js', 'utf8').replace(/^\.pragma library\s*/m, ''), policy)
const fixture = () => ({ version: 1, enabled: true, selectedId: 'a'.repeat(64), monitors: [
  { id: 'a'.repeat(64), label: 'Office', sources: [{ code: '0f', label: 'Desktop' }, { code: '11', label: 'Laptop' }] }
] })

test('monitor switching defaults off and stores only bounded hardware/input choices', () => {
  assert.equal(policy.defaults().enabled, false)
  assert.equal(policy.defaults().monitors.length, 0)
  const settings = policy.normalize({ ...fixture(), arbitraryCommand: 'ignored' })
  assert.equal(settings.monitors[0].sources[1].label, 'Laptop')
  assert.equal(settings.arbitraryCommand, undefined)
  settings.selectedId = 'missing'
  assert.equal(policy.normalize(settings).selectedId, 'a'.repeat(64))
})

test('malformed monitor settings cannot become input commands', () => {
  for (const mutate of [
    state => { state.version = 2 },
    state => { state.monitors.push(state.monitors[0]) },
    state => { state.monitors[0].id = '--bus=1' },
    state => { state.monitors[0].sources[0].code = '11;exit' },
    state => { state.monitors[0].sources[0].label = 'bad\nname' },
    state => { state.monitors[0].sources = [] },
    state => { state.monitors[0].sources.push(state.monitors[0].sources[0]) },
  ]) { const state = fixture(); mutate(state); assert.equal(policy.normalize(state), null) }
  assert.equal(policy.parse('broken json'), null)
})

test('DDC discovery and switching survive identity changes and reject ambiguous hardware', () => {
  const result = spawnSync('python3', ['tests/monitor_inputs_test.py'], { encoding: 'utf8', timeout: 10000 })
  assert.equal(result.status, 0, result.stdout + result.stderr)
})

test('guided setup identifies missing prerequisites and stops after failed installation', () => {
  const result = spawnSync('python3', ['tests/monitor_setup_test.py'], { encoding: 'utf8', timeout: 10000 })
  assert.equal(result.status, 0, result.stdout + result.stderr)
})

test('monitor preferences add inputs, save labels, remove monitors and retain touch targets', () => {
  const result = spawnSync('/usr/lib/qt6/bin/qmltestrunner', ['-input', 'tests/qml/tst_monitor-inputs.qml', '-import', 'tests/qml/imports'], {
    encoding: 'utf8', timeout: 15000, env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', QSG_RHI_BACKEND: 'software' }
  })
  assert.equal(result.status, 0, result.stdout + result.stderr)
  assert.doesNotMatch(result.stdout + result.stderr, /QWARN|QFATAL/)
})

test('real monitor controller persists settings and reports helper failures across recreation', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'omadeck-monitor-settings-'))
  try {
    for (const directory of ['.config', '.cache', 'runtime', 'fixture/services', 'fixture/scripts'])
      fs.mkdirSync(path.join(home, directory), { recursive: true, mode: 0o700 })
    const fixtureRoot = path.join(home, 'fixture')
    for (const name of ['MonitorInputController.qml', 'MonitorInputPolicy.js'])
      fs.copyFileSync(path.join('services', name), path.join(fixtureRoot, 'services', name))
    fs.writeFileSync(path.join(fixtureRoot, 'shell.qml'), fs.readFileSync('tests/qml/real-monitor-inputs/shell.qml', 'utf8').replace('../../../services', './services'))
    fs.writeFileSync(path.join(fixtureRoot, 'scripts/monitor_setup.py'), `import json, os, sys
failed = os.environ.get('OMADECK_MONITOR_PHASE') == 'check-failure'
print(json.dumps({'ok':False,'error':'Fixture setup check failed'} if failed else {'ok':True,'state':'ready','canPrepare':True}))
sys.exit(1 if failed else 0)
`)
    fs.writeFileSync(path.join(fixtureRoot, 'scripts/monitor_inputs.py'), `import json, sys
if sys.argv[1] == 'scan':
 print(json.dumps({'ok':True,'monitors':[{'id':'a'*64,'label':'Office','error':'','inputs':[{'code':'0f','label':'DisplayPort 1'},{'code':'11','label':'HDMI 1'}]}]}))
else:
 print(json.dumps({'ok':False,'error':'Fixture monitor disconnected'}))
 sys.exit(1)
`)
    const env = { ...process.env, HOME: home, XDG_CONFIG_HOME: path.join(home, '.config'), XDG_CACHE_HOME: path.join(home, '.cache'),
      XDG_RUNTIME_DIR: path.join(home, 'runtime'), QT_QPA_PLATFORM: 'offscreen', QT_QPA_PLATFORMTHEME: 'basic', QSG_RHI_BACKEND: 'software',
      OMADECK_MONITOR_FIXTURE: fixtureRoot }
    for (const key of ['DBUS_SESSION_BUS_ADDRESS', 'WAYLAND_DISPLAY', 'DISPLAY', 'QML_IMPORT_PATH', 'QML2_IMPORT_PATH', 'QS_CONFIG_PATH', 'QS_CONFIG_NAME', 'QS_MANIFEST']) delete env[key]
    function run(phase) {
      const result = spawnSync('/usr/bin/qs', ['--no-color', '-p', path.join(fixtureRoot, 'shell.qml')], {
        encoding: 'utf8', timeout: 12000, env: { ...env, OMADECK_MONITOR_PHASE: phase }
      })
      const output = result.stdout + result.stderr
      assert.equal(result.status, 0, output)
      assert.doesNotMatch(output, /MONITOR_FAILURE|Failed to load configuration|ReferenceError|TypeError/)
      const match = output.match(/MONITOR_STATE (\{[^\n]+\})/)
      assert.ok(match, output)
      return JSON.parse(match[1])
    }
    assert.deepEqual(run('read'), JSON.parse(JSON.stringify(policy.defaults())))
    assert.deepEqual(run('check'), JSON.parse(JSON.stringify(policy.defaults())))
    assert.deepEqual(run('check-failure'), JSON.parse(JSON.stringify(policy.defaults())))
    const written = run('write')
    assert.equal(written.enabled, true)
    assert.equal(written.monitors[0].sources[1].label, 'Laptop')
    assert.deepEqual(run('read'), written)
    const settingsPath = path.join(home, '.config/omadeck/monitors.json')
    fs.writeFileSync(settingsPath, 'invalid settings')
    assert.equal(run('read').enabled, false)
    assert.equal(fs.readFileSync(settingsPath, 'utf8'), 'invalid settings')
  } finally { fs.rmSync(home, { recursive: true, force: true }) }
})
