const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const test = require('node:test')
const vm = require('node:vm')
const root = path.resolve(__dirname, '..')
const history = {}
vm.runInNewContext(fs.readFileSync(path.join(root, 'modules/NotificationHistory.js'), 'utf8').replace(/^\.pragma library\s*/m, ''), history)

test('notification reader, confirmation, responsive layout and touch scrolling behave in QML', () => {
  const result = spawnSync('/usr/lib/qt6/bin/qmltestrunner', ['-input', 'tests/qml/tst_notifications.qml', '-import', 'tests/qml/imports'], {
    cwd: root, encoding: 'utf8', timeout: 30000,
    env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software' },
  })
  const output = result.stdout + result.stderr
  assert.equal(result.status, 0, output)
  assert.match(output, /0 failed/)
  assert.doesNotMatch(output, /QWARN|ReferenceError|TypeError/)
})

test('notification presentation rejects external icons and preserves pending identity', () => {
  const rows = history.parseHistory([
    {app: 'Chat', summary: 'Pending', timestamp: 20, originalId: 2, live: true, appIcon: 'org.example.Chat'},
    {app: 'Chat', summary: 'Archived', timestamp: 20, originalId: 2, appIcon: 'https://invalid.example/icon'},
    {app: 'Files', body: 'A'.repeat(40000), timestamp: 10, originalId: 1, appIcon: 'file:///private/image'},
  ].map(JSON.stringify).join('\n'), 12)
  const merged = history.merge([], rows, 12)
  assert.equal(merged.length, 2)
  assert.equal(merged[0].summary, 'Pending')
  assert.equal(merged[0].live, true)
  assert.equal(merged[0].appIcon, 'org.example.Chat')
  assert.equal(merged[1].appIcon, '')
  assert.equal(merged[1].body.length, 32768)
  assert.equal(history.entryKey(merged[0]), '2:20:Chat')
  assert.equal(history.relativeTime(0, Date.now()), 'Recent')
  assert.equal(history.relativeTime(1000, 2000), 'Just now')
  assert.equal(history.relativeTime(1000, 121000), '2m ago')
  assert.equal(history.relativeTime(1000, 7201000), '2h ago')
  assert.equal(history.relativeTime(1000, 172801000), '2d ago')
})

test('public notification command bridge validates commands and partial failures', () => {
  const result = spawnSync('/usr/bin/python3', ['tests/test_notification_control.py'], {cwd: root, encoding: 'utf8', timeout: 10000})
  assert.equal(result.status, 0, result.stdout + result.stderr)
})
