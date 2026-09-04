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
  assert.match(controller, /interval:\s*100/)
  assert.match(controller, /command:\s*\["\/usr\/bin\/timeout"[\s\S]*"\/usr\/bin\/notify-send", "-e"/)
  assert.doesNotMatch(controller, /property var state:/)
  assert.match(controller, /function actionNow\(\)\s*\{[\s\S]*nowMs = Date\.now\(\)[\s\S]*return nowMs/)
  assert.ok((controller.match(/var actionTime = actionNow\(\)/g) || []).length >= 5)
  assert.match(controller, /function reconcileDue\(actionTime\)/)
  assert.ok((controller.match(/if \(reconcileDue\(actionTime\)\)/g) || []).length >= 5)
})

test("claimed completion starts one bounded non-overlapping chime sequence", () => {
  const controller = source("services/TimerController.qml")

  assert.match(controller, /function startCompletionEffects\(\)/)
  assert.match(controller, /completionNotification\.running = true[\s\S]*startChimeSequence\(\)/)
  assert.match(controller, /function startChimeSequence\(\)\s*\{[\s\S]*chimePlayCount = 0[\s\S]*chimeIntervalElapsed = true[\s\S]*advanceChimeSequence\(\)/)
  assert.match(controller, /TimerPolicy\.nextChimeAttempt\(chimePlayCount, completionChime\.running,\s*chimeIntervalElapsed\)/)
  assert.match(controller, /if \(decision\.shouldPlay\)[\s\S]*completionChime\.running = true/)
  assert.match(controller, /Timer\s*\{[\s\S]*id:\s*chimeSchedule[\s\S]*interval:\s*TimerPolicy\.CHIME_INTERVAL_MS[\s\S]*repeat:\s*false[\s\S]*onTriggered:[\s\S]*chimeIntervalElapsed = true[\s\S]*advanceChimeSequence\(\)/)
  assert.match(controller, /Process\s*\{[\s\S]*id:\s*completionChime[\s\S]*command:\s*TimerPolicy\.playbackCommand\(root\.completionSoundId\) \|\| \[\][\s\S]*onExited:\s*root\.advanceChimeSequence\(\)/)
})

test("dismiss and controller destruction terminate owned completion audio", () => {
  const controller = source("services/TimerController.qml")

  assert.match(controller, /function stopChimeSequence\(\)\s*\{[\s\S]*chimeSequenceActive = false[\s\S]*completionChime\.running = false/)
  assert.match(controller, /function advanceChimeSequence\(\)\s*\{\s*if \(!chimeSequenceActive\) return/)
  assert.match(controller, /function dismiss\(\)\s*\{[\s\S]*stopAllAudio\(\)[\s\S]*TimerPolicy\.cancel\(timerState\)/)
  assert.match(controller, /Component\.onDestruction:\s*root\.stopAllAudio\(\)/)
})

test("chime playback failure cannot clear the authoritative completion state", () => {
  const controller = source("services/TimerController.qml")
  const advance = controller.match(/function advanceChimeSequence\(\)[\s\S]*?\n  }\n\n  function startChimeSequence/)
  const player = controller.match(/Process\s*\{\s*id:\s*completionChime[\s\S]*?\n  }/)

  assert.ok(advance)
  assert.doesNotMatch(advance[0], /timerState|persistCandidate|completionNotification/)
  assert.ok(player)
  assert.doesNotMatch(player[0], /timerState|persistCandidate|completionNotification/)
})

test("timer sound settings use separate bounded atomic persistence", () => {
  const controller = source("services/TimerController.qml")

  assert.match(controller, /soundSettingsPath:\s*configDir \+ "\/timer-settings\.json"/)
  assert.match(controller, /id:\s*soundSettingsFile[\s\S]*path:\s*root\.soundSettingsPath[\s\S]*atomicWrites:\s*true[\s\S]*blockWrites:\s*true/)
  assert.match(controller, /TimerPolicy\.restoreSoundSettings\(raw\)/)
  assert.match(controller, /TimerPolicy\.soundSettings\(selectedSoundId\)/)
  assert.match(controller, /if \(restored\.needsRepair\)[\s\S]*persistSoundSettings\(root\.selectedSoundId\)/)
  assert.match(controller, /function selectSoundId\(candidate\)/)
  assert.match(controller, /TimerPolicy\.normalizeSoundId\(candidate\) !== candidate/)
  const timerFile = controller.match(/FileView\s*\{\s*id:\s*timerFile[\s\S]*?\n  }/)
  assert.ok(timerFile)
  assert.doesNotMatch(timerFile[0], /sound|eventId|timer-settings/)
})

test("claimed completion waits for restored sound settings without replaying persisted claims", () => {
  const controller = source("services/TimerController.qml")

  assert.match(controller, /function startCompletionEffects\(\)\s*\{[\s\S]*if \(!soundSettingsLoaded\)[\s\S]*completionEffectsPending = true[\s\S]*return/)
  assert.match(controller, /function finishSoundSettingsLoad\(\)[\s\S]*completionEffectsPending && completed[\s\S]*startCompletionEffects\(\)/)
  assert.match(controller, /function loadSoundSettings\(raw\)[\s\S]*finishSoundSettingsLoad\(\)/)
  assert.match(controller, /id:\s*soundSettingsFile[\s\S]*onLoadFailed:[\s\S]*finishSoundSettingsLoad\(\)/)
  assert.match(controller, /function load\(raw\)[\s\S]*!timerState\.notificationSent[\s\S]*deliverCompletion\(\)/)
})

test("preview replacement and completion playback are mutually exclusive", () => {
  const controller = source("services/TimerController.qml")
  const preview = controller.match(/function previewSelectedSound\(\)[\s\S]*?\n  }\n\n  function stopPreview/)

  assert.ok(preview)
  assert.match(preview[0], /TimerPolicy\.playbackCommand\(selectedSoundId\)/)
  for (const blocker of ["completionEffectsPending", "completionPending", "chimeSequenceActive", "completionChime.running"]) {
    assert.match(preview[0], new RegExp(blocker.replace(".", "\\.")), blocker)
  }
  assert.match(preview[0], /return false/)
  assert.match(controller, /if \(previewChime\.running\)[\s\S]*previewRestartPending = true[\s\S]*previewChime\.running = false/)
  assert.match(controller, /id:\s*previewChime[\s\S]*onExited:[\s\S]*previewRestartPending[\s\S]*previewChime\.running = true/)
  assert.match(controller, /function startCompletionEffects\(\)[\s\S]*completionPending = previewWasRunning[\s\S]*stopPreview\(\)/)
})

test("Silent completion launches no player and all owned audio is cleaned up", () => {
  const controller = source("services/TimerController.qml")

  assert.match(controller, /function startCompletionEffects\(\)[\s\S]*selectedSoundId === ""[\s\S]*stopChimeSequence\(\)[\s\S]*return/)
  assert.match(controller, /function stopAllAudio\(\)[\s\S]*completionPending = false[\s\S]*stopPreview\(\)[\s\S]*stopChimeSequence\(\)/)
  assert.match(controller, /function dismiss\(\)[\s\S]*stopAllAudio\(\)/)
  assert.match(controller, /Component\.onDestruction:\s*root\.stopAllAudio\(\)/)
  assert.match(controller, /id:\s*completionChime[\s\S]*command:\s*TimerPolicy\.playbackCommand\(root\.completionSoundId\) \|\| \[\]/)
  assert.match(controller, /id:\s*previewChime[\s\S]*command:\s*TimerPolicy\.playbackCommand\(root\.selectedSoundId\) \|\| \[\]/)
  assert.doesNotMatch(controller, /command:\s*\[[^\]]*selectedSoundId/)
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
  const center = source("components/DeckCenter.qml")
  const split = source("components/SplitNode.qml")
  const tile = source("components/ModuleTile.qml")

  assert.match(deck, /property var timerController: null/)
  assert.match(deck, /DeckCenter \{[\s\S]*timerController: root\.timerController/)
  assert.match(center, /SplitNode \{[\s\S]*timerController: root\.timerController/)
  assert.match(split, /property var timerController: null/)
  assert.match(split, /timerController: root\.timerController/)
  assert.match(tile, /property var timerController: null/)
  assert.match(tile, /ClockCompanionTile \{[\s\S]*timer:\s*root\.timerController/)
})

test("Clock timer UI is hidden while idle and preserves long-press editing", () => {
  const tile = source("components/ModuleTile.qml")
  const clock = source("modules/ClockModule.qml")
    + source("components/ClockCompanionTile.qml")
    + source("modules/ClockCompanionModule.qml")
  const timerModule = source("modules/TimerModule.qml")
  const timerSetup = source("modules/TimerSetupPanel.qml")

  assert.match(tile, /longPressThreshold:\s*0\.5/)
  assert.match(tile, /onLongPressed:\s*root\.controller\.beginEdit\(root\.path\)/)
  assert.match(clock, /TapHandler\s*\{[\s\S]*onTapped:\s*root\.setupRequested\(\)/)
  assert.match(clock, /onSetupRequested:\s*companionModule\.openTimer\(\)/)
  assert.match(clock, /TimerModule\s*\{[\s\S]*id:\s*timerPresenter/)
  assert.match(timerModule, /visible:\s*root\.open/)
  assert.match(timerModule, /setupOpen && timerStatus !== "idle"/)
  assert.match(clock, /root\.timerStatus !== "idle"/)
  assert.match(timerSetup, /text:\s*"Start"/)
  assert.match(timerSetup, /enabled:\s*root\.presenter\.selectedDurationValid/)
  assert.match(timerModule, /function adjustSelectedPart\(delta\)/)
  assert.match(timerSetup, /root\.presenter\.adjustSelectedPart\(-1\)/)
  assert.match(timerSetup, /root\.presenter\.adjustSelectedPart\(1\)/)
})

test("timer setup exposes one compact persisted sound selector", () => {
  const timerModule = source("modules/TimerModule.qml")
  const timerSetup = source("modules/TimerSetupPanel.qml")
  const clock = source("modules/ClockModule.qml")

  assert.match(timerModule, /id:\s*pickerContent/)
  assert.match(timerSetup, /iconText:\s*"󰎆"/)
  assert.match(timerSetup, /onClicked:\s*root\.presenter\.timer\.selectNextSound\(\)/)
  assert.doesNotMatch(timerSetup, /text:\s*"Preview"|Select previous timer sound/)
  assert.doesNotMatch(clock, /selectedSound|Preview|Select previous timer sound|Select next timer sound/)
})

test("the single sound selector remains a semantic 48 pixel target", () => {
  const timerSetup = source("modules/TimerSetupPanel.qml")
  const markerIndex = timerSetup.indexOf('Accessible.name: "Choose next timer sound"')
  const buttonStart = timerSetup.lastIndexOf("Button {", markerIndex)
  const buttonEnd = timerSetup.indexOf("\n    }", markerIndex)
  assert.ok(markerIndex !== -1 && buttonStart !== -1 && buttonEnd !== -1)
  const button = timerSetup.slice(buttonStart, buttonEnd)
  assert.match(button, /height:\s*root\.touchTarget/)
  assert.match(button, /Accessible\.role:\s*Accessible\.Button/)
  assert.match(button, /root\.presenter\.timer\.soundSettingsLoaded/)
})

test("the compact Clock exposes ambient timer state without duplicating countdown text", () => {
  const clock = source("modules/ClockModule.qml")

  assert.equal((clock.match(/text:\s*root\.timeText\(\)/g) || []).length, 1)
  assert.match(clock, /timerStatus === "paused"[\s\S]*"Timer paused"/)
  assert.match(clock, /timerStatus === "active"[\s\S]*"Timer running"/)
  assert.match(clock, /return "Time's up"/)
  assert.doesNotMatch(clock, /timerRemainingText|remainingText/)
  assert.match(clock, /width:\s*parent\.width \* root\.timerProgress/)
})

test("active timer progress starts promptly and moves smoothly", () => {
  const controller = source("services/TimerController.qml")
  const clock = source("modules/ClockModule.qml")

  assert.match(controller, /Timer\s*\{[\s\S]*interval:\s*100[\s\S]*running:\s*root\.active/)
  assert.match(clock, /width:\s*parent\.width \* root\.timerProgress[\s\S]*Behavior on width\s*\{[\s\S]*duration:\s*100[\s\S]*Easing\.Linear/)
})

test("primary timer controls are semantic 48 pixel touch targets", () => {
  const clock = source("modules/ClockModule.qml")
  const timerPresentation = clock + source("modules/TimerModule.qml")
    + source("modules/TimerSetupPanel.qml")

  assert.match(timerPresentation, /readonly property int touchTarget:\s*48/)
  assert.ok((timerPresentation.match(/height:\s*root\.touchTarget/g) || []).length >= 8)
  assert.ok((timerPresentation.match(/Accessible\.role:\s*Accessible\.Button/g) || []).length >= 8)
  for (const name of ["Add 5 minutes", "Cancel timer", "Dismiss timer"]) {
    assert.match(timerPresentation, new RegExp(`Accessible\\.name:\\s*"${name}"`), name)
  }
  assert.match(timerPresentation, /Accessible\.name:\s*root\.timerStatus === "paused" \? "Resume timer" : "Pause timer"/)
  assert.doesNotMatch(timerPresentation, /Accessible\.name:\s*"Restart timer"/)
})

test("timer controls remain reachable when a Clock tile is constrained", () => {
  const timerModule = source("modules/TimerModule.qml")
  const responsivePanel = source("components/ResponsivePanel.qml")

  assert.match(timerModule, /ResponsivePanel\s*\{[\s\S]*id:\s*timerViewport/)
  assert.match(timerModule, /maximumContentWidth:\s*Style\.space\(620\)/)
  assert.match(responsivePanel, /ResponsiveLayout\.fitScale\(/)
  assert.match(responsivePanel, /anchors\.centerIn:\s*parent/)
  assert.doesNotMatch(timerModule, /Flickable/)
})
