const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const audioMixer = fs.readFileSync(
  path.join(__dirname, "..", "modules/AudioMixerModule.qml"),
  "utf8",
)

test("mixer uses a compact chevron toggle instead of a full-width plus/minus column", () => {
  assert.match(audioMixer, /property bool compact:\s*true/)
  assert.match(audioMixer, /component VerticalVolume:\s*Item/)
  assert.match(audioMixer, /controlId:\s*"output"/)
  assert.match(audioMixer, /objectName:\s*"mixerExpandButton"/)
  assert.match(audioMixer, /onClicked:\s*root\.compact = !root\.compact/)
  assert.match(audioMixer, /preferredWidth:\s*root\.compact \? Style\.space\(70\)/)
  assert.match(audioMixer, /root\.compact \? 0\s*:\s*Style\.spacing\.labelGap \+ Style\.space\(32\)/)
  assert.match(audioMixer, /width:\s*root\.compact \? Style\.space\(48\) : Style\.space\(32\)/)
  assert.match(audioMixer, /iconText:\s*root\.compact \? "󰅂" : "󰅁"/)
  assert.match(audioMixer, /borderSpec:\s*Border\.none\(\)/)
  assert.match(audioMixer, /bottomInset:\s*root\.compact \? Style\.space\(56\) : 0/)
})

test("expanded mixer reveals Mic and active aggregate categories as vertical controls", () => {
  assert.match(audioMixer, /controlId:\s*"mic"[\s\S]*revealed:\s*!root\.compact/)
  for (const category of ["media", "games", "voice", "other"])
    assert.match(audioMixer, new RegExp(`controlId:\\s*"${category}"[\\s\\S]*revealed:\\s*!root\\.compact && streams\\.length > 0`))
  assert.doesNotMatch(audioMixer, /id:\s*streamViewport/)
})

test("vertical controls preserve the snapshotted PipeWire presentation model", () => {
  assert.match(audioMixer, /property var displayStreams:\s*\[\]/)
  assert.match(audioMixer, /function refreshStreams\(\) \{ displayStreams = liveStreams\.slice\(\) \}/)
  assert.match(audioMixer, /PwObjectTracker \{ objects: root\.liveStreams \}/)
  assert.match(audioMixer, /id:\s*snapshotTimer/)
})
