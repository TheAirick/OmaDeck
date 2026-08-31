const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")
const childProcess = require("node:child_process")
const crypto = require("node:crypto")
const os = require("node:os")

const repositoryRoot = path.join(__dirname, "..")

function source(relativePath) {
  return fs.readFileSync(path.join(repositoryRoot, relativePath), "utf8")
}

function loadPolicy() {
  const policySource = source("modules/ClockCompanionPolicy.js")
    .replace(/^\.pragma library\s*/m, "")
  const context = {}
  vm.runInNewContext(policySource, context, { filename: "ClockCompanionPolicy.js" })
  return context
}

function loadSplitPolicy() {
  const policySource = source("components/SplitPresentationPolicy.js")
    .replace(/^\.pragma library\s*/m, "")
  const context = {}
  vm.runInNewContext(policySource, context, { filename: "SplitPresentationPolicy.js" })
  return context
}

test("the lower companion derives exactly one occupant from setup and authoritative timer status", () => {
  const policy = loadPolicy()

  const cases = [
    { setupOpen: false, status: "idle", expected: "weather" },
    { setupOpen: true, status: "idle", expected: "timer" },
    { setupOpen: false, status: "active", expected: "timer" },
    { setupOpen: true, status: "active", expected: "timer" },
    { setupOpen: false, status: "paused", expected: "timer" },
    { setupOpen: false, status: "completed", expected: "timer" },
  ]

  for (const fixture of cases) {
    assert.equal(
      policy.occupant(fixture.status, fixture.setupOpen),
      fixture.expected,
      JSON.stringify(fixture),
    )
  }
})

test("every accepted companion transition resolves to Weather or Timer without a third state", () => {
  const policy = loadPolicy()
  const transitions = [
    ["normal idle", "idle", false, "weather"],
    ["clock tap", "idle", true, "timer"],
    ["setup cancel", "idle", false, "weather"],
    ["start", "active", false, "timer"],
    ["pause", "paused", false, "timer"],
    ["resume", "active", false, "timer"],
    ["add five", "active", false, "timer"],
    ["restart", "active", false, "timer"],
    ["active cancel", "idle", false, "weather"],
    ["completion", "completed", false, "timer"],
    ["dismiss", "idle", false, "weather"],
    ["idle recreation", "idle", false, "weather"],
    ["active recreation", "active", false, "timer"],
    ["paused recreation", "paused", false, "timer"],
    ["completed recreation", "completed", false, "timer"],
    ["hidden weather refresh", "active", false, "timer"],
  ]

  for (const [event, status, setupOpen, expected] of transitions)
    assert.equal(policy.occupant(status, setupOpen), expected, event)
})

