import QtQuick
import Quickshell
import Quickshell.Io
import "TimerPolicy.js" as TimerPolicy

Item {
  id: root

  readonly property string configDir: Quickshell.env("HOME") + "/.config/omadeck"
  readonly property string timerPath: configDir + "/timer.json"
  readonly property string soundSettingsPath: configDir + "/timer-settings.json"

  property var timerState: TimerPolicy.idleState()
  property double nowMs: Date.now()
  property bool loaded: false
  property bool directoryReady: false
  property bool lastSaveSucceeded: false
  property string lastSaveError: ""
  property int chimePlayCount: 0
  property bool chimeSequenceActive: false
  property bool chimeIntervalElapsed: false
  property string selectedSoundId: TimerPolicy.DEFAULT_SOUND_ID
  property string completionSoundId: TimerPolicy.DEFAULT_SOUND_ID
  property bool soundSettingsLoaded: false
  property bool soundSaveSucceeded: false
  property string soundSaveError: ""
  property bool previewRestartPending: false
  property bool completionPending: false
  property bool completionEffectsPending: false

  readonly property string status: timerState ? timerState.status : "idle"
  readonly property bool active: status === "active"
  readonly property bool paused: status === "paused"
  readonly property bool completed: status === "completed"
  readonly property double remainingMs: TimerPolicy.remainingMs(timerState, nowMs)
  readonly property string remainingText: TimerPolicy.formatRemaining(remainingMs)
  readonly property real progress: TimerPolicy.progress(timerState, nowMs)
  readonly property string selectedSoundName: TimerPolicy.soundLabel(selectedSoundId)

  function actionNow() {
    nowMs = Date.now()
    return nowMs
  }

  function snapshot() {
    return {
      status: status,
      remainingMs: remainingMs,
      remainingText: remainingText,
      progress: progress,
      originalDurationMs: timerState ? timerState.originalDurationMs : 0,
      currentDurationMs: timerState ? timerState.currentDurationMs : 0,
      notificationSent: timerState ? timerState.notificationSent : false
    }
  }

  function result(ok, error) {
    var value = { ok: ok, state: snapshot() }
    if (error) value.error = String(error)
    return value
  }

  function persistCandidate(candidate) {
    if (!directoryReady) return false
    var previous = timerState
    timerState = candidate
    lastSaveSucceeded = false
    // 0.3.1 retains failed write text in its comparison cache. Invalidate it
    // before retrying the identical claim, otherwise setText emits no signal.
    if (lastSaveError !== "") {
      timerFile.path = ""
      timerFile.path = timerPath
    }
    lastSaveError = ""
    try {
      timerFile.setText(JSON.stringify(timerState, null, 2) + "\n")
    } catch (error) {
      lastSaveError = String(error)
    }
    if (!lastSaveSucceeded) timerState = previous
    return lastSaveSucceeded
  }

  function persistSoundSettings(candidate) {
    if (!directoryReady) return false
    var previous = selectedSoundId
    selectedSoundId = TimerPolicy.normalizeSoundId(candidate)
    soundSaveSucceeded = false
    soundSaveError = ""
    try {
      soundSettingsFile.setText(JSON.stringify(TimerPolicy.soundSettings(selectedSoundId), null, 2) + "\n")
    } catch (error) {
      soundSaveError = String(error)
    }
    if (!soundSaveSucceeded) selectedSoundId = previous
    return soundSaveSucceeded
  }

  function loadSoundSettings(raw) {
    var restored = TimerPolicy.restoreSoundSettings(raw)
    stopPreview()
    selectedSoundId = restored.eventId
    soundSettingsLoaded = true
    if (restored.needsRepair) persistSoundSettings(root.selectedSoundId)
    finishSoundSettingsLoad()
  }

  function finishSoundSettingsLoad() {
    if (completionEffectsPending && completed) {
      completionEffectsPending = false
      startCompletionEffects()
    }
  }

  function selectSound(direction) {
    if (!soundSettingsLoaded) return false
    stopPreview()
    return persistSoundSettings(TimerPolicy.cycleSoundId(selectedSoundId, direction))
  }

  function selectSoundId(candidate) {
    if (!soundSettingsLoaded || typeof candidate !== "string"
        || TimerPolicy.normalizeSoundId(candidate) !== candidate)
      return false
    stopPreview()
    return persistSoundSettings(candidate)
  }

  function selectPreviousSound() {
    return selectSound(-1)
  }

  function selectNextSound() {
    return selectSound(1)
  }

  function previewSelectedSound() {
    if (!soundSettingsLoaded || completionEffectsPending || completionPending
        || chimeSequenceActive || completionChime.running)
      return false
    var command = TimerPolicy.playbackCommand(selectedSoundId)
    if (!command) {
      stopPreview()
      return false
    }
    if (previewChime.running) {
      previewRestartPending = true
      previewChime.running = false
    } else {
      previewChime.running = true
    }
    return true
  }

  function stopPreview() {
    previewRestartPending = false
    previewChime.running = false
  }

  function apply(candidate, rejectedMessage) {
    if (!loaded) return result(false, "Timer state is not ready")
    if (!candidate) return result(false, rejectedMessage)
    if (!persistCandidate(candidate)) return result(false, "Timer state could not be saved")
    return result(true, "")
  }

  function reconcileDue(actionTime) {
    var next = TimerPolicy.completeIfDue(timerState, actionTime)
    if (next === timerState) return false
    // The elapsed deadline is authoritative even if claiming the alert fails.
    // Keep it completed/unclaimed so recovery uses the slow retry, not 100 ms ticks.
    timerState = next
    var claim = TimerPolicy.claimCompletion(next)
    if (persistCandidate(claim.state) && claim.shouldNotify)
      startCompletionEffects()
    return true
  }

  function start(hours, minutes, seconds) {
    if (status !== "idle") return result(false, "A timer already exists")
    stopPreview()
    var actionTime = actionNow()
    return apply(TimerPolicy.start(hours, minutes, seconds === undefined ? 0 : seconds,
                                   actionTime), "Invalid timer duration")
  }

  function pause() {
    var actionTime = actionNow()
    if (reconcileDue(actionTime)) return result(false, "Timer has completed")
    return apply(TimerPolicy.pause(timerState, actionTime), "Timer is not running")
  }

  function resume() {
    var actionTime = actionNow()
    if (reconcileDue(actionTime)) return result(false, "Timer has completed")
    return apply(TimerPolicy.resume(timerState, actionTime), "Timer is not paused")
  }

  function add(minutes) {
    var actionTime = actionNow()
    if (reconcileDue(actionTime)) return result(false, "Timer has completed")
    return apply(TimerPolicy.addMinutes(timerState, minutes, actionTime), "Timer cannot be extended")
  }

  function restart() {
    var actionTime = actionNow()
    if (reconcileDue(actionTime)) return result(false, "Timer has completed")
    return apply(TimerPolicy.restart(timerState, actionTime), "Timer cannot be restarted")
  }

  function cancel() {
    if (status !== "active" && status !== "paused") return result(false, "No active timer to cancel")
    var actionTime = actionNow()
    if (reconcileDue(actionTime)) return result(false, "Timer has completed")
    return apply(TimerPolicy.cancel(timerState), "Timer cannot be cancelled")
  }

  function dismiss() {
    if (status !== "completed") return result(false, "No completed timer to dismiss")
    stopAllAudio()
    return apply(TimerPolicy.cancel(timerState), "Timer cannot be dismissed")
  }

  function advanceChimeSequence() {
    if (!chimeSequenceActive) return
    var decision = TimerPolicy.nextChimeAttempt(chimePlayCount, completionChime.running,
                                                chimeIntervalElapsed)
    chimePlayCount = decision.playCount
    chimeSequenceActive = decision.shouldContinue
    if (decision.shouldPlay) {
      chimeIntervalElapsed = false
      completionChime.running = true
    }
  }

  function startChimeSequence() {
    stopChimeSequence()
    if (!TimerPolicy.playbackCommand(completionSoundId)) return
    chimePlayCount = 0
    chimeIntervalElapsed = true
    chimeSequenceActive = true
    advanceChimeSequence()
  }

  function stopChimeSequence() {
    chimeSequenceActive = false
    chimeIntervalElapsed = false
    completionChime.running = false
  }

  function stopAllAudio() {
    completionPending = false
    completionEffectsPending = false
    stopPreview()
    stopChimeSequence()
  }

  function startCompletionEffects() {
    if (!soundSettingsLoaded) {
      completionEffectsPending = true
      return
    }
    completionEffectsPending = false
    completionNotification.running = true
    completionSoundId = selectedSoundId
    var previewWasRunning = previewChime.running
    completionPending = previewWasRunning
    stopPreview()
    if (selectedSoundId === "") {
      completionPending = false
      stopChimeSequence()
      return
    }
    if (previewWasRunning) return
    startChimeSequence()
  }

  function deliverCompletion() {
    var claim = TimerPolicy.claimCompletion(timerState)
    if (!claim.shouldNotify) return
    if (!persistCandidate(claim.state)) return
    startCompletionEffects()
  }

  function updateClock() {
    actionNow()
    reconcileDue(nowMs)
  }

  function load(raw) {
    var loadTime = actionNow()
    timerState = TimerPolicy.restore(raw, loadTime)
    loaded = true
    if (timerState.status === "completed" && !timerState.notificationSent)
      deliverCompletion()
  }

  // Restored overdue timers are already completed, so the active clock no
  // longer ticks. Retry only unclaimed completions, at a bounded I/O cadence.
  Timer {
    interval: 5000
    running: root.loaded && root.directoryReady && root.completed
             && !root.timerState.notificationSent
    repeat: true
    onTriggered: root.deliverCompletion()
  }

  Process {
    id: mkdirProcess
    command: ["/usr/bin/mkdir", "-p", root.configDir]
    onExited: {
      root.directoryReady = true
      timerFile.reload()
      soundSettingsFile.reload()
    }
  }

  FileView {
    id: timerFile
    path: root.timerPath
    watchChanges: true
    atomicWrites: true
    blockWrites: true
    printErrors: false
    onSaved: root.lastSaveSucceeded = true
    onSaveFailed: function(error) {
      root.lastSaveSucceeded = false
      root.lastSaveError = String(error)
    }
    onLoaded: root.load(text())
    onLoadFailed: {
      if (!root.directoryReady) return
      root.timerState = TimerPolicy.idleState()
      root.loaded = true
      root.persistCandidate(root.timerState)
    }
    onFileChanged: reload()
  }

  FileView {
    id: soundSettingsFile
    path: root.soundSettingsPath
    watchChanges: true
    atomicWrites: true
    blockWrites: true
    printErrors: false
    onSaved: root.soundSaveSucceeded = true
    onSaveFailed: function(error) {
      root.soundSaveSucceeded = false
      root.soundSaveError = String(error)
    }
    onLoaded: root.loadSoundSettings(text())
    onLoadFailed: {
      if (!root.directoryReady) return
      root.selectedSoundId = TimerPolicy.DEFAULT_SOUND_ID
      root.soundSettingsLoaded = true
      root.persistSoundSettings(root.selectedSoundId)
      root.finishSoundSettingsLoad()
    }
    onFileChanged: reload()
  }

  Timer {
    interval: 100
    running: root.active
    repeat: true
    triggeredOnStart: true
    onTriggered: root.updateClock()
  }

  Timer {
    id: chimeSchedule
    interval: TimerPolicy.CHIME_INTERVAL_MS
    running: root.chimeSequenceActive && !root.chimeIntervalElapsed
    repeat: false
    triggeredOnStart: false
    onTriggered: {
      root.chimeIntervalElapsed = true
      root.advanceChimeSequence()
    }
  }

  Process {
    id: completionNotification
    command: ["/usr/bin/timeout", "--signal=TERM", "--kill-after=1s", "3s",
              "/usr/bin/notify-send", "-e", "-t", "6000", "-a", "OmaDeck", "-i", "alarm-symbolic",
              "Time's up", "OmaDeck timer finished"]
  }

  Process {
    id: completionChime
    command: TimerPolicy.playbackCommand(root.completionSoundId) || []
    onExited: root.advanceChimeSequence()
  }

  Process {
    id: previewChime
    command: TimerPolicy.playbackCommand(root.selectedSoundId) || []
    onExited: {
      if (root.completionPending) {
        root.completionPending = false
        root.startChimeSequence()
      } else if (root.previewRestartPending) {
        root.previewRestartPending = false
        previewChime.running = true
      }
    }
  }

  Component.onCompleted: mkdirProcess.running = true
  Component.onDestruction: root.stopAllAudio()
}
