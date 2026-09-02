const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const repositoryRoot = path.join(__dirname, "..")
const source = relative => fs.readFileSync(path.join(repositoryRoot, relative), "utf8")
const deck = source("components/DeckSurface.qml")
const overlay = source("components/DeckOverlay.qml")
const commandCenter = source("modules/CommandCenterModule.qml")
const launcher = source("modules/AppLauncherModule.qml")
const notifications = source("modules/NotificationCenterModule.qml")
const overview = source("modules/OverviewModule.qml")
const workspaces = source("modules/WorkspaceModule.qml")
const quickToggle = source("components/QuickToggle.qml")
const service = source("Service.qml")

const historySource = source("modules/NotificationHistory.js").replace(/^\.pragma library\s*/m, "")
const History = vm.runInNewContext(`${historySource}\n;({ parseHistory, merge })`)

test("vertical gestures own overlays and never reserve center height", () => {
  assert.match(deck, /readonly property real reservedTop:\s*0/)
  assert.match(deck, /readonly property real reservedBottom:\s*0/)
  assert.equal((deck.match(/EdgeDrawer\s*\{/g) || []).length, 2)
  assert.equal((deck.match(/DeckOverlay\s*\{/g) || []).length, 2)
  assert.match(deck, /openOverlayName === "notifications"/)
  assert.match(deck, /openOverlayName === "overview"/)
  assert.match(overlay, /y:\s*open \? 0 : closedOffset/)
  assert.match(overlay, /reverse:\s*true/)
})

test("vertical overlays preserve the horizontal drawer beneath them", () => {
  const setDrawer = deck.match(/function setOpenDrawer\(nextDrawer, reason\) \{([\s\S]*?)\n  \}/)[1]
  const setOverlay = deck.match(/function setOpenOverlay\(nextOverlay, reason\) \{([\s\S]*?)\n  \}/)[1]
  assert.doesNotMatch(setDrawer, /setOpenOverlay/)
  assert.doesNotMatch(setOverlay, /setOpenDrawer/)
  assert.match(deck, /property string openDrawer:\s*""/)
  assert.match(deck, /property string openOverlayName:\s*""/)
})

test("Command Center owns the editable Applications page", () => {
  assert.match(commandCenter, /readonly property string page:\s*deck \? deck\.commandCenterPage : "home"/)
  assert.match(commandCenter, /label: "Applications"[\s\S]*setCommandCenterPage\("applications"\)/)
  assert.match(commandCenter, /AppLauncherModule\s*\{/)
  assert.match(launcher, /controller\.availableEntries\(\)/)
  assert.match(launcher, /shell\.appLibrary/)
  assert.match(launcher, /library\.sortedEntries\(""\)/)
  assert.match(launcher, /controller\.add\(entry\.id\)/)
  assert.match(launcher, /controller\.remove\(selectedId\)/)
  assert.match(launcher, /controller\.move\(selectedId, delta\)/)
  assert.match(service, /LauncherController\s*\{\s*id:\s*launcherStore/)
})

test("notification overlay reuses Omarchy notification ownership", () => {
  assert.match(notifications, /firstPartyServiceFor\("omarchy\.notifications"\)/)
  assert.match(notifications, /notificationService\.clearPopups\(\)/)
  assert.match(notifications, /notificationService\.clearHistory\(\)/)
  assert.match(notifications, /notificationService\.invokePopupDefault/)
  assert.doesNotMatch(notifications, /NotificationServer\s*\{/)
})

test("notification center bounds its feed and exposes native quick controls", () => {
  assert.match(notifications, /width:\s*Math\.min\(notificationList\.width, Style\.space\(720\)\)/)
  assert.match(notifications, /firstPartyServiceFor\("omarchy\.nightlight"\)/)
  assert.match(notifications, /Networking\.wifiEnabled = !Networking\.wifiEnabled/)
  assert.match(notifications, /omarchy-bluetooth-power/)
  assert.match(notifications, /notificationDndControl/)
  assert.match(notifications, /notificationWifiControl/)
  assert.match(notifications, /notificationBluetoothControl/)
  assert.match(notifications, /notificationNightlightControl/)
  assert.doesNotMatch(notifications, /airplane/i)
  assert.match(quickToggle, /TapHandler\s*\{/)
  assert.match(quickToggle, /Border\.hyprlandActiveSpec/)
})

test("notification history parsing tolerates torn rows and deduplicates live entries", () => {
  const parsed = History.parseHistory([
    JSON.stringify({ app: "Chat", summary: "Older", timestamp: 10, originalId: 1 }),
    "not json",
    JSON.stringify({ app: "Chat", summary: "Newest", timestamp: 20, originalId: 2 }),
  ].join("\n"), 10)
  assert.deepEqual(Array.from(parsed, value => value.summary), ["Newest", "Older"])

  const merged = History.merge([
    { app: "Chat", summary: "Newest", timestamp: 20, originalId: 2, sourceIndex: 0 },
  ], parsed, 10)
  assert.deepEqual(Array.from(merged, value => value.summary), ["Newest", "Older"])
  assert.equal(merged[0].live, true)
})

test("overview delegates scratchpad actions to Hyprland's native special workspace", () => {
  assert.match(overview, /hl\.dsp\.workspace\.toggle_special\(\\"scratchpad\\"\)/)
  assert.match(overview, /workspace = \\"special:scratchpad\\"/)
  assert.match(overview, /WorkspaceModule\s*\{/)
  assert.match(overview, /expandToFit:\s*true/)
})

test("workspace tiles reserve persistent selection for the focused workspace", () => {
  assert.match(workspaces, /readonly property bool occupied:/)
  assert.match(workspaces, /readonly property bool focused:/)
  assert.match(workspaces, /borderSpec:\s*focused[\s\S]*Border\.hyprlandActiveSpec/)
  assert.match(workspaces, /workspaceTile\.occupied \? Color\.foreground : Color\.muted/)
  assert.match(workspaces, /HoverHandler\s*\{ id: workspaceHover \}/)
  assert.match(workspaces, /TapHandler\s*\{/)
  assert.doesNotMatch(workspaces, /selected:\s*focused/)
})
