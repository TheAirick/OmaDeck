.pragma library

var MAX_HOURS = 99
var MAX_MINUTES = 59
var MAX_SECONDS = 59
var MAX_DURATION_MS = (MAX_HOURS * 3600 + MAX_MINUTES * 60 + MAX_SECONDS) * 1000
var CHIME_ATTEMPT_LIMIT = 3
var CHIME_INTERVAL_MS = 4000
var DEFAULT_SOUND_ID = "complete"
var TIMER_SOUNDS = [
  { label: "Silent", eventId: "" },
  { label: "Alarm", eventId: "alarm-clock-elapsed" },
  { label: "Complete", eventId: "complete" },
  { label: "Bell", eventId: "bell" },
  { label: "Ring", eventId: "phone-incoming-call" },
  { label: "Warning", eventId: "dialog-warning" }
]

function soundOptions() {
  return TIMER_SOUNDS.map(function(option) {
    return { label: option.label, eventId: option.eventId }
  })
}

function soundIndex(eventId) {
  for (var index = 0; index < TIMER_SOUNDS.length; index++) {
    if (TIMER_SOUNDS[index].eventId === eventId) return index
  }
  return -1
}

function normalizeSoundId(eventId) {
  var candidate = typeof eventId === "string" ? eventId : DEFAULT_SOUND_ID
  return soundIndex(candidate) === -1 ? DEFAULT_SOUND_ID : candidate
}

function soundLabel(eventId) {
  return TIMER_SOUNDS[soundIndex(normalizeSoundId(eventId))].label
}

function cycleSoundId(eventId, direction) {
  var index = soundIndex(normalizeSoundId(eventId))
  var step = direction < 0 ? -1 : 1
  return TIMER_SOUNDS[(index + step + TIMER_SOUNDS.length) % TIMER_SOUNDS.length].eventId
}

function soundSettings(eventId) {
  return { version: 1, eventId: normalizeSoundId(eventId) }
}

function restoreSoundSettings(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || parsed.version !== 1 || typeof parsed.eventId !== "string"
        || soundIndex(parsed.eventId) === -1)
      throw new Error("invalid timer sound settings")
    return { eventId: parsed.eventId, needsRepair: false }
  } catch (error) {
    return { eventId: DEFAULT_SOUND_ID, needsRepair: true }
  }
}

function playbackCommand(eventId) {
  var prefix = ["/usr/bin/timeout", "--signal=TERM", "--kill-after=1s", "3s",
                "/usr/bin/canberra-gtk-play"]
  switch (normalizeSoundId(eventId)) {
  case "": return null
  case "alarm-clock-elapsed":
    return prefix.concat(["-i", "alarm-clock-elapsed", "-d", "OmaDeck timer sound"])
  case "bell":
    return prefix.concat(["-i", "bell", "-d", "OmaDeck timer sound"])
  case "phone-incoming-call":
    return prefix.concat(["-i", "phone-incoming-call", "-d", "OmaDeck timer sound"])
  case "dialog-warning":
    return prefix.concat(["-i", "dialog-warning", "-d", "OmaDeck timer sound"])
  default:
    return prefix.concat(["-i", "complete", "-d", "OmaDeck timer sound"])
  }
}

function isInteger(value) {
  return typeof value === "number" && isFinite(value) && Math.floor(value) === value
}

function durationMs(hours, minutes, seconds) {
  var normalizedSeconds = seconds === undefined ? 0 : seconds
  if (!isInteger(hours) || !isInteger(minutes) || !isInteger(normalizedSeconds)) return null
  if (hours < 0 || hours > MAX_HOURS || minutes < 0 || minutes > MAX_MINUTES
      || normalizedSeconds < 0 || normalizedSeconds > MAX_SECONDS) return null
  if (hours === 0 && minutes === 0 && normalizedSeconds === 0) return null
  return (hours * 3600 + minutes * 60 + normalizedSeconds) * 1000
}

function idleState() {
  return {
    version: 1,
    status: "idle",
    originalDurationMs: 0,
    currentDurationMs: 0,
    deadlineMs: 0,
    pausedRemainingMs: 0,
    notificationSent: false
  }
}

function start(hours, minutes, seconds, nowMs) {
  // Keep the original three-argument policy call compatible with existing IPC
  // and persisted-state tests: start(hours, minutes, nowMs).
  var actionTime = nowMs
  var requestedSeconds = seconds
  if (nowMs === undefined) {
    actionTime = seconds
    requestedSeconds = 0
  }
  var requestedDuration = durationMs(hours, minutes, requestedSeconds)
  if (requestedDuration === null || !isFinite(actionTime)) return null
  return {
    version: 1,
    status: "active",
    originalDurationMs: requestedDuration,
    currentDurationMs: requestedDuration,
    deadlineMs: actionTime + requestedDuration,
    pausedRemainingMs: 0,
    notificationSent: false
  }
}

function remainingMs(state, nowMs) {
  if (!state) return 0
  if (state.status === "active") return Math.max(0, state.deadlineMs - nowMs)
  if (state.status === "paused") return Math.max(0, state.pausedRemainingMs)
  return 0
}

function progress(state, nowMs) {
  if (!state || !(state.currentDurationMs > 0)) return 0
  return Math.max(0, Math.min(1, remainingMs(state, nowMs) / state.currentDurationMs))
}

