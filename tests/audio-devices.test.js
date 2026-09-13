const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const { spawnSync } = require('node:child_process')
const path = require('node:path')
const root = path.resolve(__dirname, '..')
const policy = vm.createContext({})
vm.runInContext(fs.readFileSync(path.join(root, 'services/AudioDevices.js'), 'utf8'), policy)

test('device snapshots exclude streams and monitor capture and keep no node references', () => {
  const output = { id: 1, name: 'qr65', description: 'QR65', isSink: true, audio: {} }
  const input = { id: 2, name: 'alias', description: 'Alias Pro', isSink: false, audio: {} }
  const nodes = [null, output, input, {...output, isStream: true},
    {...input, name: 'qr65.monitor'}, {...input, name: 'quickshell'},
    {id: 3, name: 'camera', isSink: false}]
  const outputs = JSON.parse(JSON.stringify(policy.snapshot(nodes, 'output')))
  assert.deepEqual(outputs, [{id: '1', name: 'qr65', label: 'QR65'}])
  assert.equal(policy.snapshot(nodes, 'input').length, 1)
  output.description = 'changed'
  assert.equal(outputs[0].label, 'QR65')
  assert.equal(policy.find(nodes, 'input', 1, 'qr65'), null)
  assert.equal(policy.find(nodes, 'output', 1, 'reused-id'), null)
  assert.equal(policy.find(nodes, 'output', 1, 'qr65'), output)
})

test('device switch confirms actual defaults, serializes taps, and handles removal and failures', () => {
  const result = spawnSync('/usr/lib/qt6/bin/qmltestrunner', [
    '-input', 'tests/qml/tst_audio-devices.qml', '-import', 'tests/qml/imports'
  ], {cwd: root, encoding: 'utf8', timeout: 15000, env: {...process.env,
    QT_QPA_PLATFORM: 'offscreen', QT_QPA_PLATFORMTHEME: 'basic', QT_QUICK_BACKEND: 'software'}})
  assert.equal(result.status, 0, result.stdout + result.stderr)
  assert.doesNotMatch(result.stdout + result.stderr, /QWARN|QCRITICAL|QFATAL/)
})
