const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const nowPlayingModule = fs.readFileSync(
  path.join(__dirname, "..", "modules/NowPlayingModule.qml"),
  "utf8",
)

test("playback controls form one compact touch row", () => {
  assert.match(nowPlayingModule, /Row \{\s*id: controls/)
  assert.match(nowPlayingModule, /readonly property bool showSecondarySeek:\s*true/)
  assert.match(nowPlayingModule, /id: playPauseControl[\s\S]*width: Style\.space\(72\); height: Style\.space\(72\)/)
  assert.match(nowPlayingModule, /id: playPauseControl[\s\S]*iconSize: Style\.font\.displayLarge \* 2/)
  assert.equal((nowPlayingModule.match(/width: Style\.space\(52\); height: Style\.space\(72\)/g) || []).length, 4)
  assert.equal((nowPlayingModule.match(/iconSize: Style\.font\.iconLarge \* 2\.2/g) || []).length, 2)
  assert.match(nowPlayingModule, /component CircularSeekIcon:\s*Canvas/)
  assert.match(nowPlayingModule, /width:\s*Style\.space\(34\)[\s\S]*height:\s*Style\.space\(34\)/)
  assert.match(nowPlayingModule, /context\.lineWidth = Style\.space\(3\)/)
  assert.match(nowPlayingModule, /objectName: "seekBackwardControl"[\s\S]*root\.skip\(-10\)[\s\S]*CircularSeekIcon \{[\s\S]*forward:\s*false/)
  assert.match(nowPlayingModule, /objectName: "seekForwardControl"[\s\S]*root\.skip\(10\)[\s\S]*CircularSeekIcon \{[\s\S]*forward:\s*true/)
  assert.equal((nowPlayingModule.match(/color: "transparent"; borderSpec: Border\.none\(\)/g) || []).length, 5)
})

test("centered artwork overlays metadata above a dedicated controls and timeline stack", () => {
  assert.match(nowPlayingModule, /id: artwork[\s\S]*anchors\.top: parent\.top[\s\S]*anchors\.horizontalCenter: parent\.horizontalCenter/)
  assert.match(nowPlayingModule, /id: metadataOverlay[\s\S]*anchors\.bottom: parent\.bottom/)
  assert.match(nowPlayingModule, /id: controlBand[\s\S]*anchors\.top: artwork\.bottom[\s\S]*anchors\.bottom: timeline\.top/)
  assert.match(nowPlayingModule, /id: controls[\s\S]*anchors\.centerIn: parent/)
  assert.match(nowPlayingModule, /id: timeline[\s\S]*anchors\.left: parent\.left[\s\S]*anchors\.right: parent\.right[\s\S]*anchors\.bottom: parent\.bottom/)
})
