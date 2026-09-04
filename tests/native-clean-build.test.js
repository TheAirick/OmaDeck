const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const crypto = require('node:crypto')
const { execFileSync, spawnSync } = require('node:child_process')

test('native build installs both verified artifacts from tracked source without native/bin', () => {
  const root = path.resolve(__dirname, '..')
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'omadeck-clean-build-'))
  try {
    const files = execFileSync('git', ['ls-files', '-z', 'native', 'scripts/build-native'], {
      cwd: root, encoding: 'utf8'
    }).split('\0').filter(Boolean)
    for (const file of files) {
      const target = path.join(dir, file)
      fs.mkdirSync(path.dirname(target), { recursive: true, mode: 0o700 })
      fs.copyFileSync(path.join(root, file), target)
    }
    assert.equal(fs.existsSync(path.join(dir, 'native/bin')), false)
    fs.mkdirSync(path.join(dir, 'runtime'), { mode: 0o700 })
    const result = spawnSync(path.join(dir, 'scripts/build-native'), [], {
      cwd: dir, encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024,
      env: { ...process.env, XDG_RUNTIME_DIR: path.join(dir, 'runtime'),
        QT_QPA_PLATFORM: 'offscreen', QT_QPA_PLATFORMTHEME: 'basic' }
    })
    assert.equal(result.status, 0, result.stdout + result.stderr + String(result.error || ''))
    const record = fs.readFileSync(path.join(dir, 'native/artifacts.sha256'), 'utf8')
    for (const name of ['OmaDeck/Touch/libomadecktouchplugin.so', 'bin/omadeck-tray']) {
      const artifact = path.join(dir, 'native', name)
      assert.ok(fs.statSync(artifact).mode & 0o100)
      const digest = crypto.createHash('sha256').update(fs.readFileSync(artifact)).digest('hex')
      assert.ok(record.includes(`${digest}  ${name}`), 'installed artifact checksum must match')
    }
  } finally {
    fs.rmSync(dir, { recursive: true, force: true })
  }
})
