const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const audioMixer = fs.readFileSync(
  path.join(__dirname, "..", "modules/AudioMixerModule.qml"),
  "utf8",
)

test("output and microphone share one fixed master row", () => {
  assert.match(audioMixer, /id: masterColumn/)
  assert.match(audioMixer, /Row\s*\{[\s\S]*height:\s*Style\.space\(46\)/)
  assert.match(audioMixer, /label:\s*"Output"[\s\S]*label:\s*"Mic"/)
  assert.match(audioMixer, /\(parent\.width - parent\.spacing\) \/ 2/)
})

test("all categories and sources share one bounded vertical viewport", () => {
  assert.match(audioMixer, /id: streamViewport/)
  assert.match(audioMixer, /anchors\.top:\s*masterColumn\.bottom/)
  assert.match(audioMixer, /contentHeight:\s*streamColumn\.implicitHeight/)
  assert.match(audioMixer, /interactive:\s*!root\.compact && contentHeight > height/)
  assert.match(audioMixer, /flickableDirection: Flickable\.VerticalFlick/)
  assert.match(audioMixer, /boundsBehavior: Flickable\.StopAtBounds/)
  assert.doesNotMatch(audioMixer, /id:\s*sourceViewport/)
})

test("the shared stream viewport exposes tap navigation", () => {
  assert.match(audioMixer, /function scrollStreams\(direction\)/)
  assert.match(audioMixer, /id: streamScrollUp[\s\S]*!streamViewport\.atYBeginning/)
  assert.match(audioMixer, /id: streamScrollDown[\s\S]*!streamViewport\.atYEnd/)
  assert.equal((audioMixer.match(/onTapped: root\.scrollStreams\([+-]1\)/g) || []).length, 2)
})
