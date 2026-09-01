import QtQuick
import QtTest
import "../../components" as Components

TestCase {
  id: testCase
  name: "DeckCenterClockIntegration"
  when: windowShown

  width: 1700
  height: 520
  visible: true

  function makeCenter(drawer, clockFirst, savedRatio) {
    layoutController.clockFirst = clockFirst
    layoutController.savedRatio = savedRatio
    layoutController.layoutBytes = "{\"root\":{\"type\":\"split\",\"ratio\":" + savedRatio + "}}"
    layoutController.revision++
    var reservations = {
      "": [0, 0, 0, 0],
      left: [682, 0, 0, 0],
      right: [0, 555, 0, 0],
      top: [0, 0, 92, 0],
      bottom: [0, 0, 0, 130]
    }[drawer]
    layoutController.drawerState = drawer
    var center = createTemporaryObject(deckCenterComponent, testCase, {
      surfaceWidth: 1600,
      surfaceHeight: 450,
      outerGap: 5,
      usableWidth: 1590,
      usableHeight: 440,
      reservedLeft: reservations[0],
      reservedRight: reservations[1],
      reservedTop: reservations[2],
      reservedBottom: reservations[3],
      layoutController: layoutController,
      appearanceController: appearanceController,
      weatherController: weatherController,
      timerController: timerController
    })
    verify(center !== null)
    wait(150)
    return center
  }

  function persistentSnapshot() {
    return {
      layoutBytes: layoutController.layoutBytes,
      topology: layoutController.topology,
      drawerState: layoutController.drawerState,
      selectedPath: layoutController.selectedPath,
      editMode: layoutController.editMode,
      mutationCalls: layoutController.mutationCalls
    }
  }

  function comparePersistent(actual, expected, label) {
    compare(actual.layoutBytes, expected.layoutBytes, label + " layout bytes")
    compare(actual.topology, expected.topology, label + " topology")
    compare(actual.drawerState, expected.drawerState, label + " drawer state")
    compare(actual.selectedPath, expected.selectedPath, label + " selection")
    compare(actual.editMode, expected.editMode, label + " edit mode")
    compare(actual.mutationCalls, expected.mutationCalls, label + " mutations")
  }

  function rectIn(item, ancestor) {
    var origin = item.mapToItem(ancestor, 0, 0)
    var farCorner = item.mapToItem(ancestor, item.width, item.height)
    return {
      x: Math.min(origin.x, farCorner.x),
      y: Math.min(origin.y, farCorner.y),
      width: Math.abs(farCorner.x - origin.x),
      height: Math.abs(farCorner.y - origin.y)
    }
  }

  function collectTargets(item, ancestor, result) {
    if (!item || !item.visible) return
    if (item.Accessible && item.Accessible.name)
      result.push({ name: item.Accessible.name, bounds: rectIn(item, ancestor) })
    for (var index = 0; index < item.children.length; index++)
      collectTargets(item.children[index], ancestor, result)
  }

  function test_reservationsUseRealSplitNode_data() {
    var rows = []
    for (var drawerIndex = 0; drawerIndex < 5; drawerIndex++) {
      var drawer = ["", "left", "right", "top", "bottom"][drawerIndex]
      rows.push({ tag: (drawer || "closed") + "-clock-first-guard", drawer: drawer,
        clockFirst: true, ratio: 0.30, effectiveRatio: 0.5, clockFraction: 0.5 })
      rows.push({ tag: (drawer || "closed") + "-clock-first-saved", drawer: drawer,
        clockFirst: true, ratio: 0.44, effectiveRatio: 0.5, clockFraction: 0.5 })
      rows.push({ tag: (drawer || "closed") + "-clock-second-guard", drawer: drawer,
        clockFirst: false, ratio: 0.70, effectiveRatio: 0.5, clockFraction: 0.5 })
    }
    return rows
  }

  function test_reservationsUseRealSplitNode(data) {
    var center = makeCenter(data.drawer, data.clockFirst, data.ratio)
    var stateBefore = persistentSnapshot()
    var split = findChild(center, "deckRootSplit")
    var clockCard = findChild(center, "clockPanelCard")
    var companionCard = findChild(center, "companionPanelCard")
    verify(split !== null)
    verify(clockCard !== null)
    verify(companionCard !== null)
    compare(split.effectiveRatio, data.effectiveRatio)
    compare(layoutController.savedRatio, data.ratio, "saved ratio must not mutate")
    compare(center.width, 1590 - center.reservedLeft - center.reservedRight)
    compare(center.height, 440 - center.reservedTop - center.reservedBottom)
    compare(center.x, 5 + center.reservedLeft)
    compare(center.y, 5 + center.reservedTop)
    var availableWidth = center.width - split.gap
    var expectedClockWidth = data.clockFirst
      ? Math.round(availableWidth * data.clockFraction)
      : availableWidth - Math.round(availableWidth * data.effectiveRatio)
    compare(clockCard.width, expectedClockWidth)
    verify(clockCard.y + clockCard.height < companionCard.y)
    compare(companionCard.y - clockCard.y - clockCard.height, split.gap)
    comparePersistent(persistentSnapshot(), stateBefore, data.tag)
  }

  function test_clockMayBeEitherDirectSplitChild_data() {
    return [
      { tag: "clock-first", clockFirst: true, savedRatio: 0.30, effectiveRatio: 0.5 },
      { tag: "clock-second", clockFirst: false, savedRatio: 0.70, effectiveRatio: 0.5 }
    ]
  }

  function test_clockMayBeEitherDirectSplitChild(data) {
    var center = makeCenter("", data.clockFirst, data.savedRatio)
    var split = findChild(center, "deckRootSplit")
    var clockCard = findChild(center, "clockPanelCard")
    verify(split !== null)
    verify(clockCard !== null)
    compare(split.effectiveRatio, data.effectiveRatio)
    var expectedWidth = Math.round((center.width - split.gap) * 0.5)
    compare(clockCard.width, expectedWidth)
    compare(layoutController.savedRatio, data.savedRatio)
  }

  function test_bottomReservationKeepsTransformedTargetsAtLeast48() {
    var center = makeCenter("bottom", true, 0.30)
    var stateBefore = persistentSnapshot()
    var clock = findChild(center, "compactClock")
    var timer = findChild(center, "timerPresenter")
    var companionContent = findChild(findChild(center, "companionPanelCard"), "deckCardContent")
    verify(clock !== null)
    verify(timer !== null)
    mouseClick(clock, clock.width / 2, clock.height / 2)
    wait(250)
    var targets = []
    collectTargets(timer, companionContent, targets)
    verify(targets.length >= 10)
    for (var index = 0; index < targets.length; index++) {
      verify(targets[index].bounds.width >= 48, targets[index].name + " transformed width")
      verify(targets[index].bounds.height >= 48, targets[index].name + " transformed height")
    }
    comparePersistent(persistentSnapshot(), stateBefore, "pointer and transformed geometry")
  }

  Component {
    id: deckCenterComponent
    Components.DeckCenter {}
  }

  QtObject {
    id: layoutController
    property int revision: 0
    property bool clockFirst: true
    property real savedRatio: 0.30
    property bool editMode: false
    property string selectedPath: ""
    property string layoutBytes: ""
    property string topology: "split(module:clock,module:command-center)"
    property string drawerState: ""
    property int mutationCalls: 0
    function nodeAt(path) {
      var clock = { type: "module", moduleId: "clock" }
      var command = { type: "module", moduleId: "command-center" }
      if (path === "") return {
        type: "split", orientation: "horizontal", ratio: savedRatio,
        first: clockFirst ? clock : command,
        second: clockFirst ? command : clock
      }
      if (path === "first") return clockFirst ? clock : command
      if (path === "second") return clockFirst ? command : clock
      return null
    }
    function beginEdit(path) { selectedPath = path; editMode = true }
    function selectOrSwap(path) { selectedPath = path; mutationCalls++ }
    function swap(first, second) { mutationCalls++ }
    function setRatio(path, ratio) { mutationCalls++ }
  }

  QtObject {
    id: appearanceController
    property bool use24Hour: false
    property bool showSeconds: false
    property bool showWeather: true
    property string weatherStyle: "scene"
    property string weatherDetail: "standard"
    property string temperatureUnit: "fahrenheit"
  }

  QtObject {
    id: weatherController
    property bool loading: false
    property string error: ""
    property var current: ({ ok: true, condition: "clear", conditionLabel: "Clear", isDay: true,
      temperatureC: 18, feelsLikeC: 18, windKph: 5, humidity: 40, highC: 20, lowC: 12,
      location: "Portland", forecast: [] })
  }

  QtObject {
    id: timerController
    property bool loaded: true
    property string status: "idle"
    property string remainingText: "5:00"
    property real progress: 0
    property string selectedSoundName: "Complete"
    property bool soundSettingsLoaded: true
    property string selectedSoundId: "complete"
    function start(hours, minutes) { status = "active"; return { ok: true } }
    function stopPreview() {}
    function selectPreviousSound() {}
    function selectNextSound() {}
    function previewSelectedSound() {}
    function pause() { status = "paused" }
    function resume() { status = "active" }
    function add(minutes) {}
    function restart() { status = "active" }
    function cancel() { status = "idle" }
    function dismiss() { status = "idle" }
  }
}
