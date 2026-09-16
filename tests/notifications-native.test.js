const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawn } = require('node:child_process')

test('real notification watcher follows arrivals, edits, archiving, close/reopen and owner clear', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'omadeck-notifications-'))
  const root = path.resolve(__dirname, '..')
  const popup = path.join(dir, '.local/state/omarchy/notifications')
  const history = path.join(popup, 'history')
  let child
  try {
    for (const name of ['services', 'components', 'modules', 'scripts', 'runtime', '.config', '.cache', '.local/state/omarchy/notifications/history'])
      fs.mkdirSync(path.join(dir, name), {recursive: true, mode: 0o700})
    for (const name of ['services/NotificationController.qml', 'components/BoundedOutputParser.qml', 'modules/NotificationHistory.js', 'scripts/notification-history'])
      fs.copyFileSync(path.join(root, name), path.join(dir, name))
    fs.copyFileSync(path.join(__dirname, 'notifications-native.qml'), path.join(dir, 'shell.qml'))
    // Substitute only the command bridge. The real controller, file reader and
    // Qt directory watchers run unchanged, without access to the desktop bus.
    fs.writeFileSync(path.join(dir, 'scripts/notification_control.py'), `import json, os, pathlib, sys
state = pathlib.Path(os.environ['HOME']) / '.local/state/omarchy/notifications'
if sys.argv[1] == 'clear':
    for directory in (state, state / 'history'):
        for entry in directory.glob('*.json'): entry.unlink()
print(json.dumps(dict(ok=True, dndAvailable=True, nightAvailable=True, dnd=False, night=False)))
`)
    const write = (directory, timestamp, body) => fs.writeFileSync(path.join(directory, timestamp + '-1.json'), JSON.stringify({app: 'Fixture', summary: 'Fixture message', body, timestamp, originalId: 1}), {mode: 0o600})
    write(history, 1000, 'Archived body')
    let output = ''
    const seen = new Set()
    const env = {...process.env, HOME: dir, XDG_CONFIG_HOME: path.join(dir, '.config'), XDG_CACHE_HOME: path.join(dir, '.cache'), XDG_STATE_HOME: path.join(dir, '.local/state'), XDG_RUNTIME_DIR: path.join(dir, 'runtime'), QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software', QT_QPA_PLATFORMTHEME: 'basic', QML_DISABLE_DISK_CACHE: '1'}
    for (const name of ['DBUS_SESSION_BUS_ADDRESS', 'WAYLAND_DISPLAY', 'DISPLAY', 'QML_IMPORT_PATH', 'QML2_IMPORT_PATH', 'QS_CONFIG_PATH', 'QS_CONFIG_NAME', 'QS_MANIFEST']) delete env[name]
    child = spawn('/usr/bin/qs', ['--no-color', '-p', path.join(dir, 'shell.qml')], {env})
    const receive = chunk => {
      output += chunk
      for (const marker of ['HISTORY_READ', 'POPUP_READ', 'POPUP_UPDATED', 'DRAWER_CLOSED']) {
        if (!output.includes(marker) || seen.has(marker)) continue
        seen.add(marker)
        if (marker === 'HISTORY_READ') write(popup, 2000, 'Pending body')
        if (marker === 'POPUP_READ') write(popup, 2000, 'Updated body')
        if (marker === 'POPUP_UPDATED') fs.renameSync(path.join(popup, '2000-1.json'), path.join(history, '2000-1.json'))
        if (marker === 'DRAWER_CLOSED') write(history, 3000, 'Arrived while closed')
      }
    }
    child.stdout.on('data', receive); child.stderr.on('data', receive)
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => { child.kill('SIGKILL'); reject(new Error(output)) }, 15000)
      child.on('error', error => { clearTimeout(timer); reject(error) })
      child.on('exit', code => { clearTimeout(timer); code === 0 ? resolve() : reject(new Error(output)) })
    })
    assert.match(output, /NOTIFICATIONS_VERIFIED/)
    assert.doesNotMatch(output, /NOTIFICATION_FAILURE|WARN|ReferenceError|TypeError/)
    assert.equal(fs.readdirSync(history).length, 0)
    assert.deepEqual(fs.readdirSync(popup), ['history'])
  } finally {
    if (child && child.exitCode === null) child.kill('SIGKILL')
    fs.rmSync(dir, {recursive: true, force: true})
  }
})
