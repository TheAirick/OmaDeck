const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const {spawnSync} = require('node:child_process')
const test = require('node:test')
const root = path.resolve(__dirname, '..')

test('custom command launch preserves quoted commands, folders and process ownership', () => {
  const result = spawnSync('/usr/bin/python3', ['tests/test_launcher_command.py'], {cwd: root, encoding: 'utf8', timeout: 10000})
  assert.equal(result.status, 0, result.stdout + result.stderr)
})

test('native launcher migration preserves legacy config and custom buttons survive restart and edits', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'omadeck-launcher-persistence-'))
  try {
    for (const folder of ['services', '.config/omadeck', '.cache', 'runtime']) fs.mkdirSync(path.join(dir, folder), {recursive: true, mode: 0o700})
    for (const file of ['LauncherController.qml', 'LauncherPolicy.js']) fs.copyFileSync(path.join(root, 'services', file), path.join(dir, 'services', file))
    const legacyPath = path.join(dir, '.config/omadeck/launcher.json')
    const legacy = JSON.stringify({version: 1, entries: ['browser', 'desktop:org.example.App']})
    fs.writeFileSync(legacyPath, legacy)
    fs.writeFileSync(path.join(dir, 'shell.qml'), `import QtQuick
import Quickshell
import "./services"
ShellRoot {
  property bool changed: false
  property int ticks: 0
  LauncherController { id: controller }
  Timer {
    interval: 30; running: true; repeat: true
    onTriggered: {
      if (++ticks > 140) { console.error("FIXTURE_TIMEOUT"); Qt.exit(1); return }
      if (!controller.loaded || controller.savePending || controller.saveInFlight) return
      if (!changed) {
        changed = true
        var phase = Quickshell.env("LAUNCHER_PHASE")
        if (phase === "write") controller.saveCommand({name: "Backup", command: "printf '%s' 'quoted value'", directory: "~/Documents", terminal: true, iconId: "backup"}, "")
        else if (phase === "edit") controller.saveCommand(Object.assign({}, controller.customEntries[0], {name: "New name"}), controller.customEntries[0].id)
        else if (phase === "remove") controller.remove(controller.customEntries[0].id)
        return
      }
      console.log("LAUNCHER_STATE " + JSON.stringify({entries: controller.entries(), launched: controller.launching, notice: controller.actionNotice}))
      Qt.quit()
    }
  }
}`)
    const env = {...process.env, HOME: dir, XDG_CONFIG_HOME: path.join(dir, '.config'), XDG_CACHE_HOME: path.join(dir, '.cache'), XDG_RUNTIME_DIR: path.join(dir, 'runtime'), QT_QPA_PLATFORM: 'offscreen', QT_QPA_PLATFORMTHEME: 'basic', QT_QUICK_BACKEND: 'software', QML_DISABLE_DISK_CACHE: '1'}
    for (const name of ['DBUS_SESSION_BUS_ADDRESS', 'WAYLAND_DISPLAY', 'DISPLAY', 'QML_IMPORT_PATH', 'QML2_IMPORT_PATH', 'QS_CONFIG_PATH', 'QS_CONFIG_NAME', 'QS_MANIFEST']) delete env[name]
    function run(phase) {
      const result = spawnSync('/usr/bin/qs', ['--no-color', '-p', path.join(dir, 'shell.qml')], {env: {...env, LAUNCHER_PHASE: phase}, encoding: 'utf8', timeout: 8000})
      const output = result.stdout + result.stderr
      assert.equal(result.status, 0, output)
      assert.doesNotMatch(output, /WARN|FIXTURE_TIMEOUT|Failed to load/)
      const match = output.match(/LAUNCHER_STATE (\{[^\n]+\})/)
      assert.ok(match, output)
      return JSON.parse(match[1])
    }
    const written = run('write')
    assert.equal(written.entries.length, 3)
    assert.equal(written.launched, false)
    assert.equal(written.notice, '')
    assert.deepEqual(run('read'), written)
    const edited = run('edit')
    assert.equal(edited.entries[2].name, 'New name')
    assert.equal(edited.entries[2].id, written.entries[2].id)
    assert.equal(edited.entries[2].command, written.entries[2].command)
    assert.deepEqual(run('read'), edited)
    assert.equal(run('remove').entries.length, 2)
    assert.equal(fs.readFileSync(legacyPath, 'utf8'), legacy)
    assert.equal(JSON.parse(fs.readFileSync(path.join(dir, '.config/omadeck/launcher-v2.json'))).custom.length, 0)
  } finally { fs.rmSync(dir, {recursive: true, force: true}) }
})
