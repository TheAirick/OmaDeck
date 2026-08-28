const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const repositoryRoot = path.join(__dirname, "..")
const helperSource = fs.readFileSync(
  path.join(repositoryRoot, "modules/MediaArtwork.js"),
  "utf8",
)
const mediaModule = fs.readFileSync(
  path.join(repositoryRoot, "modules/MediaModule.qml"),
  "utf8",
)
const context = {}
vm.runInNewContext(
  `${helperSource}\nthis.api = { trackUrl, youtubeThumbnail };`,
  context,
)

const { trackUrl, youtubeThumbnail } = context.api

test("raw MPRIS metadata supplies the track URL", () => {
  assert.equal(
    trackUrl({ metadata: { "xesam:url": "https://www.youtube.com/watch?v=lVpSU49cdQ0" } }),
    "https://www.youtube.com/watch?v=lVpSU49cdQ0",
  )
  assert.equal(trackUrl(null), "")
})

test("YouTube track URLs recover a standard thumbnail", () => {
  for (const url of [
    "https://www.youtube.com/watch?v=lVpSU49cdQ0",
    "https://youtu.be/lVpSU49cdQ0?t=10",
    "https://www.youtube.com/shorts/lVpSU49cdQ0",
  ]) assert.equal(youtubeThumbnail(url), "https://i.ytimg.com/vi/lVpSU49cdQ0/mqdefault.jpg")

  assert.equal(youtubeThumbnail("https://example.com/watch?v=lVpSU49cdQ0"), "")
})

test("MediaModule retains published art for the same track and falls back to YouTube", () => {
  assert.match(mediaModule, /property string cachedArtworkKey: ""/)
  assert.match(mediaModule, /property string cachedArtworkUrl: ""/)
  assert.match(mediaModule, /readonly property string artworkUrl:/)
  assert.match(mediaModule, /cachedArtworkKey === artworkKey \? cachedArtworkUrl : ""/)
  assert.match(mediaModule, /artworkTrackUrl: MediaArtwork\.trackUrl\(player\)/)
  assert.match(mediaModule, /derivedArtworkUrl: MediaArtwork\.youtubeThumbnail\(artworkTrackUrl\)/)
  assert.match(mediaModule, /source: root\.artworkUrl/)
})
