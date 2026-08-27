const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const sourcePath = process.env.AUDIO_MIXER_QML
  || path.join(__dirname, "../modules/AudioMixerModule.qml")
const source = fs.readFileSync(sourcePath, "utf8")

function extractFunction(name, dependencies) {
  const signature = new RegExp(`  function ${name}\\(([^)]*)\\) \\{`, "g")
  const match = signature.exec(source)
  assert.ok(match, `could not locate ${name} in ${sourcePath}`)

  const bodyStart = signature.lastIndex
  let depth = 1
  let bodyEnd = bodyStart
  while (depth > 0 && bodyEnd < source.length) {
    if (source[bodyEnd] === "{") depth++
    if (source[bodyEnd] === "}") depth--
    bodyEnd++
  }
  assert.equal(depth, 0, `could not extract ${name} from ${sourcePath}`)

  const body = source.slice(bodyStart, bodyEnd - 1)
  return Function(...Object.keys(dependencies), `return function ${name}(${match[1]}) {${body}}`)(
    ...Object.values(dependencies),
  )
}

const staleStreams = [{ audio: undefined }, null]
const streamAudio = source.includes("  function streamAudio(")
  ? extractFunction("streamAudio", {})
  : stream => stream && stream.audio ? stream.audio : null

function functionsFor(streams) {
  const streamsFor = () => streams
  const categoryVolume = extractFunction("categoryVolume", { streamsFor, streamAudio })
  const categoryMuted = extractFunction("categoryMuted", { streamsFor, streamAudio })
  const clamp = value => Math.max(0, Math.min(1, value))

  return {
    categoryVolume,
    categoryMuted,
    setCategoryVolume: extractFunction("setCategoryVolume", {
      streamsFor,
      categoryVolume,
      streamAudio,
      clamp,
    }),
    toggleCategoryMute: extractFunction("toggleCategoryMute", {
      streamsFor,
      categoryMuted,
      streamAudio,
    }),
  }
}

test("categoryVolume ignores vanished PipeWire nodes and audio interfaces", () => {
  const { categoryVolume } = functionsFor(staleStreams)
  assert.equal(categoryVolume("media"), 0)
})

test("categoryMuted reports no mute state when every PipeWire node vanished", () => {
  const { categoryMuted } = functionsFor(staleStreams)
  assert.equal(categoryMuted("media"), false)
})

test("setCategoryVolume skips vanished nodes while updating live streams", () => {
  const liveAudio = { volume: 0.5, muted: false }
  const { setCategoryVolume } = functionsFor([...staleStreams, { audio: liveAudio }])

  setCategoryVolume("media", 1)

  assert.equal(liveAudio.volume, 1)
})

test("toggleCategoryMute skips vanished nodes while updating live streams", () => {
  const liveAudio = { volume: 0.5, muted: false }
  const { toggleCategoryMute } = functionsFor([...staleStreams, { audio: liveAudio }])

  toggleCategoryMute("media")

  assert.equal(liveAudio.muted, true)
})
