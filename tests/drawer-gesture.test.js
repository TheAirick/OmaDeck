const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const gestureSource = fs.readFileSync(path.join(__dirname, "../components/DrawerGesture.js"), "utf8")
const DrawerGesture = vm.runInNewContext(`${gestureSource}\n;({
  toggleDrawer,
  dismissDrawer,
  shouldTrigger,
  dismissButtonPosition,
})`)
const deckSource = fs.readFileSync(path.join(__dirname, "../components/DeckSurface.qml"), "utf8")
const centerSource = fs.readFileSync(path.join(__dirname, "../components/DeckCenter.qml"), "utf8")
const drawerSource = fs.readFileSync(path.join(__dirname, "../components/EdgeDrawer.qml"), "utf8")
const overlaySource = fs.readFileSync(path.join(__dirname, "../components/DeckOverlay.qml"), "utf8")

test("opening another drawer replaces the current drawer", () => {
  assert.equal(DrawerGesture.toggleDrawer("left", "right"), "right")
})

test("opening the current drawer again toggles it closed", () => {
  assert.equal(DrawerGesture.toggleDrawer("left", "left"), "")
})

test("dismissal closes only the drawer that owns the gesture", () => {
  assert.equal(DrawerGesture.dismissDrawer("left", "left"), "")
  assert.equal(DrawerGesture.dismissDrawer("right", "left"), "right")
})

test("inward gestures open from every edge", () => {
  assert.equal(DrawerGesture.shouldTrigger("left", false, 43, 0, 42), true)
  assert.equal(DrawerGesture.shouldTrigger("right", false, -43, 0, 42), true)
  assert.equal(DrawerGesture.shouldTrigger("top", false, 0, 43, 42), true)
  assert.equal(DrawerGesture.shouldTrigger("bottom", false, 0, -43, 42), true)
})

test("reverse gestures dismiss toward every originating edge", () => {
  assert.equal(DrawerGesture.shouldTrigger("left", true, -43, 0, 42), true)
  assert.equal(DrawerGesture.shouldTrigger("right", true, 43, 0, 42), true)
  assert.equal(DrawerGesture.shouldTrigger("top", true, 0, -43, 42), true)
  assert.equal(DrawerGesture.shouldTrigger("bottom", true, 0, 43, 42), true)
})

test("short and wrong-direction gestures do not trigger", () => {
  assert.equal(DrawerGesture.shouldTrigger("left", true, -42, 0, 42), false)
  assert.equal(DrawerGesture.shouldTrigger("left", true, 43, 0, 42), false)
  assert.equal(DrawerGesture.shouldTrigger("bottom", true, 0, -43, 42), false)
  assert.equal(DrawerGesture.shouldTrigger("unknown", false, 100, 100, 42), false)
})

test("drawers and overlays keep content outside dismissal handling", () => {
  assert.doesNotMatch(deckSource, /onTapped:\s*if \(root\.openDrawer !== ""\) root\.closeDrawer\(\)/)
  assert.equal((deckSource.match(/onDismissRequested:\s*root\.dismissDrawer\(edge\)/g) || []).length, 2)
  assert.equal((deckSource.match(/onDismissRequested:\s*root\.closeOverlay\(\)/g) || []).length, 2)
  assert.match(drawerSource, /reverse:\s*true/)
  assert.match(drawerSource, /gestureThickness:\s*root\.dismissInset/)
  assert.match(overlaySource, /reverse:\s*true/)
  assert.match(overlaySource, /gestureThickness:\s*Style\.space\(30\)/)
})

test("only the left Volume drawer opts into a frameless carrier", () => {
  assert.match(drawerSource, /property bool framed:\s*true/)
  assert.match(drawerSource, /color:\s*root\.framed \? Color\.popups\.background : "transparent"/)
  assert.match(drawerSource, /borderSpec:\s*root\.framed[\s\S]*Border\.none\(\)/)
  assert.match(drawerSource, /property real framelessDismissInset:\s*Style\.spacing\.panelPadding/)
  assert.match(drawerSource, /rightPadding:\s*root\.framed \? root\.padding : root\.framelessDismissInset/)

  const drawers = [...deckSource.matchAll(/EdgeDrawer\s*\{([\s\S]*?)\n  \}/g)].map(match => match[1])
  assert.equal(drawers.length, 2)
  assert.match(drawers[0], /id:\s*leftDrawer/)
  assert.match(drawers[0], /objectName:\s*"leftVolumeDrawer"/)
  assert.match(drawers[0], /framed:\s*false/)
  assert.match(drawers[0], /framelessDismissInset:\s*root\.innerGap/)
  assert.match(drawers[0], /width:\s*root\.leftDrawerWidth \+ root\.innerGap/)
  for (const framedDrawer of drawers.slice(1)) assert.doesNotMatch(framedDrawer, /framed:\s*false/)
})

