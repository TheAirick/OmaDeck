const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const repositoryRoot = path.join(__dirname, "..")
const commandCenter = fs.readFileSync(
  path.join(repositoryRoot, "modules/CommandCenterModule.qml"),
  "utf8",
)
const drawerButton = fs.readFileSync(
  path.join(repositoryRoot, "components/DrawerButton.qml"),
  "utf8",
)
const deckSurface = fs.readFileSync(
  path.join(repositoryRoot, "components/DeckSurface.qml"),
  "utf8",
)
const moduleTile = fs.readFileSync(
  path.join(repositoryRoot, "components/ModuleTile.qml"),
  "utf8",
)

test("Command Center keeps horizontal drawers and promotes vertical surfaces", () => {
  for (const [edge, label] of [
    ["left", "Volume"],
    ["right", "System"],
    ["top", "Notifications"],
    ["bottom", "Overview"],
    ["page", "Applications"],
    ["preferences", "Preferences"],
  ]) {
    assert.match(commandCenter, new RegExp(`DrawerButton \\{[^}]*edge: "${edge}"[^}]*label: "${label}"`))
  }
  assert.match(commandCenter, /columns: root\.columnCount/)
})

test("Command Center uses a bounded two-or-three-column control grid", () => {
  assert.match(commandCenter, /readonly property bool useThreeColumns:/)
  assert.match(commandCenter, /readonly property int columnCount: useThreeColumns \? 3 : 2/)
  assert.match(commandCenter, /readonly property real buttonWidth:/)
  assert.match(commandCenter, /readonly property real contentScale:\s*1/)
  assert.doesNotMatch(commandCenter, /scale:\s*root\.contentScale/)
  assert.match(commandCenter, /move: Transition/)
})

test("primary drawer navigation stays visible without pointer hover", () => {
  assert.doesNotMatch(commandCenter, /pointerRevealed|controlsRevealed|drawerHover/)
  assert.doesNotMatch(commandCenter, /id: drawerControls[\s\S]*opacity:/)
  assert.doesNotMatch(commandCenter, /id: drawerControls[\s\S]*enabled:/)
  assert.doesNotMatch(commandCenter, /id: interactionHint[\s\S]*opacity:/)
  assert.doesNotMatch(moduleTile, /commandControlsRevealed|pointerRevealed/)
  assert.match(moduleTile, /moduleId === "command-center" \? "Pages & edge controls"/)
})

test("drawer controls do not persist a highlight for the open edge", () => {
  assert.doesNotMatch(drawerButton, /property bool selected|root\.selected/)
  assert.doesNotMatch(commandCenter, /selected: root\.deck && root\.deck\.openDrawer === edge/)
})

test("touch edge gestures remain available for drawers and overlays", () => {
  for (const edge of ["left", "right", "top", "bottom"])
    assert.match(deckSurface, new RegExp(`EdgeSwipeArea \\{ enabled: root\\.openOverlayName === ""; edge: "${edge}"`))
  assert.match(deckSurface, /edge: "top"[^\n]*onTriggered: root\.toggleOverlay\("notifications"\)/)
  assert.match(deckSurface, /edge: "bottom"[^\n]*onTriggered: root\.toggleOverlay\("overview"\)/)
})
