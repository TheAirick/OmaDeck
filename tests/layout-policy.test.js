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

test("migration separates all dashboard panels without changing the legacy file value", () => {
  const policy = loadPolicy()
  const old = { version: 2, root: { type: "split", orientation: "horizontal", ratio: 0.36,
    first: { type: "module", moduleId: "clock" }, second: { type: "module", moduleId: "command-center" } } }
  const before = JSON.stringify(old)
  const full = policy.dashboardLayout(old)
  assert.equal(policy.validDashboard(full), true)
  assert.equal(full.root.first.moduleId, "media")
  assert.equal(full.root.second.ratio, 0.5, "preserve the old visual minimum during migration")
  assert.equal(full.root.second.first.ratio, 0.48)
  assert.equal(full.root.second.first.first.moduleId, "clock")
  assert.equal(full.root.second.first.second.moduleId, "weather")
  assert.equal(JSON.stringify(old), before)
  assert.equal(JSON.stringify(policy.dashboardLayout(full)), JSON.stringify(full), "migration is idempotent")
})

test("every panel can move to all four sides of every other panel without loss or duplication", () => {
  const policy = loadPolicy()
  const full = policy.dashboardLayout(validNestedLayout())
  const before = JSON.stringify(full)
  const ids = ["media", "clock", "weather", "command-center", "workspaces"]
  for (const source of ids) for (const target of ids.filter(id => id !== source)) {
    for (const edge of ["left", "right", "top", "bottom"]) {
      const moved = policy.moveModule(full, source, target, edge)
      assert.equal(policy.validDashboard(moved), true, `${source} ${edge} of ${target}`)
      const sourcePath = policy.modulePath(moved.root, source, "")
      let parent = moved.root
      for (const part of sourcePath.split("/").slice(0, -1)) parent = parent[part]
      assert.equal(parent.orientation, ["left", "right"].includes(edge) ? "horizontal" : "vertical")
      const beforeTarget = ["left", "top"].includes(edge)
      assert.equal(parent[beforeTarget ? "first" : "second"].moduleId, source)
      assert.equal(parent[beforeTarget ? "second" : "first"].moduleId, target)
    }
  }
  assert.equal(JSON.stringify(full), before)
  assert.equal(policy.moveModule(full, "media", "media", "left"), null)
  assert.equal(policy.moveModule(full, "unknown", "clock", "left"), null)
  assert.equal(policy.moveModule(full, "media", "clock", "unknown"), null)
})

test("dashboard validation refuses missing, duplicate, and unsupported panels", () => {
  const policy = loadPolicy()
  for (const id of ["clock", "unknown", null]) {
    const full = policy.dashboardLayout(validNestedLayout())
    full.root.first.moduleId = id
    assert.equal(policy.validDashboard(full), false)
    assert.equal(policy.parseLayout(JSON.stringify(full)), null)
  }
})
