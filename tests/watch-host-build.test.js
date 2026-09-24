const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const {spawnSync} = require('node:child_process')

test('optional Watch host builds and loads its WebEngine QML in isolation', {timeout: 180000}, () => {
  const lab = fs.mkdtempSync(path.join(os.tmpdir(), 'omadeck-watch-build-'))
  try {
    const run = (command, args, extra = {}) => {
      const result = spawnSync(command, args, {encoding: 'utf8', timeout: 120000,
        maxBuffer: 4 * 1024 * 1024, ...extra})
      assert.equal(result.status, 0, String(result.error || '') + result.stdout + result.stderr)
      return result.stdout
    }
    run('cmake', ['-S', path.resolve(__dirname, '../native/watch'), '-B', lab, '-DCMAKE_BUILD_TYPE=Release'])
    run('cmake', ['--build', lab, '--parallel', '2'])
    const runtime = path.join(lab, 'runtime'); fs.mkdirSync(runtime, {mode: 0o700})
    const bus = path.join(lab, 'bus.conf')
    fs.writeFileSync(bus, '<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen><policy context="default"><allow send_destination="*"/><allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
    const env = {...process.env, XDG_RUNTIME_DIR: runtime, QT_QPA_PLATFORM: 'offscreen',
      QT_QPA_PLATFORMTHEME: 'basic', QT_QUICK_BACKEND: 'software', QSG_RHI_BACKEND: 'software',
      GTK_USE_PORTAL: '0', QTWEBENGINE_CHROMIUM_FLAGS: '--disable-gpu --mute-audio'}
    delete env.WAYLAND_DISPLAY; delete env.DISPLAY
    delete env.DBUS_SESSION_BUS_ADDRESS
    assert.match(run('dbus-run-session', ['--config-file=' + bus, '--', path.join(lab, 'omadeck-watch-host'), '--probe'], {env}), /PROBE loaded/)
  } finally { fs.rmSync(lab, {recursive: true, force: true}) }
})
