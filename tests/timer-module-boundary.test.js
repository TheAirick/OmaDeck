const assert = require("node:assert/strict")
const childProcess = require("node:child_process")
const crypto = require("node:crypto")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const repositoryRoot = path.join(__dirname, "..")

function source(relativePath) {
  return fs.readFileSync(path.join(repositoryRoot, relativePath), "utf8")
}

test("Clock hosts exactly one presentation-only TimerModule boundary", () => {
  const modulePath = path.join(repositoryRoot, "modules/TimerModule.qml")
  assert.equal(fs.existsSync(modulePath), true, "TimerModule.qml must exist")

  const clock = source("modules/ClockModule.qml")
  const timerModule = source("modules/TimerModule.qml")

  assert.equal((clock.match(/TimerModule\s*\{/g) || []).length, 1)
  assert.match(clock, /TimerModule\s*\{[\s\S]*timer:\s*root\.timer/)
  assert.match(clock, /TimerModule\s*\{[\s\S]*z:\s*50/)
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

test("TimerModule owns active paused completed and close presentation", () => {
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
  assert.match(timerModule, /Accessible\.name:\s*"Close timer controls"/)
  assert.doesNotMatch(clock, /controlsOpen|id:\s*controlsContent|root\.timer\.(?:pause|resume|add|restart|cancel|dismiss)\(/)
})

test("Clock retains ambient projection and delegates opening to TimerModule", () => {
  const timerModule = source("modules/TimerModule.qml")
  const clock = source("modules/ClockModule.qml")

  assert.match(timerModule, /function openForCurrentStatus\(\)/)
  assert.match(clock, /onTapped:\s*timerPresenter\.openForCurrentStatus\(\)/)
  assert.doesNotMatch(clock, /function openTimerControls|openSetup\(|openControls\(/)
  assert.ok((clock.match(/text:\s*root\.timeText\(\)/g) || []).length >= 3)
  assert.ok((clock.match(/root\.secondaryText\(/g) || []).length >= 3)
  assert.match(clock, /id:\s*timerProgressRail/)
  assert.match(clock, /width:\s*parent\.width \* root\.timerProgress/)
})

test("offscreen TimerModule rendering matches the accepted Clock overlay", {
  skip: !fs.existsSync("/usr/lib/qt6/bin/qmltestrunner"),
}, () => {
  const baselinePath = path.join(repositoryRoot, "tests/fixtures/timer-overlay-render-hashes.json")
  const qmlTestPath = path.join(repositoryRoot, "tests/qml/tst_timer-module-render.qml")
  assert.equal(fs.existsSync(baselinePath), true, "accepted Timer overlay render hashes must exist")
  assert.equal(fs.existsSync(qmlTestPath), true, "TimerModule render-parity test must exist")
  const baseline = JSON.parse(fs.readFileSync(baselinePath, "utf8"))
  assert.equal(baseline.commit, "884efcd51ff6b89b42ff652134182da2560abb24")
  for (const tag of Object.keys(baseline.images)) {
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

  for (const [tag, expectedHash] of Object.entries(baseline.images)) {
    const imagePath = `/tmp/omadeck-timer-${tag}.png`
    assert.equal(fs.existsSync(imagePath), true, `fresh render missing for ${tag}`)
    const image = fs.readFileSync(imagePath)
    assert.equal(crypto.createHash("sha256").update(image).digest("hex"), expectedHash, tag)
  }
})
