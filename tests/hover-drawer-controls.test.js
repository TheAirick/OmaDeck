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

test("all four drawer actions exist in the hover-revealed control grid", () => {
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

test("drawer controls and hint are hidden until pointer hover or explicit edit mode", () => {
  assert.match(commandCenter, /readonly property bool pointerRevealed: drawerHover\.hovered/)
  assert.match(commandCenter, /readonly property bool controlsRevealed: pointerRevealed/)
  assert.match(commandCenter, /HoverHandler \{ id: drawerHover/)
  assert.match(commandCenter, /id: drawerControls[\s\S]*opacity: root\.controlsRevealed \? 1 : 0/)
  assert.match(commandCenter, /id: drawerControls[\s\S]*enabled: root\.controlsRevealed/)
  assert.match(commandCenter, /id: interactionHint[\s\S]*opacity: root\.controlsRevealed \? 1 : 0/)
  assert.match(commandCenter, /Behavior on opacity/)
  assert.match(moduleTile, /commandControlsRevealed/)
  assert.match(moduleTile, /moduleLoader\.item\.pointerRevealed/)
  assert.match(moduleTile, /!\(controller && controller\.editMode\)/)
  assert.match(moduleTile, /commandControlsRevealed \? "Swipe from any edge" : ""/)
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
