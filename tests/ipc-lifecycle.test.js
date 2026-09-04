const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const repositoryRoot = path.join(__dirname, "..")
const service = fs.readFileSync(path.join(repositoryRoot, "Service.qml"), "utf8")
const deckSurface = fs.readFileSync(
  path.join(repositoryRoot, "components/DeckSurface.qml"),
  "utf8",
)

test("persistent Service owns the only OmaDeck IPC handler", () => {
  assert.match(service, /IpcHandler\s*{/)
  assert.match(service, /target:\s*"pretty\.omadeck"/)
  assert.doesNotMatch(deckSurface, /IpcHandler\s*{/)
})

test("DeckSurface registers and unregisters as the available IPC surface", () => {
  assert.match(service, /property var activeSurface:\s*null/)
  assert.match(service, /function registerSurface\(surface\)/)
  assert.match(service, /function unregisterSurface\(surface\)/)
  assert.match(deckSurface, /property var serviceHost:\s*null/)
  assert.match(deckSurface, /serviceHost\.registerSurface\(root\)/)
  assert.match(deckSurface, /serviceHost\.unregisterSurface\(root\)/)
  assert.match(service, /if \(!layoutStore\.loaded \|\| !hardwareStore\.loaded\) return \[\]/)
})

test("touch IPC reports honest state without a target monitor and forwards after hotplug", () => {
  assert.match(service, /function touchState\(\): string/)
  assert.match(service, /active:\s*false/)
  assert.match(service, /exclusiveGrab:\s*false/)
  assert.match(service, /devicePath:\s*""/)
  assert.match(service, /configuredDeviceNames:\s*root\.touchDeviceNames/)
  assert.match(service, /status:\s*"Target monitor unavailable"/)
  assert.match(service, /root\.activeSurface\.touchState\(\)/)

  assert.match(service, /function reconnectTouch\(\): string/)
  assert.match(service, /root\.activeSurface\.reconnectTouch\(\)/)
  assert.match(service, /Target monitor unavailable/)
})

test("hardware IPC reports persisted and currently detected choices", () => {
  assert.match(service, /function hardwareState\(\): string/)
  assert.match(service, /hardwareStore\.snapshot\(\)/)
  assert.match(service, /state\.availableScreenNames = hardwareStore\.availableScreenNames/)
  assert.match(service, /state\.availableTouchDeviceNames = hardwareStore\.availableTouchDeviceNames/)
  assert.match(service, /state\.selectedTouchDeviceName = hardwareStore\.selectedTouchDeviceName/)
})

test("drawer state identifies when no target surface exists", () => {
  assert.match(service, /function drawerState\(\): string/)
  assert.match(service, /available:\s*false/)
  assert.match(service, /root\.activeSurface\.drawerState\(\)/)
})

test("overlay IPC can dismiss the vertical layer without closing a horizontal drawer", () => {
  assert.match(service, /function closeOverlay\(\): void/)
  assert.match(service, /root\.activeSurface\.closeOverlay\(\)/)
  assert.match(deckSurface, /function closeOverlay\(\)/)
})
