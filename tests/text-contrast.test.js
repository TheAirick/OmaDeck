const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")
const { spawnSync } = require("node:child_process")
const test = require("node:test")
const root = path.resolve(__dirname, "..")
const contrast = {}
vm.runInNewContext(fs.readFileSync(path.join(root, "theme/TextContrast.js"), "utf8")
  .replace(/^\.pragma library\s*/m, ""), contrast)
const palettes = require("./fixtures/theme-palettes.json").palettes
function color(hex) {
  return { r: parseInt(hex.slice(1, 3), 16) / 255, g: parseInt(hex.slice(3, 5), 16) / 255,
    b: parseInt(hex.slice(5, 7), 16) / 255, a: 1 }
}
// Independent reference formula checks the public output, including rounding.
function ratio(first, second) {
  function luminance(value) {
    return [value.r, value.g, value.b].map(v => v <= 0.04045 ? v / 12.92 : ((v + .055) / 1.055) ** 2.4)
      .reduce((sum, value, i) => sum + value * [.2126, .7152, .0722][i], 0)
  }
  const a = luminance(first), b = luminance(second)
  return (Math.max(a, b) + .05) / (Math.min(a, b) + .05)
}

test("reported dark palette becomes readable while staying softer than primary text", () => {
  const { muted, foreground, background } = palettes[0]
  const result = color(contrast.secondary(color(muted), color(foreground), color(background)))
  assert.ok(ratio(color(muted), color(background)) < 1.6)
  assert.ok(ratio(result, color(background)) >= 4.5)
  assert.ok(result.r < color(foreground).r)
  assert.equal(result.r, result.g)
  assert.equal(result.g, result.b)
})

test("all captured light and dark theme palettes meet the secondary-text floor", () => {
  assert.ok(palettes.length >= 23)
  for (const palette of palettes) {
    const muted = color(palette.muted), fg = color(palette.foreground), bg = color(palette.background)
    const result = contrast.secondary(muted, fg, bg)
    assert.ok(ratio(color(result), bg) >= 4.5, `${palette.name}: ${result}`)
    if (ratio(muted, bg) >= 4.5)
      assert.equal(result.toLowerCase(), palette.muted.toLowerCase(), `${palette.name} already readable`)
  }
})

test("light surfaces darken faint labels and unrelated popup colors use their own background", () => {
  for (const background of ["#ffffff", "#faf4e8", "#111111", "#787878"]) {
    const bg = color(background)
    const result = color(contrast.secondary(bg, bg, bg))
    assert.ok(ratio(result, bg) >= 4.5, background)
  }
  const darkened = color(contrast.secondary(color("#dddddd"), color("#222222"), color("#ffffff")))
  assert.ok(darkened.r < color("#dddddd").r)
  assert.ok(darkened.r > color("#222222").r)
})

test("translucent text and a broad range of custom RGB palettes retain the contrast floor", () => {
  let seed = 9173
  function random() { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296 }
  function rgb() { return { r: random(), g: random(), b: random(), a: 1 } }
  for (let i = 0; i < 4000; i++) {
    const bg = rgb(), fg = rgb(), muted = { ...rgb(), a: random() }
    const result = contrast.secondary(muted, fg, bg)
    assert.ok(ratio(color(result), bg) >= 4.5, `${i}: ${result}`)
  }
})

test("real QML labels react to theme changes and use the popup surface", () => {
  const result = spawnSync("/usr/lib/qt6/bin/qmltestrunner", [
    "-input", "tests/qml/tst_text-contrast.qml", "-import", "tests/qml/imports",
  ], { cwd: root, encoding: "utf8", timeout: 30000,
    env: { ...process.env, QT_QPA_PLATFORM: "offscreen", QSG_RHI_BACKEND: "software" } })
  assert.equal(result.status, 0, result.stdout + result.stderr)
  assert.doesNotMatch(result.stdout + result.stderr, /QWARN|ReferenceError|TypeError/)
})
