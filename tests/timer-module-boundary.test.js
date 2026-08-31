const assert = require("node:assert/strict")
const childProcess = require("node:child_process")

const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const repositoryRoot = path.join(__dirname, "..")

function source(relativePath) {
  return fs.readFileSync(path.join(repositoryRoot, relativePath), "utf8")
}

test("Clock companion hosts exactly one presentation-only TimerModule boundary", () => {
  const modulePath = path.join(repositoryRoot, "modules/TimerModule.qml")
  assert.equal(fs.existsSync(modulePath), true, "TimerModule.qml must exist")

  const clock = source("modules/ClockCompanionModule.qml")
  const timerModule = source("modules/TimerModule.qml")

  assert.equal((clock.match(/TimerModule\s*\{/g) || []).length, 1)
  assert.match(clock, /TimerModule\s*\{[\s\S]*timer:\s*root\.timer/)
  assert.match(clock, /TimerModule\s*\{[\s\S]*companionMode:\s*true/)
  assert.match(timerModule, /property var timer:\s*null/)
})

test("TimerModule owns setup draft and forwarding without controller lifecycle", () => {
  const timerModule = source("modules/TimerModule.qml")
  const clock = source("modules/ClockModule.qml")
  const service = source("Service.qml")

  assert.match(timerModule, /property int selectedHours:\s*0/)
  assert.match(timerModule, /property int selectedMinutes:\s*5/)
  assert.match(timerModule, /readonly property bool selectedDurationValid:/)
  assert.match(timerModule, /function setPreset\(minutes\)/)
  assert.match(timerModule, /function startSelectedTimer\(\)/)
  assert.match(timerModule, /id:\s*pickerContent/)
  assert.match(timerModule, /text:\s*"Preview"/)
  assert.match(timerModule, /text:\s*"Start"/)

  for (const forbidden of [
    /\bProcess\s*\{/,
    /\bFileView\s*\{/,
    /\bTimerController\s*\{/,
    /TimerPolicy|IpcHandler|notification|persistence/i,
  ]) {
    assert.doesNotMatch(timerModule, forbidden)
  }

  assert.equal((service.match(/TimerController\s*\{/g) || []).length, 1)
  assert.doesNotMatch(clock, /selectedHours|selectedMinutes|selectedDurationValid|id:\s*pickerContent/)
})

test("TimerModule owns active paused and completed companion presentation", () => {
  const timerModule = source("modules/TimerModule.qml")
  const clock = source("modules/ClockModule.qml")

  assert.match(timerModule, /property bool controlsOpen:\s*false/)
  assert.match(timerModule, /function openControls\(\)/)
  assert.match(timerModule, /id:\s*controlsContent/)
  assert.match(timerModule, /timerStatus === "active" \|\| root\.timerStatus === "paused"/)
  assert.match(timerModule, /timerStatus === "completed"/)
  for (const action of ["pause", "resume", "add", "restart", "cancel", "dismiss"]) {
    assert.match(timerModule, new RegExp(`root\\.timer\\.${action}\\(`), action)
  }
  assert.doesNotMatch(timerModule, /Accessible\.name:\s*"Close timer controls"/)
  assert.doesNotMatch(clock, /controlsOpen|id:\s*controlsContent|root\.timer\.(?:pause|resume|add|restart|cancel|dismiss)\(/)
})

test("compact Clock retains ambient projection and delegates setup opening to TimerModule", () => {
  const timerModule = source("modules/TimerModule.qml")
  const clock = source("modules/ClockModule.qml")
  const tile = source("components/ClockCompanionTile.qml")
  const companion = source("modules/ClockCompanionModule.qml")

  assert.match(timerModule, /function openForCurrentStatus\(\)/)
  assert.match(clock, /onTapped:\s*root\.setupRequested\(\)/)
  assert.match(tile, /onSetupRequested:\s*companionModule\.openSetup\(\)/)
  assert.match(companion, /function openSetup\(\) \{ timerPresenter\.openSetup\(\) \}/)
  assert.doesNotMatch(clock, /function (?:openTimerControls|openSetup|openControls)\(/)
  assert.equal((clock.match(/text:\s*root\.timeText\(\)/g) || []).length, 1)
  assert.match(clock, /root\.timerSummary\(\)/)
  assert.match(clock, /width:\s*parent\.width \* root\.timerProgress/)
})

test("offscreen TimerModule rendering remains valid in the Clock companion", {
  skip: !fs.existsSync("/usr/lib/qt6/bin/qmltestrunner"),
}, () => {
  const qmlTestPath = path.join(repositoryRoot, "tests/qml/tst_timer-module-render.qml")
  assert.equal(fs.existsSync(qmlTestPath), true, "TimerModule render-parity test must exist")
  const tags = [
    "setup-normal", "setup-constrained", "setup-short-wide",
    "active-normal", "active-constrained", "active-short-wide",
    "paused-normal", "paused-constrained", "paused-short-wide",
    "completed-normal", "completed-constrained", "completed-short-wide",
  ]
  for (const tag of tags) {
    fs.rmSync(`/tmp/omadeck-timer-${tag}.png`, { force: true })
  }

  const result = childProcess.spawnSync("/usr/lib/qt6/bin/qmltestrunner", [
    "-silent",
    "-input",
    "tests/qml/tst_timer-module-render.qml",
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

  for (const tag of tags) {
    const imagePath = `/tmp/omadeck-timer-${tag}.png`
    assert.equal(fs.existsSync(imagePath), true, `fresh render missing for ${tag}`)
    assert.ok(fs.statSync(imagePath).size > 1000, tag)
  }
})
