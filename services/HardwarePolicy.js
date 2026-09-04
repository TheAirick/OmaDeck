.pragma library

var VERSION = 1
var DEFAULT_TARGET_SCREEN = "DP-3"
var DEFAULT_PRIMARY_MONITOR = "DP-1"
var DEFAULT_TOUCH_DEVICE_NAMES = ["WCH.CN", "XENEON"]

function normalizeName(value, maximumLength) {
  if (typeof value !== "string") return null
  var normalized = value.trim()
  if (normalized.length < 1 || normalized.length > maximumLength) return null
  if (/[\u0000-\u001f\u007f]/.test(normalized)) return null
  return normalized
}

function isList(value) {
  return value !== null && value !== undefined
    && typeof value !== "string" && typeof value.length === "number"
}

function normalizeTouchNames(values) {
  if (!isList(values) || values.length < 1 || values.length > 8) return null
  var normalized = []
  var seen = ({})
  for (var index = 0; index < values.length; index++) {
    var name = normalizeName(values[index], 160)
    if (name === null) return null
    var key = name.toLowerCase()
    if (seen[key]) continue
    seen[key] = true
    normalized.push(name)
  }
  return normalized.length > 0 ? normalized : null
}

function snapshot(targetScreen, primaryMonitor, touchDeviceNames) {
  var target = normalizeName(targetScreen, 128)
  var primary = normalizeName(primaryMonitor, 128)
  var touch = normalizeTouchNames(touchDeviceNames)
  if (target === null || primary === null || touch === null) return null
  return {
    version: VERSION,
    targetScreen: target,
    primaryMonitor: primary,
    touchDeviceNames: touch
  }
}

function parseSettings(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || parsed.version !== VERSION) return null
    return snapshot(parsed.targetScreen, parsed.primaryMonitor, parsed.touchDeviceNames)
  } catch (error) {
    return null
  }
}

function includesExact(values, candidate) {
  if (!isList(values)) return false
  for (var index = 0; index < values.length; index++)
    if (String(values[index]) === String(candidate)) return true
  return false
}

function initialSnapshot(availableScreenNames) {
  if (!isList(availableScreenNames) || availableScreenNames.length < 1)
    return snapshot(DEFAULT_TARGET_SCREEN, DEFAULT_PRIMARY_MONITOR, DEFAULT_TOUCH_DEVICE_NAMES)

  var available = []
  for (var index = 0; index < availableScreenNames.length; index++) {
    var name = normalizeName(String(availableScreenNames[index]), 128)
    if (name !== null && !includesExact(available, name)) available.push(name)
  }
  if (available.length < 1)
    return snapshot(DEFAULT_TARGET_SCREEN, DEFAULT_PRIMARY_MONITOR, DEFAULT_TOUCH_DEVICE_NAMES)

  var primary = includesExact(available, DEFAULT_PRIMARY_MONITOR)
    ? DEFAULT_PRIMARY_MONITOR : available[0]
  var target = includesExact(available, DEFAULT_TARGET_SCREEN)
    ? DEFAULT_TARGET_SCREEN : ""
  if (target === "") {
    for (var screenIndex = 0; screenIndex < available.length; screenIndex++) {
      if (available[screenIndex] !== primary) {
        target = available[screenIndex]
        break
      }
    }
  }
  if (target === "") target = primary
  return snapshot(target, primary, DEFAULT_TOUCH_DEVICE_NAMES)
}

function touchSelection(configuredNames, availableNames) {
  if (!isList(configuredNames) || !isList(availableNames)) return ""
  for (var availableIndex = 0; availableIndex < availableNames.length; availableIndex++) {
    var available = String(availableNames[availableIndex])
    for (var configuredIndex = 0; configuredIndex < configuredNames.length; configuredIndex++) {
      var configured = String(configuredNames[configuredIndex])
      if (configured !== "" && available.toLowerCase().indexOf(configured.toLowerCase()) !== -1)
        return available
    }
  }
  return ""
}