test("every open drawer exposes a mouse-only button back to the center", () => {
  assert.match(drawerSource, /Button \{\s*id: dismissButton/)
  assert.match(drawerSource, /property bool pointerRevealed:\s*false/)
  assert.match(drawerSource, /readonly property bool dismissButtonInInset:\s*!framed && edge === "left"/)
  assert.match(drawerSource, /opacity:\s*root\.pointerRevealed \? 1 : 0/)
  assert.match(drawerSource, /enabled:\s*root\.pointerRevealed/)
  assert.match(drawerSource, /navigationSize:\s*Style\.space\(32\)/)
  assert.match(drawerSource, /width:\s*root\.dismissButtonInInset \? root\.dismissInset : root\.navigationSize/)
  assert.match(drawerSource, /height:\s*root\.navigationSize/)
  assert.match(drawerSource, /x:\s*root\.dismissButtonInInset \? root\.width - width : root\.dismissButtonPosition\.x/)
  assert.match(drawerSource, /iconText:\s*root\.edge === "left"/)
  assert.doesNotMatch(drawerSource, /selected:\s*true/)
  assert.match(drawerSource, /onClicked:\s*root\.dismissRequested\(\)/)
})

test("drawer close buttons align compactly with their dismissal edge", () => {
  const width = 1000
  const height = 300
  const size = 32
  const inset = 8

  assert.deepEqual(
    JSON.parse(JSON.stringify(DrawerGesture.dismissButtonPosition("left", width, height, size, inset, inset, inset, inset))),
    { x: inset, y: inset },
  )
  assert.deepEqual(
    JSON.parse(JSON.stringify(DrawerGesture.dismissButtonPosition("right", width, height, size, inset, inset, inset, inset))),
    { x: width - size - inset, y: inset },
  )
  assert.deepEqual(
    JSON.parse(JSON.stringify(DrawerGesture.dismissButtonPosition("top", width, height, size, inset, inset, inset, inset))),
    { x: (width - size) / 2, y: inset },
  )
  assert.deepEqual(
    JSON.parse(JSON.stringify(DrawerGesture.dismissButtonPosition("bottom", width, height, size, inset, inset, inset, inset))),
    { x: (width - size) / 2, y: height - size - inset },
  )
})

test("drawer close buttons float without reserving content geometry", () => {
  assert.doesNotMatch(gestureSource, /function navigationMargins/)
  assert.doesNotMatch(drawerSource, /navigationMargins/)
  assert.match(drawerSource, /anchors\.topMargin:\s*root\.contentTopInset\s*$/m)
  assert.match(drawerSource, /anchors\.rightMargin:\s*root\.contentRightInset\s*$/m)
})

test("mouse presence anywhere on OmaDeck reveals horizontal drawer controls without touch", () => {
  assert.match(deckSource, /readonly property bool deckHovered:\s*backgroundHover\.hovered\s*\|\| centerCanvas\.pointerHovered/)
  for (const id of ["leftDrawer", "rightDrawer", "notificationOverlay", "overviewOverlay"])
    assert.match(deckSource, new RegExp(`${id}\\.pointerHovered`))
  assert.match(deckSource, /readonly property bool pointerRevealed:\s*deckHovered\s*&& !directTouch\.touchInProgress/)
  assert.match(deckSource, /id:\s*deckBackground[\s\S]*HoverHandler \{\s*id: backgroundHover\s*\}/)
  assert.match(deckSource, /DeckCenter \{\s*id:\s*centerCanvas/)
  assert.match(centerSource, /readonly property bool pointerHovered:\s*centerHover\.hovered/)
  assert.match(centerSource, /HoverHandler \{\s*id: centerHover\s*\}/)
  assert.match(drawerSource, /readonly property bool pointerHovered:\s*drawerHover\.hovered/)
  assert.match(drawerSource, /HoverHandler \{\s*id: drawerHover\s*\}/)
  assert.doesNotMatch(deckSource, /acceptedDevices:\s*PointerDevice\.Mouse/)
  assert.doesNotMatch(drawerSource, /acceptedDevices:\s*PointerDevice\.Mouse/)
  assert.equal((deckSource.match(/pointerRevealed:\s*root\.pointerRevealed/g) || []).length, 2)
})

test("drawer diagnostics expose each mouse reveal gate", () => {
  assert.match(deckSource, /deckHovered:\s*deckHovered/)
  assert.match(deckSource, /backgroundHovered:\s*backgroundHover\.hovered/)
  assert.match(deckSource, /centerHovered:\s*centerCanvas\.pointerHovered/)
  assert.match(deckSource, /touchInProgress:\s*directTouch\.touchInProgress/)
  assert.match(deckSource, /pointerRevealed:\s*pointerRevealed/)
})

test("every drawer state transition is routed through an observable boundary", () => {
  const assignments = deckSource.match(/(?:root\.)?openDrawer\s*=(?!=)/g) || []
  const overlayAssignments = deckSource.match(/(?:root\.)?openOverlayName\s*=(?!=)/g) || []
  const diagnosticLogs = deckSource.match(/console\.(?:info|warn)\("\[OmaDeckDrawer\]/g) || []

  assert.equal(assignments.length, 1)
  assert.equal(overlayAssignments.length, 1)
  assert.equal(diagnosticLogs.length, 1)
  assert.match(deckSource, /function setOpenDrawer\(nextDrawer, reason\)/)
  assert.match(deckSource, /function setOpenOverlay\(nextOverlay, reason\)/)
  assert.match(deckSource, /function drawerState\(\): string/)
  assert.match(deckSource, /\[OmaDeckDrawer\] loaded/)
  assert.match(deckSource, /componentUrl/)
  assert.match(deckSource, /sourceDir/)
})
