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

test("NowPlayingModule owns the unchanged player presentation", () => {
  const mediaModule = source("modules/MediaModule.qml")
  const nowPlayingModule = source("modules/NowPlayingModule.qml")

  for (const presentation of [
    /id:\s*hero/,
    /id:\s*artwork/,
    /id:\s*artworkImage/,
    /id:\s*controls/,
    /id:\s*playPauseControl/,
    /id:\s*transportControls/,
    /id:\s*timeline/,
    /PanelSlider\s*\{/,
  ]) {
    assert.match(nowPlayingModule, presentation)
    assert.doesNotMatch(mediaModule, presentation)
  }
})

test("MediaModule preserves combined heading mixer and player geometry", () => {
  const mediaModule = source("modules/MediaModule.qml")

  assert.equal((mediaModule.match(/NowPlayingModule\s*\{/g) || []).length, 1)
  assert.equal((mediaModule.match(/AudioMixerModule\s*\{/g) || []).length, 1)
  assert.match(mediaModule, /Text\s*\{\s*id:\s*heading[\s\S]*text:\s*"Media"/)
  assert.match(mediaModule, /AudioMixerModule\s*\{[\s\S]*anchors\.top:\s*heading\.bottom/)
  assert.match(mediaModule, /NowPlayingModule\s*\{[\s\S]*anchors\.bottomMargin:\s*mixer\.contentHeight \+ Style\.spacing\.controlGap/)
  assert.match(mediaModule, /function setMixerCompact\(compact\) \{ mixer\.compact = compact \}/)
  assert.match(mediaModule, /function setMixerCategory\(category\)/)
})

const qmlTestRunner = "/usr/lib/qt6/bin/qmltestrunner"
test("offscreen full Media composition preserves render and interaction parity", {
  skip: !fs.existsSync(qmlTestRunner),
}, () => {
  const qmlTestPath = path.join(repositoryRoot, "tests/qml/tst_now-playing-module-render.qml")
  assert.equal(fs.existsSync(qmlTestPath), true, "Now Playing render-parity test must exist")

  const baselineDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "omadeck-now-playing-"))
  const acceptedSource = childProcess.execFileSync(
    "git",
    ["show", "76783ab4cd2a32a439485345cc397d44fcf44862:modules/MediaModule.qml"],
    { cwd: repositoryRoot, encoding: "utf8" },
  )
    .replace('import "MediaArtwork.js" as MediaArtwork', `import "file:${path.join(repositoryRoot, "modules/MediaArtwork.js")}" as MediaArtwork`)
    .replace("  AudioMixerModule {", "  Modules.AudioMixerModule {")
  try {
    fs.writeFileSync(
      path.join(baselineDirectory, "AcceptedMediaModule.qml"),
      `import "file:${path.join(repositoryRoot, "modules")}" as Modules\n${acceptedSource}`,
      { flag: "wx" },
    )
    const generatedTestPath = path.join(baselineDirectory, "tst_now-playing-module-render.qml")
    const generatedTest = fs.readFileSync(qmlTestPath, "utf8")
      .replace('import "../../modules" as Modules', `import "file:${path.join(repositoryRoot, "modules")}" as Modules`)
      .replace('Qt.resolvedUrl("../../assets/screenshots/media.png")', `"file:${path.join(repositoryRoot, "assets/screenshots/media.png")}"`)
    fs.writeFileSync(generatedTestPath, generatedTest, { flag: "wx" })

    const result = childProcess.spawnSync(qmlTestRunner, [
      "-silent",
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
  } finally {
    fs.rmSync(baselineDirectory, { recursive: true, force: true })
  }
})
