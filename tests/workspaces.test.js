const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const { spawnSync } = require('node:child_process')
const test = require('node:test')
const policy = fs.readFileSync(path.join(__dirname, '../services/WorkspacePolicy.js'), 'utf8').replace(/^\.pragma library\s*/m, '')
const Policy = vm.runInNewContext(`${policy}\n;({ address, workspaceRows })`)

test('five baseline workspaces adapt to existing and out-of-order window events', () => {
  let rows = Policy.workspaceRows([], [], 2)
  assert.deepEqual(Array.from(rows, row => row.id), [1, 2, 3, 4, 5])
  assert.equal(rows[1].focused, true)
  assert.ok(rows.every(row => !row.occupied))
  rows = Policy.workspaceRows([{ id: 9, monitor: 'DP-2' }, { id: -1337 }, { id: -98 }, { id: 9 }], [
    { workspaceId: 7, address: '0xa', monitor: 'DP-1' },
    { workspaceId: 3, address: '0xb', monitor: 'DP-2' },
    { workspaceId: -98, address: '0xc' },
  ], 7)
  assert.deepEqual(Array.from(rows, row => row.id), [1, 2, 3, 4, 5, 7, 9])
  assert.equal(rows.find(row => row.id === 7).windows[0].address, '0xa')
  assert.equal(rows.find(row => row.id === 3).monitor, 'DP-2')
  assert.ok(!rows.some(row => row.windows.some(window => window.address === '0xc')))
})

test('window addresses cannot become dispatcher expressions', () => {
  assert.equal(Policy.address('ABC123'), '0xabc123')
  assert.equal(Policy.address('0xabc123'), '0xabc123')
  for (const value of ['', '0x0', '0', 'address:0xa', '0xa" }); run()', '../a'])
    assert.equal(Policy.address(value), '')
})

test('real QML Workspaces updates, navigation, scratchpad and touch targets', () => {
  const result = spawnSync('/usr/lib/qt6/bin/qmltestrunner', [
    '-input', 'tests/qml/tst_workspaces.qml', '-import', 'tests/qml/imports',
  ], {
    cwd: path.join(__dirname, '..'), encoding: 'utf8', timeout: 60000,
    env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', QSG_RHI_BACKEND: 'software' },
  })
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`)
  assert.doesNotMatch(result.stdout + result.stderr, /QWARN|QCRITICAL|ReferenceError|TypeError/)
})
