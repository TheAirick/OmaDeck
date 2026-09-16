const assert = require('node:assert/strict')
const {spawnSync} = require('node:child_process')
const test = require('node:test')
const path = require('node:path')
test('launcher app discovery, custom editing, touch keyboard, save and removal work in QML', () => {
  const result = spawnSync('/usr/lib/qt6/bin/qmltestrunner', ['-input', 'tests/qml/tst_launcher.qml', '-import', 'tests/qml/imports'], {
    cwd: path.resolve(__dirname, '..'), encoding: 'utf8', timeout: 30000,
    env: {...process.env, QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software'}
  })
  const output = result.stdout + result.stderr
  assert.equal(result.status, 0, output)
  assert.doesNotMatch(output, /QWARN|TypeError|ReferenceError/)
})
