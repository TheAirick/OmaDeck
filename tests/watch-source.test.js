const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

const source = fs.readFileSync(path.join(__dirname, '../services/WatchSource.js'), 'utf8')
  .replace(/^\.pragma library\s*/m, '')
const WatchSource = vm.runInNewContext(`${source}\n;({ youtubeVideoId, candidate })`)

test('accepts standard YouTube watch links from different MPRIS browser identities', () => {
  for (const key of ['org.mpris.MediaPlayer2.firefox.instance_1',
    'org.mpris.MediaPlayer2.chromium.instance_2']) {
    const value = WatchSource.candidate({
      metadata: { 'xesam:url': 'https://www.youtube.com/watch?list=PL123&v=M7lc1UVf-VE' },
      position: 123.8,
      isPlaying: true
    }, key)
    assert.deepEqual({ ...value }, {
      videoId: 'M7lc1UVf-VE', seconds: 123, sourceKey: key,
      sourceWasPlaying: true
    })
  }
  assert.equal(WatchSource.youtubeVideoId('https://youtu.be/M7lc1UVf-VE?t=120'), 'M7lc1UVf-VE')
})

test('rejects unsupported and deceptive URLs before offering a handoff', () => {
  for (const url of [
    'http://www.youtube.com/watch?v=M7lc1UVf-VE',
    'https://youtube.com.evil.test/watch?v=M7lc1UVf-VE',
    'https://youtube.com@evil.test/watch?v=M7lc1UVf-VE',
    'https://www.youtube.com/watch?v=short',
    'https://www.youtube.com/shorts/M7lc1UVf-VE',
    'https://example.com/video'
  ]) assert.equal(WatchSource.youtubeVideoId(url), '')
  assert.equal(WatchSource.candidate({ metadata: { 'xesam:url':
    'https://www.youtube.com/watch?v=M7lc1UVf-VE' } }, ''), null)
})

test('returns only bounded source data and tolerates missing position', () => {
  const value = WatchSource.candidate({
    metadata: {
      'xesam:url': 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
      'xesam:title': 'private title'
    },
    position: NaN,
    isPlaying: false
  }, 'browser-key')
  assert.deepEqual(Object.keys(value).sort(),
    ['seconds', 'sourceKey', 'sourceWasPlaying', 'videoId'].sort())
  assert.equal(value.seconds, 0)
  assert.equal(value.sourceWasPlaying, false)
})
