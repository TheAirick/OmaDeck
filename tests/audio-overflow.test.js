const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const audioMixer = fs.readFileSync(
  path.join(__dirname, "..", "modules/AudioMixerModule.qml"),
  "utf8",
)

test("expanded categories show at most two source sliders", () => {
  assert.match(audioMixer, /readonly property int visibleStreamRowLimit: 2/)
  assert.match(audioMixer, /Style\.space\(46 \* root\.visibleStreamRowLimit\)/)
})

test("overflowing source sliders support vertical swiping", () => {
  assert.match(audioMixer, /id: sourceViewport/)
  assert.match(audioMixer, /interactive: contentHeight > height/)
  assert.match(audioMixer, /flickableDirection: Flickable\.VerticalFlick/)
  assert.match(audioMixer, /boundsBehavior: Flickable\.StopAtBounds/)
})

test("overflowing source sliders expose tap navigation", () => {
  assert.match(audioMixer, /function scrollSources\(direction\)/)
  assert.match(audioMixer, /id: sourceScrollUp[\s\S]*!sourceViewport\.atYBeginning/)
  assert.match(audioMixer, /id: sourceScrollDown[\s\S]*!sourceViewport\.atYEnd/)
  assert.equal((audioMixer.match(/onTapped: category\.scrollSources\([+-]1\)/g) || []).length, 2)
})
