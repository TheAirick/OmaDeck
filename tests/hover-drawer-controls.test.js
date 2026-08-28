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

test("all four drawer actions exist in the permanent control grid", () => {
  for (const [edge, label] of [
    ["left", "Media"],
    ["right", "System"],
    ["top", "Workspaces"],
    ["bottom", "Applications"],
  ]) {
    assert.match(commandCenter, new RegExp(`DrawerButton \\{[^}]*edge: "${edge}"[^}]*label: "${label}"`))
  }
  assert.match(commandCenter, /columns: 2/)
})

test("primary drawer navigation stays visible without pointer hover", () => {
  assert.doesNotMatch(commandCenter, /pointerRevealed|controlsRevealed|drawerHover/)
  assert.doesNotMatch(commandCenter, /id: drawerControls[\s\S]*opacity:/)
  assert.doesNotMatch(commandCenter, /id: drawerControls[\s\S]*enabled:/)
  assert.doesNotMatch(commandCenter, /id: interactionHint[\s\S]*opacity:/)
  assert.doesNotMatch(moduleTile, /commandControlsRevealed|pointerRevealed/)
  assert.match(moduleTile, /moduleId === "command-center" \? "Swipe from any edge"/)
})

test("drawer controls expose selected feedback for the open edge", () => {
  assert.match(drawerButton, /property bool selected: false/)
  assert.match(drawerButton, /root\.selected/)
  assert.match(commandCenter, /selected: root\.deck && root\.deck\.openDrawer === edge/)
})

test("touch edge gestures remain available for every drawer", () => {
  for (const edge of ["left", "right", "top", "bottom"])
    assert.match(deckSurface, new RegExp(`EdgeSwipeArea \\{ edge: "${edge}"`))
})
