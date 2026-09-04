const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')

test('actual QML controllers recover from injected I/O failures', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'omadeck-recovery-'))
  const root = path.resolve(__dirname, '..')
  try {
    for (const folder of ['services', 'components'])
      fs.cpSync(path.join(root, folder), path.join(dir, folder), { recursive: true })
    fs.cpSync(path.join(__dirname, 'qml/imports'), path.join(dir, 'imports'), { recursive: true })
    fs.cpSync(path.join(__dirname, 'recovery'), dir, { recursive: true })
    // IDs remain private in production; name only the test copies for fault injection.
    for (const name of ['Timer', 'Weather', 'Layout', 'Launcher']) {
      const file = path.join(dir, 'services', name + 'Controller.qml')
      fs.writeFileSync(file, fs.readFileSync(file, 'utf8').replace(/^(\s*)id: (\w+)$/gm, '$1id: $2\n$1objectName: "$2"'))
    }
    const service = fs.readFileSync(path.join(root, 'Service.qml'), 'utf8')
    // Exercise the actual tray owner functions and QML lifecycle handlers,
    // without loading the desktop, native bridge, IPC or other service owners.
    const tray = `import QtQuick\nimport Quickshell.Io\nItem {\n id: root
      property bool unloading: false
      property string pluginDir: "/fixture"
      property int trayRestartFailures: 0
      property string targetScreen: ""
      property string primaryMonitor: ""
      property var touchDeviceNames: []
      QtObject { id: hardwareStore; property bool loaded: true }
      ${service.slice(service.indexOf('  function startTray()'), service.indexOf('  Component.onCompleted:'))}
      ${service.slice(service.indexOf('  Process {\n    id: trayController'), service.indexOf('  IpcHandler {'))}
    }`
    fs.writeFileSync(path.join(dir, 'TrayOwner.qml'), tray.replace(/^(\s*)id: (\w+)$/gm, '$1id: $2\n$1objectName: "$2"'))
    const result = spawnSync('/usr/lib/qt6/bin/qmltestrunner', ['-input', dir, '-import', path.join(dir, 'imports')], {
      encoding: 'utf8', timeout: 40000,
      env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software' }
    })
    assert.equal(result.status, 0, result.stdout + result.stderr)
  } finally { fs.rmSync(dir, { recursive: true, force: true }) }
})
