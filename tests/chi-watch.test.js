const test = require('node:test')
const assert = require('node:assert/strict')
const { spawnSync } = require('node:child_process')
const path = require('node:path')
test('Chi Watch refuses ambiguity and stale documents and sequences confirmed controls', () => {
  const result = spawnSync('/usr/lib/qt6/bin/qmltestrunner', [
    '-input', 'tests/qml/tst_chi-watch.qml', '-import', 'tests/qml/imports'
  ], { cwd: path.join(__dirname, '..'), encoding: 'utf8', timeout: 15000,
    env: {...process.env, QT_QPA_PLATFORM: 'offscreen', QSG_RHI_BACKEND: 'software'} })
  assert.equal(result.status, 0, result.stdout + result.stderr)
  assert.doesNotMatch(result.stdout + result.stderr, /QWARN|QCRITICAL|QFATAL/)
})
