const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

function loadPolicy() {
  const source = fs
    .readFileSync(path.join(__dirname, "../services/LayoutPolicy.js"), "utf8")
    .replace(/^\.pragma library\s*/m, "")
  const context = {}
  vm.runInNewContext(source, context, { filename: "LayoutPolicy.js" })
  return context
}

function validNestedLayout() {
  return {
    version: 2,
    root: {
      type: "split",
      orientation: "horizontal",
      ratio: 0.18,
      first: { type: "module", moduleId: "clock" },
      second: {
        type: "split",
        orientation: "vertical",
        ratio: 0.82,
        first: { type: "module", moduleId: "workspaces" },
        second: { type: "module", moduleId: "command-center" },
      },
    },
  }
}

test("valid nested layouts and supported module IDs remain unchanged", () => {
  const policy = loadPolicy()
  const layout = validNestedLayout()
  const before = JSON.stringify(layout)

  assert.equal(policy.validLayout(layout), true)
  assert.equal(JSON.stringify(policy.parseLayout(before)), before)
  assert.equal(JSON.stringify(layout), before)
})

test("invalid persisted fixtures select the safe default layout", () => {
  const policy = loadPolicy()
  const fallback = validNestedLayout()
  const fixtures = [
    "not json",
    JSON.stringify({ version: 2, root: { type: "module", moduleId: "clock" } }),
    JSON.stringify({
      version: 2,
      root: {
        type: "split",
        orientation: "horizontal",
        ratio: "0.5",
        first: { type: "module", moduleId: "clock" },
        second: { type: "module", moduleId: "command-center" },
      },
    }),
    '{"version":2,"root":{"type":"split","orientation":"horizontal","ratio":1e400,"first":{"type":"module","moduleId":"clock"},"second":{"type":"module","moduleId":"command-center"}}}',
    JSON.stringify({
      version: 2,
      root: {
        type: "split",
        orientation: "horizontal",
        ratio: 0.5,
        first: { type: "module", moduleId: "obsolete-module" },
        second: { type: "module", moduleId: "command-center" },
      },
    }),
  ]

  for (const fixture of fixtures) {
    const selected = policy.parseLayout(fixture) || fallback
    assert.equal(selected, fallback)
  }
})

test("persisted split ratios must be finite numbers within the resize bounds", () => {
  const policy = loadPolicy()
  const invalidRatios = ["0.5", null, NaN, Infinity, -Infinity, 0.179, 0.821]

  for (const ratio of invalidRatios) {
    const layout = validNestedLayout()
    layout.root.ratio = ratio
    assert.equal(policy.validLayout(layout), false, String(ratio))
  }

  for (const ratio of [0.18, 0.5, 0.82]) {
    const layout = validNestedLayout()
    layout.root.ratio = ratio
    assert.equal(policy.validLayout(layout), true, String(ratio))
  }
})

test("persisted layouts reject unknown modules and a module root", () => {
  const policy = loadPolicy()

  for (const moduleId of ["", "clock-old", "media", null, 7]) {
    const layout = validNestedLayout()
    layout.root.first.moduleId = moduleId
    assert.equal(policy.validLayout(layout), false, String(moduleId))
  }

  assert.equal(
    policy.validLayout({
      version: 2,
      root: { type: "module", moduleId: "clock" },
    }),
    false,
  )
})

test("ratio updates clamp finite numbers and reject non-finite or nonnumeric input", () => {
  const policy = loadPolicy()

  assert.equal(policy.ratioForUpdate(-1), 0.18)
  assert.equal(policy.ratioForUpdate(0.5), 0.5)
  assert.equal(policy.ratioForUpdate(2), 0.82)
  for (const value of ["0.5", null, NaN, Infinity, -Infinity]) {
    assert.equal(policy.ratioForUpdate(value), null, String(value))
  }
})

test("LayoutController applies the shared policy when loading and updating", () => {
  const controller = fs.readFileSync(
    path.join(__dirname, "../services/LayoutController.qml"),
    "utf8",
  )

  assert.match(controller, /import "LayoutPolicy\.js" as LayoutPolicy/)
  assert.match(controller, /LayoutPolicy\.parseLayout\(/)
  assert.match(controller, /layout = defaultLayout\(\)/)
  assert.match(controller, /scheduleSave\(\)/)
  assert.match(controller, /LayoutPolicy\.ratioForUpdate\(value\)/)
})
