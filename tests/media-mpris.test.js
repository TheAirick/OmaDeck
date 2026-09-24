const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')

for (const { cycles, nativeAdapter } of [
  { cycles: 1, nativeAdapter: false },
  { cycles: 100, nativeAdapter: false },
  { cycles: 1, nativeAdapter: true },
]) test(nativeAdapter
  ? 'native MPRIS fallback controls the exact displayed player without host service access'
  : cycles === 1
  ? 'real MPRIS targets the displayed source, respects capabilities and survives player removal'
  : '100 real MPRIS appearance/removal and QML recreation cycles release resources', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'omadeck-mpris-'))
  try {
    fs.mkdirSync(path.join(dir, 'runtime'), { mode: 0o700 })
    fs.mkdirSync(path.join(dir, 'imports'))
    // Mock appearance only. Discovery and player objects use installed Quickshell.
    fs.cpSync(path.join(__dirname, 'qml/imports/qs'), path.join(dir, 'imports/qs'), { recursive: true })
    for (const file of ['NowPlayingModule.qml', 'MediaArtwork.js'])
      fs.copyFileSync(path.join(__dirname, '../modules', file), path.join(dir, file))
    fs.copyFileSync(path.join(__dirname, '../services/WatchSource.js'), path.join(dir, 'WatchSource.js'))
    fs.cpSync(path.join(__dirname, '../theme'), path.join(dir, 'theme'), { recursive: true })
    const nowPlayingPath = path.join(dir, 'NowPlayingModule.qml')
    fs.writeFileSync(nowPlayingPath, fs.readFileSync(nowPlayingPath, 'utf8')
      .replace('../theme', 'theme')
      .replace('../services/WatchSource.js', 'WatchSource.js'))
    fs.copyFileSync(path.join(__dirname, '../services/MprisMediaAdapter.qml'), path.join(dir, 'MprisMediaAdapter.qml'))
    fs.copyFileSync(path.join(__dirname, 'fixtures/mpris-players.py'), path.join(dir, 'players.py'))
    fs.writeFileSync(path.join(dir, 'shell.qml'), `import QtQuick
import Quickshell
import Quickshell.Services.Mpris
Item {
  id: root
  property int stage: 0
  property int completed: 0
  readonly property var card: cardLoader.item
  function check(ok, message) { if (!ok) { console.log("FAIL " + message); Qt.exit(1) } }
  ${nativeAdapter ? `MprisMediaAdapter {
    id: mediaService
    preferredPlayerKey: "org.mpris.MediaPlayer2.fixtureB"
  }` : `QtObject {
    id: mediaService
    readonly property var players: Mpris.players.values
    readonly property var activePlayer: playerForKey("org.mpris.MediaPlayer2.fixtureB") || players[0] || null
    function playerKey(player) { return player.dbusName }
    function playerForKey(key) {
      for (var i = 0; i < players.length; i++) if (playerKey(players[i]) === key) return players[i]
      return null
    }
    // Model Omarchy's global fallback: without an exact key it can choose A
    // even when the card presents B. The production presenter must supply B.
    function runAction(action, feedback, key) {
      var player = playerForKey(key) || playerForKey("org.mpris.MediaPlayer2.fixtureA")
      if (!player) return false
      if (action === "playPause") player.pause()
      else if (action === "next") player.next()
      return true
    }
  }`}
  Loader {
    id: cardLoader
    sourceComponent: Component { NowPlayingModule { media: mediaService; width: 500; height: 400 } }
  }
  Timer {
    interval: 50; running: true; repeat: true
    onTriggered: {
      if (root.stage === 0 && mediaService.players.length === 2 && card.canPlayPause && card.player.canQuit
          && card.player.trackTitle === "Fixture B") {
        root.check(card.runTransport("playPause"), "targeted pause"); root.stage = 1
      } else if (root.stage === 1 && !card.player.isPlaying && !card.canPlayPause) {
        root.check(!card.runTransport("playPause"), "disabled transport")
        root.check(card.playbackStatus.indexOf("unavailable") !== -1, "unsupported status")
        card.player.quit(); root.stage = 2
      } else if (root.stage === 2 && mediaService.players.length === 1 && card.player.trackTitle === "Fixture A"
          && card.player.canGoNext && card.player.canQuit) {
        root.check(card.runTransport("next"), "remaining source")
        card.player.quit(); root.stage = 3
      } else if (root.stage === 3 && mediaService.players.length === 0) {
        root.check(!card.hasPlayer && !card.runTransport("playPause"), "removed source")
        root.check(card.playbackStatus === "No media player detected", "empty status")
        card.media = null
        root.check(card.playbackStatus === "Media service unavailable", "service unavailable")
        root.completed++
        if (root.completed === ${cycles}) { console.log("MPRIS_INTEGRATION_PASSED"); Qt.quit() }
        else { cardLoader.active = false; root.stage = 4 }
      } else if (root.stage === 4) {
        cardLoader.active = true; root.stage = 0
      }
    }
  }
  Timer { interval: ${Math.max(10000, cycles * 800)}; running: true; onTriggered: { console.log("FAIL timeout stage " + root.stage); Qt.exit(1) } }
}`)
    const env = { ...process.env, HOME: dir, XDG_CONFIG_HOME: path.join(dir, 'config'),
      XDG_CACHE_HOME: path.join(dir, 'cache'), XDG_RUNTIME_DIR: path.join(dir, 'runtime'),
      QT_QPA_PLATFORM: 'offscreen', QT_QPA_PLATFORMTHEME: 'basic', QT_QUICK_BACKEND: 'software',
      OMADECK_MPRIS_CYCLES: String(cycles), QML_DISABLE_DISK_CACHE: '1', QML_IMPORT_PATH: path.join(dir, 'imports') }
    for (const name of ['DBUS_SESSION_BUS_ADDRESS', 'WAYLAND_DISPLAY', 'DISPLAY',
      'QML2_IMPORT_PATH', 'QS_CONFIG_PATH', 'QS_CONFIG_NAME', 'QS_MANIFEST']) delete env[name]
    const result = spawnSync('/usr/bin/dbus-run-session', ['/usr/bin/python3',
      path.join(dir, 'players.py'), path.join(dir, 'shell.qml')], {
      env, encoding: 'utf8', timeout: Math.max(16000, cycles * 800 + 4000), maxBuffer: 1024 * 1024,
    })
    const output = result.stdout + result.stderr
    assert.equal(result.status, 0, output || JSON.stringify(result))
    assert.match(output, /MPRIS_INTEGRATION_PASSED/)
    assert.doesNotMatch(output, /FAIL |TypeError|ReferenceError|Binding loop/)
    const calls = JSON.parse(output.match(/MPRIS_CALLS (\[[^\n]+\])/)[1])
    assert.deepEqual(calls, Array.from({ length: cycles }, () =>
      [['B', 'Pause'], ['B', 'Quit'], ['A', 'Next'], ['A', 'Quit']]).flat())
    if (cycles > 1) {
      const samples = JSON.parse(output.match(/MPRIS_RESOURCES (\[[^\n]+\])/)[1]).slice(10)
      assert.equal(samples.length, cycles - 11)
      for (const field of ['fixtureFds', 'shellFds']) {
        const values = samples.map(sample => sample[field])
        assert.ok(Math.max(...values) - Math.min(...values) <= 2, `${field} must plateau after warmup: ${values}`)
      }
      assert.ok(samples.every(sample => sample.shellChildren.length === 0), 'no leaked shell helper processes')
    }
  } finally { fs.rmSync(dir, { recursive: true, force: true }) }
})
