const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const net = require('node:net')
const { spawn } = require('node:child_process')
const vm = require('node:vm')

const root = path.join(__dirname, '..')

function contentFixture(play) {
  const video = { currentTime: 43.5, paused: false, ended: false,
    pause() { this.paused = true }, play() { this.paused = false; return play() } }
  let listener, expire
  const context = {
    globalThis: { chrome: { runtime: {
      sendMessage: async () => {}, onMessage: { addListener: fn => { listener = fn } },
    } } },
    location: { href: 'https://www.youtube.com/watch?v=M7lc1UVf-VE' },
    document: { querySelector: () => video, addEventListener: () => {} },
    URL, Promise, Date, setInterval: () => {},
    setTimeout: (fn, ms) => {
      const timer = setTimeout(fn, ms)
      if (ms === 6000) expire = () => { clearTimeout(timer); fn() }
      return timer
    }, clearTimeout,
  }
  vm.runInNewContext(fs.readFileSync(path.join(root, 'browser/watch-extension/content.js'), 'utf8'), context)
  return { video, context, expire: () => expire(),
    command: message => new Promise(resolve => listener({ type: 'command',
      videoId: 'M7lc1UVf-VE', ...message }, {}, resolve)) }
}

test('tab pause captures the actual timestamp and resume rejects a changed video', async () => {
  const fixture = contentFixture(async () => {})
  const paused = await fixture.command({ action: 'pause' })
  assert.equal(paused.ok, true)
  assert.equal(paused.seconds, 43.5)
  fixture.context.location.href = 'https://www.youtube.com/watch?v=jNQXAC9IVRw'
  const changed = await fixture.command({ action: 'resume', seconds: 55, wasPlaying: true })
  assert.equal(changed.ok, false)
  assert.equal(fixture.video.currentTime, 43.5)
  assert.equal(fixture.video.paused, true)
})

test('a stalled browser Return pauses the source before reporting failure', async () => {
  const fixture = contentFixture(() => new Promise(() => {}))
  const result = fixture.command({ action: 'resume', seconds: 55, wasPlaying: true })
  assert.equal(fixture.video.paused, false)
  fixture.expire()
  assert.equal((await result).ok, false)
  assert.equal(fixture.video.paused, true)
})

test('Return retries when the page restores its old playhead after play resolves', async () => {
  let plays = 0
  const fixture = contentFixture(async () => {
    if (++plays === 1) setTimeout(() => { fixture.video.currentTime = 43.5 }, 20)
  })
  const result = await fixture.command({ action: 'resume', seconds: 120, wasPlaying: true })
  assert.equal(result.ok, true)
  assert.equal(plays, 2)
  assert.equal(fixture.video.currentTime, 120)
})

test('Return rejects a browser that repeatedly restores the old playhead', async () => {
  const fixture = contentFixture(async () => {
    setTimeout(() => { fixture.video.currentTime = 43.5 }, 20)
  })
  const result = await fixture.command({ action: 'resume', seconds: 120, wasPlaying: true })
  assert.equal(result.ok, false)
  assert.equal(fixture.video.paused, true)
})

test('Return restores the original paused state without starting browser audio', async () => {
  const fixture = contentFixture(() => { throw new Error('Should not play') })
  const result = await fixture.command({ action: 'resume', seconds: 55, wasPlaying: false })
  assert.equal(result.ok, true)
  assert.equal(fixture.video.currentTime, 55)
  assert.equal(fixture.video.paused, true)
})

function frame(message) {
  const body = Buffer.from(JSON.stringify(message))
  const size = Buffer.alloc(4)
  size.writeUInt32LE(body.length)
  return Buffer.concat([size, body])
}

test('native messaging relay carries bounded browser candidates and exact tab commands', async () => {
  const runtime = fs.mkdtempSync(path.join(os.tmpdir(), 'omadeck-watch-relay-'))
  fs.chmodSync(runtime, 0o700)
  const socketPath = path.join(runtime, 'omadeck-browser-watch.sock')
  const server = net.createServer()
  let child
  try {
    await new Promise((resolve, reject) => {
      server.once('error', reject)
      server.listen(socketPath, resolve)
    })
    const accepted = new Promise(resolve => server.once('connection', resolve))
    child = spawn(path.join(root, 'scripts/browser-watch-native-host'), [], {
      env: { ...process.env, XDG_RUNTIME_DIR: runtime }, stdio: ['pipe', 'pipe', 'pipe'],
    })
    const deck = await accepted
    const browserLine = new Promise(resolve => deck.once('data', data => resolve(data.toString())))
    child.stdin.write(frame({ type: 'hello', browser: 'chromium' }))
    assert.deepEqual(JSON.parse((await browserLine).trim()), { type: 'hello', browser: 'chromium' })

    const candidateLine = new Promise(resolve => deck.once('data', data => resolve(data.toString())))
    child.stdin.write(frame({ type: 'candidate', videoId: 'M7lc1UVf-VE',
      seconds: 42.5, tabId: 17, playing: true }))
    assert.deepEqual(JSON.parse((await candidateLine).trim()), { type: 'candidate',
      videoId: 'M7lc1UVf-VE', seconds: 42.5, tabId: 17, playing: true })

    const browserReply = new Promise(resolve => child.stdout.once('data', resolve))
    deck.write(JSON.stringify({ type: 'command', action: 'pause', requestId: 2,
      videoId: 'M7lc1UVf-VE', tabId: 17, seconds: 42, wasPlaying: true }) + '\n')
    const reply = await browserReply
    const length = reply.readUInt32LE(0)
    assert.deepEqual(JSON.parse(reply.subarray(4, 4 + length).toString()), {
      type: 'command', action: 'pause', requestId: 2,
      videoId: 'M7lc1UVf-VE', tabId: 17, seconds: 42, wasPlaying: true,
    })
    const closedLine = new Promise(resolve => deck.once('data', data => resolve(data.toString())))
    child.stdin.write(frame({ type: 'sourceClosed', tabId: 17 }))
    assert.deepEqual(JSON.parse((await closedLine).trim()), { type: 'sourceClosed', tabId: 17 })
    child.stdin.end()
    await new Promise(resolve => child.once('exit', resolve))
    assert.equal(child.exitCode, 0)
    deck.destroy()
  } finally {
    if (child && child.exitCode === null) child.kill()
    server.close()
    fs.rmSync(runtime, { recursive: true, force: true })
  }
})