function pad2(value) {
  return value < 10 ? "0" + value : String(value)
}

function formatRemaining(milliseconds) {
  var seconds = Math.max(0, Math.ceil(Number(milliseconds) / 1000))
  var hours = Math.floor(seconds / 3600)
  var minutes = Math.floor((seconds % 3600) / 60)
  var remainder = seconds % 60
  if (hours > 0) return hours + ":" + pad2(minutes) + ":" + pad2(remainder)
  return minutes + ":" + pad2(remainder)
}

function copyState(state) {
  return JSON.parse(JSON.stringify(state))
}

function pause(state, nowMs) {
  if (!state || state.status !== "active") return null
  var remaining = remainingMs(state, nowMs)
  if (remaining <= 0) return null
  var next = copyState(state)
  next.status = "paused"
  next.deadlineMs = 0
  next.pausedRemainingMs = remaining
  return next
}

function resume(state, nowMs) {
  if (!state || state.status !== "paused" || !(state.pausedRemainingMs > 0) || !isFinite(nowMs)) return null
  var next = copyState(state)
  next.status = "active"
  next.deadlineMs = nowMs + state.pausedRemainingMs
  next.pausedRemainingMs = 0
  return next
}

function addMinutes(state, minutes, nowMs) {
  if (!state || (state.status !== "active" && state.status !== "paused")) return null
  if (!isInteger(minutes) || minutes <= 0) return null
  var addedMs = minutes * 60 * 1000
  if (state.currentDurationMs + addedMs > MAX_DURATION_MS) return null

  var next = copyState(state)
  next.currentDurationMs += addedMs
  if (state.status === "active") {
    if (remainingMs(state, nowMs) <= 0) return null
    next.deadlineMs += addedMs
  } else {
    next.pausedRemainingMs += addedMs
  }
  return next
}

function restart(state, nowMs) {
  if (!state || (state.status !== "active" && state.status !== "paused")) return null
  if (!(state.originalDurationMs > 0) || !isFinite(nowMs)) return null
  if (state.status === "active" && remainingMs(state, nowMs) <= 0) return null
  var next = copyState(state)
  next.status = "active"
  next.currentDurationMs = state.originalDurationMs
  next.deadlineMs = nowMs + state.originalDurationMs
  next.pausedRemainingMs = 0
  next.notificationSent = false
  return next
}

function cancel() {
  return idleState()
}

function completeIfDue(state, nowMs) {
  if (!state || state.status !== "active" || remainingMs(state, nowMs) > 0) return state
  var next = copyState(state)
  next.status = "completed"
  next.deadlineMs = 0
  next.pausedRemainingMs = 0
  next.notificationSent = false
  return next
}

function validDuration(value) {
  return isInteger(value) && value >= 1000 && value <= MAX_DURATION_MS
}

function restore(raw, nowMs) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || parsed.version !== 1) return idleState()
    if (["active", "paused", "completed"].indexOf(parsed.status) === -1) return idleState()
    if (!validDuration(parsed.originalDurationMs) || !validDuration(parsed.currentDurationMs)) return idleState()
    if (parsed.currentDurationMs < parsed.originalDurationMs) return idleState()
    if (typeof parsed.notificationSent !== "boolean") return idleState()
    if (!isInteger(parsed.deadlineMs) || parsed.deadlineMs < 0) return idleState()
    if (!isInteger(parsed.pausedRemainingMs) || parsed.pausedRemainingMs < 0 || parsed.pausedRemainingMs > MAX_DURATION_MS)
      return idleState()

    if (parsed.status === "active") {
      if (!(parsed.deadlineMs > 0) || parsed.pausedRemainingMs !== 0 || parsed.notificationSent) return idleState()
      if (remainingMs(parsed, nowMs) > parsed.currentDurationMs) return idleState()
      return completeIfDue(parsed, nowMs)
    }
    if (parsed.status === "paused") {
      if (parsed.deadlineMs !== 0 || !(parsed.pausedRemainingMs > 0)
          || parsed.pausedRemainingMs > parsed.currentDurationMs || parsed.notificationSent) return idleState()
      return parsed
    }
    if (parsed.deadlineMs !== 0 || parsed.pausedRemainingMs !== 0) return idleState()
    return parsed
  } catch (error) {
    return idleState()
  }
}

function claimCompletion(state) {
  if (!state || state.status !== "completed" || state.notificationSent)
    return { state: state || idleState(), shouldNotify: false }
  var next = copyState(state)
  next.notificationSent = true
  return { state: next, shouldNotify: true }
}

function nextChimeAttempt(playCount, playerRunning, intervalElapsed) {
  if (!isInteger(playCount) || playCount < 0 || playCount >= CHIME_ATTEMPT_LIMIT)
    return { playCount: CHIME_ATTEMPT_LIMIT, shouldPlay: false, shouldContinue: false }
  if (playerRunning || !intervalElapsed)
    return { playCount: playCount, shouldPlay: false, shouldContinue: true }
  var nextCount = playCount + 1
  return {
    playCount: nextCount,
    shouldPlay: true,
    shouldContinue: nextCount < CHIME_ATTEMPT_LIMIT
  }
}
