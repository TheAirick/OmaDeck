const assert = require("node:assert/strict")
const childProcess = require("node:child_process")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const test = require("node:test")

const repositoryRoot = path.join(__dirname, "..")

function source(relativePath) {
  return fs.readFileSync(path.join(repositoryRoot, relativePath), "utf8")
}

test("MediaModule hosts one lifecycle-free NowPlayingModule boundary", () => {
  const modulePath = path.join(repositoryRoot, "modules/NowPlayingModule.qml")
  assert.equal(fs.existsSync(modulePath), true, "NowPlayingModule.qml must exist")

  const mediaModule = source("modules/MediaModule.qml")
  const nowPlayingModule = source("modules/NowPlayingModule.qml")

  assert.equal((mediaModule.match(/NowPlayingModule\s*\{/g) || []).length, 1)
  assert.match(mediaModule, /NowPlayingModule\s*\{[\s\S]*media:\s*root\.media/)
  assert.match(nowPlayingModule, /property var media:\s*null/)
  assert.match(nowPlayingModule, /readonly property var player:\s*media \? media\.activePlayer : null/)

  for (const forbidden of [
    /AudioMixerModule/,
    /Quickshell\.Services\.Pipewire|\bPipewire\b|\bPwNode\b|\bPwObjectTracker\b/,
    /\bProcess\s*\{|\bFileView\s*\{|IpcHandler|settings|persistence|Qt\.createComponent/i,
  ]) {
    assert.doesNotMatch(nowPlayingModule, forbidden)
  }
})

test("NowPlayingModule owns the complete local player projection state", () => {
  const mediaModule = source("modules/MediaModule.qml")
  const nowPlayingModule = source("modules/NowPlayingModule.qml")

  for (const contract of [
    /readonly property bool hasPlayer:/,
    /readonly property bool canSkip:/,
    /readonly property string trackKey:/,
    /property real displayedPosition:\s*0/,
    /property real cachedLength:\s*0/,
    /property bool seeking:\s*false/,
    /property bool optimisticPosition:\s*false/,
    /function captureDuration\(\)/,
    /function seekTo\(value\)/,
    /function skip\(seconds\)/,
    /Timer\s*\{[\s\S]*interval:\s*500[\s\S]*running:\s*root\.hasPlayer/,
    /Connections\s*\{[\s\S]*target:\s*root\.player/,
  ]) {
    assert.match(nowPlayingModule, contract)
    assert.doesNotMatch(mediaModule, contract)
  }

  assert.equal((nowPlayingModule.match(/\bTimer\s*\{/g) || []).length, 1)
  assert.equal((nowPlayingModule.match(/\bConnections\s*\{/g) || []).length, 1)
})

test("NowPlayingModule owns same-track artwork recovery without prior-track leakage", () => {
  const mediaModule = source("modules/MediaModule.qml")
  const nowPlayingModule = source("modules/NowPlayingModule.qml")

  for (const contract of [
    /property string cachedArtworkKey:\s*""/,
    /property string cachedArtworkUrl:\s*""/,
    /readonly property string artworkTrackUrl:\s*MediaArtwork\.trackUrl\(player\)/,
    /readonly property string derivedArtworkUrl:\s*MediaArtwork\.youtubeThumbnail\(artworkTrackUrl\)/,
    /cachedArtworkKey === artworkKey \? cachedArtworkUrl : ""/,
    /function captureArtwork\(\)/,
  ]) {
    assert.match(nowPlayingModule, contract)
    assert.doesNotMatch(mediaModule, contract)
  }
})

test("NowPlayingModule owns the compact full-height player presentation", () => {
  const mediaModule = source("modules/MediaModule.qml")
  const nowPlayingModule = source("modules/NowPlayingModule.qml")

  for (const presentation of [
    /id:\s*artwork/,
    /id:\s*artworkImage/,
    /id:\s*metadataOverlay/,
    /id:\s*controlBand/,
    /id:\s*controls/,
    /id:\s*playPauseControl/,
    /id:\s*timeline/,
    /PanelSlider\s*\{/,
  ]) {
    assert.match(nowPlayingModule, presentation)
    assert.doesNotMatch(mediaModule, presentation)
  }
})

test("Now Playing is static while Volume owns the left drawer", () => {
  const mediaModule = source("modules/MediaModule.qml")
  const volumeModule = source("modules/VolumeModule.qml")
  const deckSurface = source("components/DeckSurface.qml")

  assert.equal((mediaModule.match(/NowPlayingModule\s*\{/g) || []).length, 1)
  assert.equal((mediaModule.match(/AudioMixerModule\s*\{/g) || []).length, 0)
  assert.equal((mediaModule.match(/DeckCard\s*\{/g) || []).length, 1)
  assert.match(mediaModule, /objectName:\s*"nowPlayingPanelCard"[\s\S]*title:\s*"Now Playing"[\s\S]*NowPlayingModule\s*\{/)
  assert.equal((volumeModule.match(/AudioMixerModule\s*\{/g) || []).length, 1)
  assert.equal((volumeModule.match(/NowPlayingModule\s*\{/g) || []).length, 0)
  assert.match(volumeModule, /objectName:\s*"audioMixerPanelCard"[\s\S]*title:\s*"Volume"[\s\S]*AudioMixerModule\s*\{/)
  assert.match(volumeModule, /readonly property real preferredDrawerWidth:/)
  assert.match(volumeModule, /function setMixerCompact\(compact\) \{ mixer\.compact = compact \}/)
  assert.match(volumeModule, /function setMixerCategory\(category\)/)
  assert.match(deckSurface, /MediaModule\s*\{\s*id:\s*staticMedia/)
  assert.match(deckSurface, /VolumeModule\s*\{\s*id:\s*volumeDrawer/)
  assert.match(deckSurface, /readonly property int staticMediaWidth:/)
  assert.match(deckSurface, /reservedLeft:\s*root\.staticMediaReserve \+ root\.reservedLeft/)
})

const qmlTestRunner = "/usr/lib/qt6/bin/qmltestrunner"
test("offscreen NowPlaying controls and disabled lifecycle states remain valid", {
  skip: !fs.existsSync(qmlTestRunner),
}, () => {
  const result = childProcess.spawnSync(qmlTestRunner, [
    "-input",
    "tests/qml/tst_now-playing-module-render.qml",
    "-import",
    "tests/qml/imports",
  ], {
    cwd: repositoryRoot,
    encoding: "utf8",
    env: {
      ...process.env,
      QT_QPA_PLATFORM: "offscreen",
      QSG_RHI_BACKEND: "software",
    },
  })
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`)
  assert.match(result.stdout, /0 failed/)
  assert.doesNotMatch(result.stdout + result.stderr, /QWARN|QCRITICAL|QFATAL/)
})

test("offscreen actual DeckSurface path renders separate media panels", {
  skip: !fs.existsSync(qmlTestRunner),
}, () => {
  const qmlTestPath = path.join(repositoryRoot, "tests/qml/tst_deck-surface-media.qml")
  assert.equal(fs.existsSync(qmlTestPath), true, "DeckSurface media-panel test must exist")

  const testRoot = fs.mkdtempSync(path.join(os.tmpdir(), "omadeck-deck-surface-"))
  try {
    const generatedComponents = path.join(testRoot, "components")
    fs.mkdirSync(generatedComponents)
    for (const entry of fs.readdirSync(path.join(repositoryRoot, "components"))) {
      if (entry === "DeckSurface.qml") continue
      fs.symlinkSync(path.join(repositoryRoot, "components", entry), path.join(generatedComponents, entry))
    }
    fs.symlinkSync(path.join(repositoryRoot, "modules"), path.join(testRoot, "modules"))

    const touchFixture = `  QtObject {\n    id: directTouch\n    property bool touchInProgress: false\n    property bool active: false\n    property string devicePath: ""\n    property var deviceNames: []\n    property string status: "test"\n    property var window: null\n    function start() {}\n    function stop() {}\n  }`
    const deckSurface = source("components/DeckSurface.qml")
      .replace(/^import Quickshell.*\n/gm, "")
      .replace(/^import "\.\.\/native\/OmaDeck\/Touch".*\n/m, "")
      .replace("PanelWindow {", "Rectangle {\n  property var screen: ({ name: \"DP-3\" })")
      .replace(/^  anchors \{ top: true; right: true; bottom: true; left: true \}\n/m, "")
      .replace(/^  exclusionMode:.*\n/m, "")
      .replace(/^  WlrLayershell\..*\n/gm, "")
      .replace(/  NativeTouch\.TouchBridge \{[\s\S]*?\n  \}/, touchFixture)
    fs.writeFileSync(path.join(generatedComponents, "DeckSurface.qml"), deckSurface, { flag: "wx" })

    const generatedTestPath = path.join(testRoot, "tst_deck-surface-media.qml")
    const generatedTest = fs.readFileSync(qmlTestPath, "utf8")
      .replace('import "../../components" as Components', 'import "components" as Components')
    fs.writeFileSync(generatedTestPath, generatedTest, { flag: "wx" })

    const result = childProcess.spawnSync(qmlTestRunner, [
      "-input",
      generatedTestPath,
      "-import",
      "tests/qml/imports",
    ], {
      cwd: repositoryRoot,
      encoding: "utf8",
      env: {
        ...process.env,
        QT_QPA_PLATFORM: "offscreen",
        QSG_RHI_BACKEND: "software",
      },
    })

    assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`)
    assert.match(result.stdout, /0 failed/)
    assert.doesNotMatch(result.stdout + result.stderr, /QWARN|QCRITICAL|QFATAL/)
  } finally {
    fs.rmSync(testRoot, { recursive: true, force: true })
  }
})
