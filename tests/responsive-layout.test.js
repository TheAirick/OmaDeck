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
  const clock = source("modules/ClockModule.qml")
  const commandCenter = source("modules/CommandCenterModule.qml")

  assert.match(clock, /ResponsivePanel\s*\{[\s\S]*id:\s*timerViewport/)
  assert.match(clock, /id:\s*presetGrid[\s\S]*columns:\s*width < Style\.space\(400\) \? 2 : 4/)
  assert.match(clock, /Flow\s*\{\s*id:\s*soundSelector[\s\S]*width:\s*parent\.width/)
  assert.doesNotMatch(clock, /id:\s*timerOverlayScroll/)
  assert.doesNotMatch(clock, /Math\.max\(Style\.space\(360\)/)

  assert.match(commandCenter, /import "\.\.\/components\/ResponsiveLayout\.js" as ResponsiveLayout/)
  assert.match(commandCenter, /ResponsiveLayout\.useShortWide\(/)
  assert.match(commandCenter, /columns:\s*root\.useWideLayout \? 4 : 2/)
})
