const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const root = path.join(__dirname, "..")
function source(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8")
}

test("the service owns one persisted timer controller", () => {
  const service = source("Service.qml")
  const controller = source("services/TimerController.qml")

  assert.match(service, /TimerController\s*\{\s*id:\s*timerStore/)
  assert.match(service, /timerController:\s*timerStore/)
  assert.match(controller, /import "TimerPolicy\.js" as TimerPolicy/)
  assert.match(controller, /timerPath:\s*configDir \+ "\/timer\.json"/)
  assert.match(controller, /FileView\s*\{[\s\S]*atomicWrites:\s*true/)
  assert.match(controller, /blockWrites:\s*true/)
  assert.match(controller, /TimerPolicy\.restore\(/)
  assert.match(controller, /TimerPolicy\.completeIfDue\(/)
  assert.match(controller, /interval:\s*1000/)
  assert.match(controller, /command:\s*\["notify-send", "-e"/)
  assert.doesNotMatch(controller, /property var state:/)
  assert.match(controller, /function actionNow\(\)\s*\{[\s\S]*nowMs = Date\.now\(\)[\s\S]*return nowMs/)
  assert.ok((controller.match(/var actionTime = actionNow\(\)/g) || []).length >= 5)
  assert.match(controller, /function reconcileDue\(actionTime\)/)
  assert.ok((controller.match(/if \(reconcileDue\(actionTime\)\)/g) || []).length >= 5)
})

test("timer IPC exposes bounded state transitions with structured results", () => {
  const service = source("Service.qml")

  for (const method of [
    "timerState",
    "timerStart",
    "timerPause",
    "timerResume",
    "timerRestart",
    "timerAdd",
    "timerCancel",
    "timerDismiss",
  ]) {
    assert.match(service, new RegExp(`function ${method}\\(`), method)
  }
  assert.match(service, /TimerPolicy\.durationMs\(hours, minutes\)/)
  assert.match(service, /minutes !== 5/)
  assert.match(service, /JSON\.stringify\(\{ ok: false, error:/)
  assert.match(service, /JSON\.stringify\(\{ ok: true/)
})

test("timer ownership is forwarded through every layout loader to the Clock", () => {
  const deck = source("components/DeckSurface.qml")
  const split = source("components/SplitNode.qml")
  const tile = source("components/ModuleTile.qml")

  assert.match(deck, /property var timerController: null/)
  assert.match(deck, /SplitNode \{[\s\S]*timerController: root\.timerController/)
  assert.match(split, /property var timerController: null/)
  assert.match(split, /timerController: root\.timerController/)
  assert.match(tile, /property var timerController: null/)
  assert.match(tile, /ClockModule \{[\s\S]*timer:\s*root\.timerController/)
})

test("Clock timer UI is hidden while idle and preserves long-press editing", () => {
  const tile = source("components/ModuleTile.qml")
  const clock = source("modules/ClockModule.qml")

  assert.match(tile, /longPressThreshold:\s*500/)
  assert.match(tile, /onLongPressed:\s*root\.controller\.beginEdit\(root\.path\)/)
  assert.match(clock, /TapHandler\s*\{[\s\S]*onTapped:\s*root\.openTimerControls\(\)/)
  assert.match(clock, /visible:\s*root\.pickerOpen \|\| root\.controlsOpen/)
  assert.match(clock, /pickerOpen && timerStatus !== "idle"/)
  assert.match(clock, /root\.timerStatus !== "idle"/)
  assert.match(clock, /text:\s*"Start"/)
  assert.match(clock, /enabled:\s*root\.selectedDurationValid/)
  for (const preset of [5, 15, 30, 60]) {
    assert.match(clock, new RegExp(`setPreset\\(${preset}\\)`), String(preset))
  }
})

test("all Clock styles expose ambient timer state without replacing wall time", () => {
  const clock = source("modules/ClockModule.qml")

  assert.ok((clock.match(/text:\s*root\.timeText\(\)/g) || []).length >= 3)
  assert.ok((clock.match(/root\.secondaryText\(/g) || []).length >= 3)
  assert.match(clock, /timerStatus === "paused"[\s\S]*"Paused/)
  assert.match(clock, /"Time's up"/)
  assert.match(clock, /id:\s*timerProgressRail/)
  assert.match(clock, /width:\s*parent\.width \* root\.timerProgress/)
})

test("primary timer controls are semantic 48 pixel touch targets", () => {
  const clock = source("modules/ClockModule.qml")

  assert.match(clock, /readonly property int touchTarget:\s*48/)
  assert.ok((clock.match(/height:\s*root\.touchTarget/g) || []).length >= 10)
  assert.ok((clock.match(/Accessible\.role:\s*Accessible\.Button/g) || []).length >= 10)
  for (const name of ["Pause timer", "Resume timer", "Add 5 minutes", "Restart timer", "Cancel timer", "Dismiss timer"]) {
    assert.match(clock, new RegExp(`Accessible\\.name:\\s*"${name}"`), name)
  }
})

test("timer controls remain reachable when a Clock tile is constrained", () => {
  const clock = source("modules/ClockModule.qml")

  assert.match(clock, /Flickable\s*\{[\s\S]*id:\s*timerOverlayScroll/)
  assert.match(clock, /contentHeight:\s*Math\.max\(height, Math\.max\(pickerContent\.implicitHeight, controlsContent\.implicitHeight\)/)
  assert.match(clock, /flickableDirection:\s*Flickable\.AutoFlickDirection/)
  assert.match(clock, /interactive:\s*contentHeight > height \|\| contentWidth > width/)
})
