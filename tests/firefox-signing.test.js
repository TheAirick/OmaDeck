const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { execFileSync, spawnSync } = require('node:child_process')
const { createHash } = require('node:crypto')

const root = path.resolve(__dirname, '..')
const extension = 'browser/watch-extension/'
const files = ['scripts/prepare-firefox-signing', 'scripts/package-release',
  'manifest.json', 'LICENSE', 'docs/FIREFOX_SIGNING.md', 'docs/FIREFOX_REVIEWER_NOTES.md',
  ...['manifest.firefox.json', 'manifest.chromium.json', 'background.js', 'content.js',
    'PRIVACY.md', 'README.md', 'firefox-updates.json'].map(name => extension + name)]
const hash = bytes => createHash('sha256').update(bytes).digest('hex')

function fixture(t) {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'omadeck-signing-'))
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }))
  for (const file of files) {
    fs.mkdirSync(path.dirname(path.join(folder, file)), { recursive: true })
    fs.copyFileSync(path.join(root, file), path.join(folder, file))
  }
  const git = (...args) => execFileSync('git', ['-C', folder, ...args], { encoding: 'utf8' }).trim()
  git('init', '-q')
  git('config', 'user.name', 'Signing Test')
  git('config', 'user.email', 'signing-test@example.invalid')
  git('config', 'commit.gpgsign', 'false')
  git('add', '.')
  git('commit', '-qm', 'fixture')
  const prepare = output => spawnSync('python3', [path.join(folder, 'scripts/prepare-firefox-signing'),
    '--output', path.join(folder, output)], { encoding: 'utf8' })
  return { folder, git, prepare }
}

test('submission is reproducible, committed-only, checksummed and agrees with release ZIP', t => {
  const { folder, git, prepare } = fixture(t)
  const commit = git('rev-parse', 'HEAD')
  const original = fs.readFileSync(path.join(folder, extension + 'content.js'), 'utf8')
  fs.writeFileSync(path.join(folder, extension + 'content.js'), 'UNCOMMITTED PRIVATE FIXTURE')
  fs.writeFileSync(path.join(folder, extension + 'secret.txt'), 'MUST NOT PACKAGE')
  for (const output of ['first', 'second']) {
    const result = prepare(output)
    assert.equal(result.status, 0, result.stderr)
  }
  const first = path.join(folder, 'first')
  const metadata = JSON.parse(fs.readFileSync(path.join(first, 'submission.json')))
  assert.equal(metadata.commit, commit)
  assert.equal(metadata.signed, false)
  assert.equal(metadata.channel, 'unlisted')
  for (const name of fs.readdirSync(first))
    assert.deepEqual(fs.readFileSync(path.join(first, name)), fs.readFileSync(path.join(folder, 'second', name)))
  for (const line of fs.readFileSync(path.join(first, 'SHA256SUMS'), 'utf8').trim().split('\n')) {
    const [expected, name] = line.split('  ')
    assert.equal(hash(fs.readFileSync(path.join(first, name))), expected)
  }
  const inspect = execFileSync('python3', ['-c',
    'import json,sys,zipfile; z=zipfile.ZipFile(sys.argv[1]); print(json.dumps({n:z.read(n).decode() for n in z.namelist()}))',
    path.join(first, metadata.upload)], { encoding: 'utf8' })
  const contents = JSON.parse(inspect)
  assert.deepEqual(Object.keys(contents).sort(),
    ['LICENSE', 'PRIVACY.md', 'README.md', 'background.js', 'content.js', 'manifest.json'].sort())
  assert.equal(contents['content.js'], original)
  const manifest = JSON.parse(contents['manifest.json'])
  assert.equal(manifest.browser_specific_settings.gecko.id, metadata.addonId)
  assert.equal(manifest.browser_specific_settings.gecko.update_url, metadata.updateUrl)
  execFileSync('python3', [path.join(folder, 'scripts/package-release'), '--output', path.join(folder, 'release')])
  assert.deepEqual(fs.readFileSync(path.join(first, metadata.upload)),
    fs.readFileSync(path.join(folder, 'release', `omadeck-watch-firefox-v${metadata.version}.zip`)))
})

test('preparation preserves existing kits and rejects mismatched release versions', t => {
  const { folder, git, prepare } = fixture(t)
  assert.equal(prepare('kit').status, 0)
  const before = fs.readFileSync(path.join(folder, 'kit', 'SHA256SUMS'))
  const again = prepare('kit')
  assert.notEqual(again.status, 0)
  assert.match(again.stderr, /must be empty/)
  assert.deepEqual(fs.readFileSync(path.join(folder, 'kit', 'SHA256SUMS')), before)
  const manifestPath = path.join(folder, extension + 'manifest.firefox.json')
  const manifest = JSON.parse(fs.readFileSync(manifestPath))
  manifest.version = '9.9.9'
  fs.writeFileSync(manifestPath, JSON.stringify(manifest))
  git('add', extension + 'manifest.firefox.json')
  git('commit', '-qm', 'wrong version')
  const result = prepare('bad')
  assert.notEqual(result.status, 0)
  assert.match(result.stderr, /versions must match/)
  assert.equal(fs.existsSync(path.join(folder, 'bad')), false)
})

test('signing preparation rejects missing consent instead of creating an upload', t => {
  const { folder, git, prepare } = fixture(t)
  const manifestPath = path.join(folder, extension + 'manifest.firefox.json')
  const manifest = JSON.parse(fs.readFileSync(manifestPath))
  delete manifest.browser_specific_settings.gecko.data_collection_permissions
  fs.writeFileSync(manifestPath, JSON.stringify(manifest))
  git('add', extension + 'manifest.firefox.json')
  git('commit', '-qm', 'missing consent')
  const result = prepare('bad')
  assert.notEqual(result.status, 0)
  assert.match(result.stderr, /consent declarations/)
  assert.equal(fs.existsSync(path.join(folder, 'bad')), false)
})
