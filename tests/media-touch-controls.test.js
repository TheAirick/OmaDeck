const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const nowPlayingModule = fs.readFileSync(
  path.join(__dirname, "..", "modules/NowPlayingModule.qml"),
  "utf8",
)

test("playback controls form a touch-first pyramid", () => {
  assert.match(nowPlayingModule, /Column \{\s*id: controls[\s\S]*Button \{\s*id: playPauseControl/)
  assert.match(nowPlayingModule, /id: playPauseControl[\s\S]*width: Style\.space\(120\); height: Style\.space\(64\)/)
  assert.match(nowPlayingModule, /id: playPauseControl[\s\S]*iconSize: Style\.font\.displayLarge \* 3/)
  assert.match(nowPlayingModule, /id: controls[\s\S]*spacing: 0/)
  assert.match(nowPlayingModule, /Row \{\s*id: transportControls/)
  assert.equal((nowPlayingModule.match(/width: Style\.space\(58\); height: Style\.space\(58\)/g) || []).length, 4)
  assert.equal((nowPlayingModule.match(/(?:iconSize: Style\.font\.iconLarge|fontSize: Style\.font\.body) \* 1\.6/g) || []).length, 4)
  assert.equal((nowPlayingModule.match(/color: "transparent"; borderSpec: Border\.none\(\)/g) || []).length, 5)
})

test("transport controls share the artwork bottom baseline", () => {
  assert.match(nowPlayingModule, /id: controlSpacer/)
  assert.match(nowPlayingModule, /height: Math\.max\(0, artwork\.y \+ artwork\.height - controls\.height - y - parent\.spacing\)/)
})