test("Clock tile uses one explicit static companion host with complementary presenters", () => {
  const tile = source("components/ClockCompanionTile.qml")
  const companion = source("modules/ClockCompanionModule.qml")

  assert.equal((tile.match(/ClockModule\s*\{/g) || []).length, 1)
  assert.equal((tile.match(/ClockCompanionModule\s*\{/g) || []).length, 1)
  assert.equal((companion.match(/WeatherModule\s*\{/g) || []).length, 1)
  assert.equal((companion.match(/TimerModule\s*\{/g) || []).length, 1)
  assert.match(companion, /readonly property string occupant:\s*ClockCompanionPolicy\.occupant\(root\.timerStatus, timerPresenter\.setupOpen\)/)
  assert.match(companion, /visible:\s*root\.occupant === "weather"/)
  assert.match(companion, /visible:\s*root\.occupant === "timer"/)
  assert.doesNotMatch(companion, /Loader|setSource|layoutController|commit\(|scheduleSave/)
})

test("ModuleTile gives Clock two sibling card boundaries instead of one composite card", () => {
  const moduleTile = source("components/ModuleTile.qml")
  const companionTilePath = path.join(repositoryRoot, "components/ClockCompanionTile.qml")

  assert.equal(fs.existsSync(companionTilePath), true, "ClockCompanionTile.qml must own the pair")
  assert.match(moduleTile, /id:\s*clockLoader[\s\S]*active:\s*root\.moduleId === "clock"[\s\S]*sourceComponent:\s*clockTileComponent/)
  assert.match(moduleTile, /id:\s*genericCardLoader[\s\S]*active:\s*root\.moduleId !== "clock"[\s\S]*sourceComponent:\s*genericCardComponent/)
  assert.equal((moduleTile.match(/DeckCard\s*\{/g) || []).length, 1,
    "ordinary modules retain exactly one generic DeckCard declaration")
  assert.equal((moduleTile.match(/ClockCompanionTile\s*\{/g) || []).length, 1)

  const companionTile = fs.readFileSync(companionTilePath, "utf8")
  assert.equal((companionTile.match(/DeckCard\s*\{/g) || []).length, 2)
  assert.match(companionTile, /objectName:\s*"clockPanelCard"/)
  assert.match(companionTile, /objectName:\s*"companionPanelCard"/)
  assert.doesNotMatch(companionTile, /\bRectangle\s*\{/, "the split must not be a decorative divider")
})

test("companion Timer setup cancel stops preview and non-idle state is always presented", () => {
  const timerModule = source("modules/TimerModule.qml")

  assert.match(timerModule, /property bool companionMode:\s*false/)
  assert.match(timerModule, /readonly property bool presenterActive:\s*root\.setupOpen \|\| root\.timerStatus !== "idle"/)
  assert.match(timerModule, /visible:\s*root\.companionMode \? root\.presenterActive : root\.open/)
  assert.match(timerModule, /function cancelSetup\(\)[\s\S]*timer\.stopPreview\(\)[\s\S]*close\(\)/)
  assert.match(timerModule, /Component\.onDestruction:\s*if \(timer\) timer\.stopPreview\(\)/)
  assert.match(timerModule, /text:\s*"Cancel"[\s\S]{0,220}onClicked:\s*root\.cancelSetup\(\)/)
  assert.doesNotMatch(timerModule, /text:\s*"Close"/)
})

test("the direct Clock split gets a presentation-only 0.36 minimum on either side", () => {
  const policy = loadSplitPolicy()

  assert.equal(policy.effectiveRatio(true, "clock", "command-center", 0.28), 0.36)
  assert.equal(policy.effectiveRatio(true, "clock", "command-center", 0.36), 0.36)
  assert.equal(policy.effectiveRatio(true, "clock", "command-center", 0.44), 0.44)
  assert.equal(policy.effectiveRatio(true, "command-center", "clock", 0.72), 0.64)
  assert.equal(policy.effectiveRatio(true, "command-center", "clock", 0.64), 0.64)
  assert.equal(policy.effectiveRatio(true, "command-center", "clock", 0.56), 0.56)
  assert.equal(policy.effectiveRatio(false, "clock", "command-center", 0.28), 0.28)
  assert.equal(policy.effectiveRatio(true, "clock", "workspaces", 0.28), 0.28)
})

test("SplitNode applies effective presentation geometry without changing the saved ratio", () => {
  const split = source("components/SplitNode.qml")

  assert.match(split, /import "SplitPresentationPolicy\.js" as SplitPresentationPolicy/)
  assert.match(split, /readonly property real effectiveRatio:\s*SplitPresentationPolicy\.effectiveRatio\(/)
  assert.match(split, /readonly property real firstLength:\s*Math\.max\(0, Math\.round\(availableLength \* effectiveRatio\)\)/)
  assert.match(split, /startingRatio = root\.ratio/)
  assert.doesNotMatch(split, /setRatio\([^\n]*effectiveRatio|commit\(|scheduleSave/)
})

test("companion transitions preserve layout bytes, topology, edit selection, and drawer state", () => {
  const fixturePath = path.join(repositoryRoot, "tests/fixtures/clock-companion-layout.json")
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "omadeck-companion-"))
  const copiedLayout = path.join(scratch, "layout.json")
  try {
    fs.copyFileSync(fixturePath, copiedLayout)
    const before = fs.readFileSync(copiedLayout)
    const beforeHash = crypto.createHash("sha256").update(before).digest("hex")
    const saved = JSON.parse(before.toString("utf8"))
    const topology = JSON.stringify(saved.root)
    const selectedPath = "first"
    const drawerState = "bottom"
    const companionPolicy = loadPolicy()
    const splitPolicy = loadSplitPolicy()

    for (let cycle = 0; cycle < 20; cycle += 1) {
      for (const [status, setupOpen] of [
        ["idle", false], ["idle", true], ["active", false],
        ["paused", false], ["completed", false], ["idle", false],
      ]) {
        assert.ok(["weather", "timer"].includes(companionPolicy.occupant(status, setupOpen)))
        assert.equal(splitPolicy.effectiveRatio(true, "clock", "command-center", saved.root.ratio), 0.36)
      }
    }

    const after = fs.readFileSync(copiedLayout)
    assert.deepEqual(after, before)
    assert.equal(crypto.createHash("sha256").update(after).digest("hex"), beforeHash)
    assert.equal(JSON.stringify(saved.root), topology)
    assert.equal(selectedPath, "first")
    assert.equal(drawerState, "bottom")
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true })
  }
})

test("fixed companion geometry remains 0.37/0.63 through all drawer reservations", () => {
  const tile = source("components/ClockCompanionTile.qml")
  assert.match(tile, /clockHeight:\s*Math\.round\(splitHeight \* 0\.37\)/)
  assert.match(tile, /companionHeight:\s*Math\.max\(0, splitHeight - clockHeight\)/)

  const screen = { width: 1600, height: 450, outer: 5, gap: 14 }
  const drawers = {
    closed: [0, 0, 0, 0],
    left: [555, 0, 0, 0],
    right: [0, 555, 0, 0],
    top: [0, 0, 92, 0],
    bottom: [0, 0, 0, 130],
  }
  for (const ratio of [0.36, 0.44]) {
    for (const [drawer, [left, right, top, bottom]] of Object.entries(drawers)) {
      const centerWidth = screen.width - screen.outer * 2 - left - right
      const centerHeight = screen.height - screen.outer * 2 - top - bottom
      const clockWidth = Math.round((centerWidth - screen.gap) * ratio)
      const clockHeight = Math.round((centerHeight - screen.gap) * 0.37)
      const companionHeight = centerHeight - screen.gap - clockHeight
      assert.ok(clockWidth >= 367, `${drawer} ${ratio} width ${clockWidth}`)
      assert.ok(clockHeight >= 109, `${drawer} ${ratio} clock ${clockHeight}`)
      assert.ok(companionHeight >= 181, `${drawer} ${ratio} companion ${companionHeight}`)
    }
  }
})

test("offscreen QML verifies states, drawers, touch geometry, and lifecycle churn", {
  skip: !fs.existsSync("/usr/lib/qt6/bin/qmltestrunner"),
}, () => {
  const result = childProcess.spawnSync("/usr/lib/qt6/bin/qmltestrunner", [
    "-silent",
    "-input",
    "tests/qml/tst_clock-companion-render.qml",
    "-import",
    "tests/qml/imports",
  ], {
    cwd: repositoryRoot,
    encoding: "utf8",
    env: {
      ...process.env,
      QT_QPA_PLATFORM: "offscreen",
      QSG_RHI_BACKEND: "software",
    },
  })

  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`)
  assert.match(result.stdout, /0 failed/)
  const stateHashes = new Set()
  for (const state of [
    "weather-loading", "weather-disabled", "weather-unavailable", "weather-current",
    "setup", "active", "paused", "completed",
  ]) {
    const imagePath = `/tmp/omadeck-companion-${state}.png`
    assert.equal(fs.existsSync(imagePath), true, state)
    assert.ok(fs.statSync(imagePath).size > 1000, state)
    stateHashes.add(crypto.createHash("sha256").update(fs.readFileSync(imagePath)).digest("hex"))
  }
  assert.equal(stateHashes.size, 8, "every Weather and Timer state must render distinctly")
})

test("actual ModuleTile renders and interacts as two independent Clock panels", {
  skip: !fs.existsSync("/usr/lib/qt6/bin/qmltestrunner"),
}, () => {
  const imagePath = "/tmp/omadeck-module-tile-clock.png"
  fs.rmSync(imagePath, { force: true })
  const result = childProcess.spawnSync("/usr/lib/qt6/bin/qmltestrunner", [
    "-silent",
    "-input",
    "tests/qml/tst_module-tile-clock.qml",
    "-import",
    "tests/qml/imports",
  ], {
    cwd: repositoryRoot,
    encoding: "utf8",
    env: {
      ...process.env,
      QT_QPA_PLATFORM: "offscreen",
      QSG_RHI_BACKEND: "software",
    },
  })

  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`)
  assert.match(result.stdout, /0 failed/)
  assert.equal(fs.existsSync(imagePath), true)
  assert.ok(fs.statSync(imagePath).size > 1000)
})
