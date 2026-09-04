import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"
import test from "node:test"

function loadPolicy() {
  const source = fs
    .readFileSync(new URL("../services/TimerPolicy.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*/m, "")
  const context = {}
  vm.runInNewContext(source, context, { filename: "TimerPolicy.js" })
  return context
}

test("timer durations are bounded to 00:00:01 through 99:59:59", () => {
  const policy = loadPolicy()

  assert.equal(policy.durationMs(0, 0, 1), 1_000)
  assert.equal(policy.durationMs(0, 1), 60_000)
  assert.equal(policy.durationMs(99, 59, 59), 359_999_000)
  for (const value of [
    [0, 0, 0],
    [-1, 1],
    [100, 0],
    [1, -1],
    [1, 60],
    [1, 0, -1],
    [1, 0, 60],
    [1.5, 0],
    ["1", 0],
  ]) {
    assert.equal(policy.durationMs(value[0], value[1], value[2]), null, value.join(":"))
  }
})

test("timer start accepts exact seconds while preserving minute-only callers", () => {
  const policy = loadPolicy()

  assert.equal(policy.start(0, 0, 5, 1_000).deadlineMs, 6_000)
  assert.equal(policy.start(0, 5, 1_000).deadlineMs, 301_000)
})

test("active timers derive remaining time and progress from the deadline", () => {
  const policy = loadPolicy()
  const started = policy.start(0, 5, 1_000)

  assert.equal(started.status, "active")
  assert.equal(started.deadlineMs, 301_000)
  assert.equal(policy.remainingMs(started, 121_000), 180_000)
  assert.equal(policy.progress(started, 121_000), 0.6)
  assert.equal(policy.remainingMs(started, 400_000), 0)
  assert.equal(policy.progress(started, 400_000), 0)
})

test("remaining time formatting preserves the final second and multi-hour context", () => {
  const policy = loadPolicy()

  assert.equal(policy.formatRemaining(1), "0:01")
  assert.equal(policy.formatRemaining(999), "0:01")
  assert.equal(policy.formatRemaining(60_000), "1:00")
  assert.equal(policy.formatRemaining(3_661_000), "1:01:01")
  assert.equal(policy.formatRemaining(0), "0:00")
})

test("pause and resume preserve remaining time without accumulating ticks", () => {
  const policy = loadPolicy()
  const started = policy.start(0, 5, 1_000)
  const paused = policy.pause(started, 121_000)

  assert.equal(paused.status, "paused")
  assert.equal(paused.pausedRemainingMs, 180_000)
  assert.equal(policy.remainingMs(paused, 9_999_999), 180_000)

  const resumed = policy.resume(paused, 500_000)
  assert.equal(resumed.status, "active")
  assert.equal(resumed.deadlineMs, 680_000)
})

test("adding five minutes is bounded and restart uses the original duration", () => {
  const policy = loadPolicy()
  const started = policy.start(0, 15, 1_000)
  const extended = policy.addMinutes(started, 5, 301_000)

  assert.equal(policy.remainingMs(extended, 301_000), 900_000)
  assert.equal(extended.currentDurationMs, 1_200_000)
  assert.equal(extended.originalDurationMs, 900_000)

  const restarted = policy.restart(extended, 500_000)
  assert.equal(restarted.status, "active")
  assert.equal(restarted.deadlineMs, 1_400_000)
  assert.equal(restarted.currentDurationMs, 900_000)

  const maximum = policy.start(99, 59, 0)
  assert.equal(policy.addMinutes(maximum, 5, 0), null)
  assert.equal(policy.addMinutes(started, 0, 0), null)
})

test("cancel returns a clean idle state", () => {
  const policy = loadPolicy()
  const cancelled = policy.cancel(policy.start(0, 5, 0))

  assert.equal(cancelled.status, "idle")
  assert.equal(cancelled.deadlineMs, 0)
  assert.equal(cancelled.originalDurationMs, 0)
})

test("time jumps complete an active timer from its wall-clock deadline", () => {
  const policy = loadPolicy()
  const started = policy.start(0, 1, 10_000)

  assert.equal(policy.completeIfDue(started, 69_999).status, "active")
  const completed = policy.completeIfDue(started, 70_000)
  assert.equal(completed.status, "completed")
  assert.equal(completed.notificationSent, false)
  assert.equal(policy.pause(started, 70_000), null)
  assert.equal(policy.addMinutes(started, 5, 70_000), null)
  assert.equal(policy.restart(started, 70_000), null)
})

test("overdue active persistence restores completed while corrupt state fails closed", () => {
  const policy = loadPolicy()
  const active = policy.start(0, 5, 1_000)
  const restored = policy.restore(JSON.stringify(active), 400_000)

  assert.equal(restored.status, "completed")
  assert.equal(restored.originalDurationMs, 300_000)

  for (const raw of [
    "not json",
    "{}",
    JSON.stringify({ ...active, status: "unknown" }),
    JSON.stringify({ ...active, deadlineMs: Number.POSITIVE_INFINITY }),
    JSON.stringify({ ...active, deadlineMs: active.deadlineMs + active.currentDurationMs + 1 }),
    JSON.stringify({ ...active, currentDurationMs: 999_999_999 }),
    JSON.stringify({ ...active, status: "paused", deadlineMs: 0, pausedRemainingMs: active.currentDurationMs + 1 }),
  ]) {
    assert.equal(policy.restore(raw, 0).status, "idle")
  }
})

test("completion notification can be claimed only once across persistence", () => {
  const policy = loadPolicy()
  const completed = policy.completeIfDue(policy.start(0, 1, 0), 60_000)
  const first = policy.claimCompletion(completed)

  assert.equal(first.shouldNotify, true)
  assert.equal(first.state.notificationSent, true)

  const restored = policy.restore(JSON.stringify(first.state), 70_000)
  const second = policy.claimCompletion(restored)
  assert.equal(second.shouldNotify, false)
  assert.equal(second.state.notificationSent, true)
})

test("completion chimes use three bounded launches at four-second minimum intervals", () => {
  const policy = loadPolicy()
  let playCount = 0
  const decisions = []

  for (let slot = 0; slot < 4; slot += 1) {
    const decision = policy.nextChimeAttempt(playCount, false, true)
    decisions.push(decision)
    playCount = decision.playCount
  }

  assert.equal(policy.CHIME_INTERVAL_MS, 4_000)
  assert.deepEqual(
    decisions.map(({ playCount, shouldPlay, shouldContinue }) => ({
      playCount,
      shouldPlay,
      shouldContinue,
    })),
    [
      { playCount: 1, shouldPlay: true, shouldContinue: true },
      { playCount: 2, shouldPlay: true, shouldContinue: true },
      { playCount: 3, shouldPlay: true, shouldContinue: false },
      { playCount: 3, shouldPlay: false, shouldContinue: false },
    ],
  )
})

test("a player still busy at four seconds waits then still launches all three chimes", () => {
  const policy = loadPolicy()
  let playCount = 0
  let running = false
  let launches = 0

  function advance(intervalElapsed) {
    const decision = policy.nextChimeAttempt(playCount, running, intervalElapsed)
    playCount = decision.playCount
    if (decision.shouldPlay) {
      launches += 1
      running = true
    }
    return decision
  }

  assert.equal(advance(true).shouldPlay, true)
  assert.equal(advance(true).shouldPlay, false)
  assert.equal(playCount, 1)

  running = false
  assert.equal(advance(true).shouldPlay, true)
  assert.equal(advance(true).shouldPlay, false)

  running = false
  const final = advance(true)

  assert.equal(final.shouldPlay, true)
  assert.equal(final.shouldContinue, false)
  assert.equal(launches, 3)
  assert.equal(playCount, 3)
})

test("a player exit before the minimum interval cannot launch the next chime", () => {
  const policy = loadPolicy()

  const waiting = policy.nextChimeAttempt(1, false, false)

  assert.equal(waiting.playCount, 1)
  assert.equal(waiting.shouldPlay, false)
  assert.equal(waiting.shouldContinue, true)
})

test("timer sounds expose only the curated labels and event IDs", () => {
  const policy = loadPolicy()

  assert.deepEqual(
    Array.from(policy.soundOptions(), ({ label, eventId }) => ({ label, eventId })),
    [
      { label: "Silent", eventId: "" },
      { label: "Alarm", eventId: "alarm-clock-elapsed" },
      { label: "Complete", eventId: "complete" },
      { label: "Bell", eventId: "bell" },
      { label: "Ring", eventId: "phone-incoming-call" },
      { label: "Warning", eventId: "dialog-warning" },
    ],
  )
  assert.equal(policy.normalizeSoundId("complete"), "complete")
  assert.equal(policy.normalizeSoundId("/tmp/untrusted.oga"), "complete")
  assert.equal(policy.soundLabel("phone-incoming-call"), "Ring")
})

test("timer sound cycling wraps in both directions", () => {
  const policy = loadPolicy()

  assert.equal(policy.cycleSoundId("", -1), "dialog-warning")
  assert.equal(policy.cycleSoundId("dialog-warning", 1), "")
  assert.equal(policy.cycleSoundId("complete", -1), "alarm-clock-elapsed")
  assert.equal(policy.cycleSoundId("complete", 1), "bell")
})

test("timer sound settings default and repair corrupt or invalid persistence", () => {
  const policy = loadPolicy()

  for (const raw of ["", "not json", "{}", JSON.stringify({ version: 2, eventId: "bell" }),
    JSON.stringify({ version: 1, eventId: "/tmp/untrusted.oga" })]) {
    const restored = policy.restoreSoundSettings(raw)
    assert.equal(restored.eventId, "complete")
    assert.equal(restored.needsRepair, true)
  }

  const silent = policy.restoreSoundSettings(JSON.stringify({ version: 1, eventId: "" }))
  assert.equal(silent.eventId, "")
  assert.equal(silent.needsRepair, false)
  assert.equal(JSON.stringify(policy.soundSettings("bell")), '{"version":1,"eventId":"bell"}')
})

test("sound commands are static deadline-bounded Canberra invocations and Silent has none", () => {
  const policy = loadPolicy()
  const prefix = [
    "/usr/bin/timeout", "--signal=TERM", "--kill-after=1s", "3s",
    "/usr/bin/canberra-gtk-play",
  ]

  assert.equal(policy.playbackCommand(""), null)
  assert.deepEqual(Array.from(policy.playbackCommand("bell")), [
    ...prefix, "-i", "bell", "-d", "OmaDeck timer sound",
  ])
  assert.deepEqual(Array.from(policy.playbackCommand("/tmp/untrusted.oga")), [
    ...prefix, "-i", "complete", "-d", "OmaDeck timer sound",
  ])
  for (const option of policy.soundOptions()) {
    const command = policy.playbackCommand(option.eventId)
    if (option.eventId === "") continue
    assert.deepEqual(Array.from(command.slice(0, prefix.length)), prefix)
    assert.equal(command[prefix.length], "-i")
    assert.equal(command[prefix.length + 1], option.eventId)
    assert.equal(command.includes("-f"), false)
  }
})
