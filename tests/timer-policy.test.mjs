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

test("timer durations are bounded to 00:01 through 99:59", () => {
  const policy = loadPolicy()

  assert.equal(policy.durationMs(0, 1), 60_000)
  assert.equal(policy.durationMs(99, 59), 359_940_000)
  for (const value of [
    [0, 0],
    [-1, 1],
    [100, 0],
    [1, -1],
    [1, 60],
    [1.5, 0],
    ["1", 0],
  ]) {
    assert.equal(policy.durationMs(value[0], value[1]), null, value.join(":"))
  }
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
