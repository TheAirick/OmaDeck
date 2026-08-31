.pragma library

function occupant(timerStatus, setupOpen) {
  return setupOpen || timerStatus !== "idle" ? "timer" : "weather"
}
