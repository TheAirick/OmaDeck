const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawn } = require('node:child_process')

test('installed Quickshell retries real failed writes and failed starts in a private HOME', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'omadeck-native-recovery-'))
  const config = path.join(dir, '.config/omadeck')
  fs.mkdirSync(config, { recursive: true })
  fs.mkdirSync(path.join(dir, 'runtime'), { mode: 0o700 })
  const root = path.resolve(__dirname, '..')
  let child
  try {
    fs.mkdirSync(path.join(dir, 'services'))
    fs.mkdirSync(path.join(dir, 'components'))
    for (const name of ['Layout', 'Launcher', 'Timer', 'Weather', 'Hardware']) {
      for (const suffix of ['Controller.qml', 'Policy.js'])
        fs.copyFileSync(path.join(root, 'services', name + suffix), path.join(dir, 'services', name + suffix))
    }
    fs.copyFileSync(path.join(root, 'components/BoundedOutputParser.qml'), path.join(dir, 'components/BoundedOutputParser.qml'))
    fs.copyFileSync(path.join(root, 'services/AppearanceController.qml'), path.join(dir, 'services/AppearanceController.qml'))
    // The controller is unchanged except its effect executables. Never send a
    // desktop notification or play audio, even if sound restoration regresses.
    const timerPath = path.join(dir, 'services/TimerController.qml')
    let timer = fs.readFileSync(timerPath, 'utf8')
    timer = timer.replace(/command: \["\/usr\/bin\/timeout"[\s\S]*?"OmaDeck timer finished"\]/,
      'command: ["/usr/bin/true"]\n    onStarted: console.log("TEST_ALERT")')
    timer = timer.replace(/command: TimerPolicy.playbackCommand\([^\n]+/g, 'command: ["/usr/bin/true"]')
    fs.writeFileSync(timerPath, timer)
    const values = {
      'layout.json': {version: 2, root: {type: 'split', orientation: 'horizontal', ratio: 0.36,
        first: {type: 'module', moduleId: 'clock'}, second: {type: 'module', moduleId: 'command-center'}}},
      'launcher.json': {version: 1, entries: ['terminal', 'browser']},
      'timer.json': {version: 1, status: 'active', originalDurationMs: 60000,
        currentDurationMs: 60000, deadlineMs: Date.now() - 1000, pausedRemainingMs: 0, notificationSent: false},
      'timer-settings.json': {version: 1, eventId: ''},
      'appearance.json': {version: 1, use24Hour: false},
      'hardware.json': {version: 1, targetScreen: 'fixture-old', primaryMonitor: 'fixture-old', touchDeviceNames: ['Fixture Touch']}
    }
    for (const [name, value] of Object.entries(values))
      fs.writeFileSync(path.join(config, name), JSON.stringify(value), { mode: 0o400 })
    fs.copyFileSync(path.join(__dirname, 'recovery-native.qml'), path.join(dir, 'shell.qml'))
    let output = ''
    let recoveredPermissions = false
    const env = { ...process.env, HOME: dir, XDG_CONFIG_HOME: path.join(dir, '.config'),
      XDG_STATE_HOME: path.join(dir, 'state'), XDG_CACHE_HOME: path.join(dir, 'cache'),
      XDG_RUNTIME_DIR: path.join(dir, 'runtime'), QT_QPA_PLATFORM: 'offscreen',
      QT_QPA_PLATFORMTHEME: 'basic', QT_QUICK_BACKEND: 'software', QML_DISABLE_DISK_CACHE: '1' }
    for (const name of ['DBUS_SESSION_BUS_ADDRESS', 'WAYLAND_DISPLAY', 'DISPLAY',
      'QML_IMPORT_PATH', 'QML2_IMPORT_PATH', 'QS_CONFIG_PATH', 'QS_CONFIG_NAME', 'QS_MANIFEST']) delete env[name]
    child = spawn('/usr/bin/qs', ['--no-color', '-p', path.join(dir, 'shell.qml')], { env })
    const receive = chunk => {
      output += chunk
      if (!recoveredPermissions && output.includes('FAULTS_OBSERVED')) {
        recoveredPermissions = true
        for (const name of Object.keys(values)) fs.chmodSync(path.join(config, name), 0o600)
      }
    }
    child.stdout.on('data', receive)
    child.stderr.on('data', receive)
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => { child.kill('SIGKILL'); reject(new Error(output)) }, 15000)
      child.on('error', error => { clearTimeout(timer); reject(error) })
      child.on('exit', code => { clearTimeout(timer); code === 0 ? resolve() : reject(new Error(output)) })
    })
    assert.ok(recoveredPermissions, output)
    assert.match(output, /RECOVERED/, output)
    assert.equal((output.match(/TEST_ALERT/g) || []).length, 1, output)
    assert.equal(JSON.parse(fs.readFileSync(path.join(config, 'timer.json'))).notificationSent, true)
    assert.equal(JSON.parse(fs.readFileSync(path.join(config, 'layout.json'))).root.ratio, 0.6)
    assert.equal(JSON.parse(fs.readFileSync(path.join(config, 'launcher.json'))).entries.length, 1)
    assert.equal(JSON.parse(fs.readFileSync(path.join(config, 'appearance.json'))).use24Hour, true)
    assert.equal(JSON.parse(fs.readFileSync(path.join(config, 'hardware.json'))).targetScreen, 'fixture-new')
  } finally {
    if (child && child.exitCode === null) child.kill('SIGKILL')
    fs.rmSync(dir, { recursive: true, force: true })
  }
})