test('both browser packages share the same tab handoff code', () => {
  const extension = path.join(root, 'browser/watch-extension')
  const firefox = JSON.parse(fs.readFileSync(path.join(extension, 'manifest.firefox.json')))
  const chromium = JSON.parse(fs.readFileSync(path.join(extension, 'manifest.chromium.json')))
  for (const manifest of [firefox, chromium]) {
    assert.deepEqual(manifest.permissions, ['nativeMessaging'])
    assert.equal(manifest.content_scripts[0].js[0], 'content.js')
  }
  assert.equal(firefox.background.scripts[0], 'background.js')
  assert.equal(chromium.background.service_worker, 'background.js')
})

test('extension retains background media and clears only closed or navigated sources', async () => {
  const listeners = {}
  const sent = []
  let reconnect, now = Date.now()
  const port = {
    postMessage: message => sent.push(message),
    onMessage: { addListener: callback => { listeners.native = callback } },
    onDisconnect: { addListener: callback => { listeners.disconnect = callback } },
  }
  const event = name => ({ addListener: callback => { listeners[name] = callback } })
  const api = {
    runtime: {
      getManifest: () => ({}), connectNative: () => port,
      onMessage: event('report'), onConnect: event('page'),
    },
    tabs: {
      query: async () => [{ id: 17 }],
      sendMessage: async (id, message) => ({ ok: id === 17 && message.videoId === 'M7lc1UVf-VE' }),
      onRemoved: event('removed'), onUpdated: event('updated'),
      onActivated: event('activated'),
    },
  }
  vm.runInNewContext(fs.readFileSync(path.join(root, 'browser/watch-extension/background.js'), 'utf8'),
    { globalThis: { chrome: api }, URL, Promise, Date: { now: () => now },
      setTimeout: (fn, delay) => {
        if (delay === 2000) { reconnect = fn; return 0 }
        return setTimeout(fn, delay)
      }, clearTimeout })
  const report = { type: 'candidate', videoId: 'M7lc1UVf-VE', seconds: 42, playing: true }
  listeners.report(report, { tab: { id: 17 }, url: 'https://example.com/watch?v=M7lc1UVf-VE' })
  await new Promise(resolve => setImmediate(resolve))
  assert.equal(sent.length, 1)
  listeners.report(report, { tab: { id: 17 }, url: 'https://www.youtube.com/watch?v=M7lc1UVf-VE' })
  await new Promise(resolve => setImmediate(resolve))
  assert.deepEqual({ ...sent[1] }, { ...report, tabId: 17 })
  listeners.native({ type: 'command', action: 'pause', requestId: 3,
    tabId: 17, videoId: 'M7lc1UVf-VE' })
  await new Promise(resolve => setImmediate(resolve))
  assert.deepEqual({ ...sent[2] }, { type: 'ack', requestId: 3, ok: true })
  listeners.activated?.({ tabId: 18 })
  assert.equal(sent.length, 3, 'switching tabs retains the media source')
  listeners.removed(17)
  assert.deepEqual({ ...sent[3] }, { type: 'clear' })
  const pageMessages = []
  const page = { name: 'omadeck-watch-page',
    sender: { url: 'https://www.youtube.com/watch?v=M7lc1UVf-VE' },
    postMessage: message => pageMessages.push(message),
    onMessage: event('pageReport'), onDisconnect: event('pageClosed') }
  listeners.page(page)
  listeners.pageReport({ ...report, visible: false })
  assert.equal(sent[4].tabId, 1000000, 'playing background document works without Zen sender.tab')
  const commanded = listeners.native({ type: 'command', action: 'resume', requestId: 4,
    tabId: 1000000, videoId: report.videoId, seconds: 88, wasPlaying: true })
  assert.equal(pageMessages[0].seconds, 88)
  listeners.pageReport({ type: 'ack', requestId: 4, ok: true, seconds: 88.1 })
  await commanded
  assert.deepEqual({ ...sent[5] }, { type: 'ack', requestId: 4, ok: true, seconds: 88.1 })
  listeners.pageReport({ ...report, playing: false, seconds: 89, visible: false })
  assert.equal(sent[6].type, 'candidate', 'scratchpad occlusion must retain the selected video')
  assert.equal(sent[6].seconds, 89)
  now += 120000
  listeners.disconnect()
  reconnect()
  assert.deepEqual({ ...sent[7] }, { type: 'hello', browser: 'chromium' })
  assert.equal(sent[8].type, 'candidate', 'shell restart retains a connected, throttled document')
  assert.equal(sent[8].tabId, 1000000)
  listeners.pageClosed()
  assert.deepEqual({ ...sent[9] }, { type: 'clear' })
  assert.deepEqual({ ...sent[10] }, { type: 'sourceClosed', tabId: 1000000 })
})
