const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

function source(relativePath) {
  return fs.readFileSync(path.join(__dirname, "..", relativePath), "utf8")
}

function loadPolicy() {
  const policySource = source("components/ResponsiveLayout.js")
    .replace(/^\.pragma library\s*/m, "")
  const context = {}
  vm.runInNewContext(policySource, context, { filename: "ResponsiveLayout.js" })
  return context
}

test("responsive fit never enlarges content and bounds both axes", () => {
  const policy = loadPolicy()

  assert.equal(policy.fitScale(300, 200, 100, 100), 1)
  assert.equal(policy.fitScale(300, 200, 600, 100), 0.5)
  assert.equal(policy.fitScale(300, 200, 100, 400), 0.5)
  assert.equal(policy.fitScale(300, 200, 600, 800), 0.25)

  for (const fixture of [
    [300, 200, 600, 100],
    [300, 200, 100, 400],
    [525 / 1.6, 598 / 1.6, 360, 320],
    [843 / 1.6, 390 / 1.6, 500, 300],
  ]) {
    const [availableWidth, availableHeight, contentWidth, contentHeight] = fixture
    const scale = policy.fitScale(...fixture)
    assert.ok(contentWidth * scale <= availableWidth + 0.001, fixture.join("×"))
    assert.ok(contentHeight * scale <= availableHeight + 0.001, fixture.join("×"))
  }
})

test("short-wide reflow is selected only when the stacked layout is too tall and the wide topology fits", () => {
  const policy = loadPolicy()

  assert.equal(policy.useShortWide(800, 200, 300, 700), true)
  assert.equal(policy.useShortWide(650, 200, 300, 700), false)
  assert.equal(policy.useShortWide(800, 320, 300, 700), false)
})

test("ResponsivePanel provides one reusable bounded-content contract", () => {
  const panel = source("components/ResponsivePanel.qml")

  assert.match(panel, /import "ResponsiveLayout\.js" as ResponsiveLayout/)
  assert.match(panel, /default property alias content:/)
  assert.match(panel, /readonly property real availableWidth:/)
  assert.match(panel, /readonly property real availableHeight:/)
  assert.match(panel, /ResponsiveLayout\.fitScale\(/)
  assert.match(panel, /width:\s*root\.layoutWidth/)
  assert.match(panel, /scale:\s*root\.contentScale/)
  assert.match(panel, /anchors\.centerIn:\s*parent/)
  assert.match(panel, /clip:\s*true/)
  assert.doesNotMatch(panel, /Flickable/)
})

test("finite action panels reflow where meaningful and never rely on hidden scrolling", () => {
  const timerModule = source("modules/TimerModule.qml")
  const timerSetup = source("modules/TimerSetupPanel.qml")
  const timerStep = source("components/TimerStepButton.qml")
  const commandCenter = source("modules/CommandCenterModule.qml")

  assert.match(timerModule, /ResponsivePanel\s*\{[\s\S]*id:\s*timerViewport/)
  assert.equal((timerModule.match(/TimerSetupPanel\s*\{/g) || []).length, 2)
  assert.match(timerSetup, /id:\s*durationSelector/)
  assert.match(timerSetup, /readonly property bool oneRow:/)
  assert.equal((timerSetup.match(/TimerStepButton\s*\{/g) || []).length, 2)
  assert.match(timerStep, /font\.pixelSize:\s*Style\.font\.display/)
  assert.match(timerSetup, /id:\s*actionRow[\s\S]*\(width - spacing \* 2\) \/ 3/)
  assert.doesNotMatch(timerModule, /id:\s*timerOverlayScroll/)
  assert.doesNotMatch(timerModule, /Math\.max\(Style\.space\(360\)/)

  assert.match(commandCenter, /readonly property int columnCount:\s*useThreeColumns \? 3 : 2/)
  assert.match(commandCenter, /readonly property real contentWidth:\s*Math\.min\(/)
  assert.match(commandCenter, /columns:\s*root\.columnCount/)
  assert.match(commandCenter, /readonly property real contentScale:\s*1/)
  assert.doesNotMatch(commandCenter, /scale:\s*root\.contentScale/)
})

test("Command Center stays usable in roomy, narrow, and short customized panels", () => {
  const result = require("node:child_process").spawnSync("/usr/lib/qt6/bin/qmltestrunner", [
    "-input", "tests/qml/tst_command-center-responsive.qml", "-import", "tests/qml/imports"
  ], {
    cwd: path.join(__dirname, ".."), encoding: "utf8", timeout: 10000,
    env: { ...process.env, QT_QPA_PLATFORM: "offscreen", QT_QUICK_BACKEND: "software", QML_DISABLE_DISK_CACHE: "1" }
  })
  assert.equal(result.error, undefined)
  assert.equal(result.status, 0, result.stdout + result.stderr)
  assert.doesNotMatch(result.stdout + result.stderr, /QWARN|QCRITICAL|QFATAL/)
})
