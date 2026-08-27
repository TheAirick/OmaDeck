const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const gestureSource = fs.readFileSync(path.join(__dirname, "../components/DrawerGesture.js"), "utf8")
const DrawerGesture = vm.runInNewContext(`${gestureSource}\n;({ toggleDrawer, dismissDrawer, shouldTrigger })`)
const deckSource = fs.readFileSync(path.join(__dirname, "../components/DeckSurface.qml"), "utf8")
const drawerSource = fs.readFileSync(path.join(__dirname, "../components/EdgeDrawer.qml"), "utf8")

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

test("drawer integration keeps center taps and drawer content outside dismissal handling", () => {
  assert.doesNotMatch(deckSource, /onTapped:\s*if \(root\.openDrawer !== ""\) root\.closeDrawer\(\)/)
  assert.equal((deckSource.match(/onDismissRequested:\s*root\.dismissDrawer\(edge\)/g) || []).length, 4)
  assert.match(drawerSource, /reverse:\s*true/)
  assert.match(drawerSource, /gestureThickness:\s*root\.dismissInset/)
})
