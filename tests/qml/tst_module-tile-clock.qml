import QtQuick
import QtTest
import qs.Commons
import "../../components" as Components

TestCase {
  id: testCase
  name: "ModuleTileClockPanels"
  when: windowShown

  width: 900
  height: 520
  visible: true

  property int editCalls: 0

  function makeTile(width, height) {
    editCalls = 0
    layoutController.moduleId = "clock"
    layoutController.revision++
    layoutController.editMode = false
    layoutController.selectedPath = ""
    layoutController.layoutMutationCalls = 0
    timerController.status = "idle"
    timerController.stopPreviewCalls = 0
    timerController.startCalls = 0
    var tile = createTemporaryObject(moduleTileComponent, testCase, {
      width: width,
      height: height,
      controller: layoutController,
      path: "first",
      appearanceController: appearanceController,
      weatherController: weatherController,
      timerController: timerController
    })
    verify(tile !== null)
    wait(100)
    return tile
  }

  function panelFixture(tile) {
    var clockCard = findChild(tile, "clockPanelCard")
    var companionCard = findChild(tile, "companionPanelCard")
    verify(clockCard !== null, "Clock needs its own DeckCard boundary")
    verify(companionCard !== null, "Weather/Timer needs its own DeckCard boundary")
    compare(findChild(tile, "moduleCard"), null, "Clock must bypass the generic composite DeckCard")
    verify(clockCard !== companionCard)
    compare(clockCard.parent, companionCard.parent, "the two cards must be siblings")
    var clockContent = findChild(clockCard, "deckCardContent")
    var companionContent = findChild(companionCard, "deckCardContent")
    var clockHeader = findChild(clockCard, "deckCardHeader")
    var companionHeader = findChild(companionCard, "deckCardHeader")
    verify(clockContent !== null)
    verify(companionContent !== null)
    verify(clockHeader !== null)
    verify(companionHeader !== null)
    return {
      clockCard: clockCard,
      companionCard: companionCard,
      clockContent: clockContent,
      companionContent: companionContent,
      clock: findChild(clockCard, "compactClock"),
      weather: findChild(companionCard, "weatherPresenter"),
      timer: findChild(companionCard, "timerPresenter")
    }
  }

  function rectIn(item, ancestor) {
    var origin = item.mapToItem(ancestor, 0, 0)
    return { x: origin.x, y: origin.y, width: item.width, height: item.height }
  }

  function compareRect(actual, expected, label) {
    compare(actual.x, expected.x, label + " x")
    compare(actual.y, expected.y, label + " y")
    compare(actual.width, expected.width, label + " width")
    compare(actual.height, expected.height, label + " height")
  }

  function persistentSnapshot() {
    return {
      layoutBytes: layoutController.layoutBytes,
      topology: layoutController.topology,
      drawerState: layoutController.drawerState,
      selectedPath: layoutController.selectedPath,
      editMode: layoutController.editMode,
      layoutMutationCalls: layoutController.layoutMutationCalls
    }
  }

  function comparePersistent(actual, expected, label, includeEditState) {
    compare(actual.layoutBytes, expected.layoutBytes, label + " layout bytes")
    compare(actual.topology, expected.topology, label + " topology")
    compare(actual.drawerState, expected.drawerState, label + " drawer state")
    compare(actual.layoutMutationCalls, expected.layoutMutationCalls, label + " mutations")
    if (includeEditState) {
      compare(actual.selectedPath, expected.selectedPath, label + " selected path")
      compare(actual.editMode, expected.editMode, label + " edit mode")
    }
  }

  function collectTargets(item, ancestor, result) {
    if (!item || !item.visible) return
    if (item.Accessible && item.Accessible.name) {
      var bounds = rectIn(item, ancestor)
      result.push({ name: item.Accessible.name, bounds: bounds })
    }
    for (var index = 0; index < item.children.length; index++)
      collectTargets(item.children[index], ancestor, result)
  }

  function collectNamed(item, objectName, result) {
    if (!item) return
    if (item.objectName === objectName) result.push(item)
    for (var index = 0; index < item.children.length; index++)
      collectNamed(item.children[index], objectName, result)
  }

  function countCardBoundaries(item) {
    if (!item) return 0
    var result = item.cardBoundary === true ? 1 : 0
    for (var index = 0; index < item.children.length; index++)
      result += countCardBoundaries(item.children[index])
    return result
  }

  function test_twoSiblingCardsAndRealClockTap() {
    var tile = makeTile(530, 380)
    var fixture = panelFixture(tile)
    compare(countCardBoundaries(tile), 2)
    verify(fixture.clockCard.border.width > 0)
    verify(fixture.companionCard.border.width > 0)
    verify(fixture.clockCard.borderSpec !== fixture.companionCard.borderSpec)
    compare(fixture.clockCard.title, "Clock")
    compare(fixture.companionCard.title, "Weather")
    verify(fixture.clock !== null)
    verify(fixture.weather !== null)
    verify(fixture.timer !== null)
    compare(fixture.weather.visible, true)
    compare(fixture.timer.visible, false)

    var clockCardBefore = rectIn(fixture.clockCard, tile)
    var clockBefore = rectIn(fixture.clock, tile)
    var lowerBefore = rectIn(fixture.companionCard, tile)
    var stateBefore = persistentSnapshot()
    verify(clockCardBefore.y + clockCardBefore.height < lowerBefore.y)
    compare(lowerBefore.y - clockCardBefore.y - clockCardBefore.height, Style.spacing.panelGap)

    mouseClick(fixture.clock, fixture.clock.width / 2, fixture.clock.height / 2)
    wait(100)

    compareRect(rectIn(fixture.clockCard, tile), clockCardBefore, "Clock card after setup")
    compareRect(rectIn(fixture.clock, tile), clockBefore, "Clock content after setup")
    compare(fixture.clock.visible, true)
    compare(fixture.weather.visible, false)
    compare(fixture.timer.visible, true)
    compare(fixture.companionCard.title, "Timer")
    compareRect(rectIn(fixture.companionCard, tile), lowerBefore, "Timer card")
    var overlay = findChild(fixture.timer, "timerOverlay")
    verify(overlay !== null)
    compareRect(rectIn(overlay, tile), rectIn(fixture.companionContent, tile), "Timer overlay")

    mouseClick(fixture.timer, 4, 4)
    wait(50)
    compare(fixture.timer.setupOpen, true, "lower-panel input must not retrigger Clock")
    fixture.timer.cancelSetup()
    compare(fixture.weather.visible, true)
    compare(fixture.timer.visible, false)
    compare(fixture.companionCard.title, "Weather")
    comparePersistent(persistentSnapshot(), stateBefore, "companion switch", true)
    grabImage(tile).save("/tmp/omadeck-module-tile-clock.png")
  }

  function test_timerTransitionsStayInsideLowerCard() {
    var tile = makeTile(530, 380)
    var fixture = panelFixture(tile)
    var clockBounds = rectIn(fixture.clockCard, tile)
    var lowerBounds = rectIn(fixture.companionCard, tile)
    var stateBefore = persistentSnapshot()

    mouseClick(fixture.clock, fixture.clock.width / 2, fixture.clock.height / 2)
    fixture.timer.startSelectedTimer()
    compare(timerController.startCalls, 1)
    compare(timerController.status, "active")
    compare(fixture.timer.visible, true)
    timerController.pause()
    compare(timerController.status, "paused")
    timerController.resume()
    compare(timerController.status, "active")
    timerController.cancel()
    compare(fixture.weather.visible, true)
    timerController.status = "completed"
    compare(fixture.timer.visible, true)
    timerController.dismiss()
    compare(fixture.weather.visible, true)
    compareRect(rectIn(fixture.clockCard, tile), clockBounds, "Clock throughout timer lifecycle")
    compareRect(rectIn(fixture.companionCard, tile), lowerBounds, "lower card throughout timer lifecycle")
    comparePersistent(persistentSnapshot(), stateBefore, "timer lifecycle", true)
  }

  function test_ordinaryModuleRetainsOneGenericCard() {
    var tile = makeTile(530, 380)
    layoutController.moduleId = "workspaces"
    layoutController.revision++
    wait(100)
    verify(findChild(tile, "moduleCard") !== null)
    compare(findChild(tile, "clockPanelCard"), null)
    compare(findChild(tile, "companionPanelCard"), null)
    compare(countCardBoundaries(tile), 1)
  }

  function test_longPressEditsLogicalLeafWithoutOpeningTimer() {
    var tile = makeTile(530, 380)
    var fixture = panelFixture(tile)
    var stateBefore = persistentSnapshot()
    mousePress(fixture.clock, fixture.clock.width / 2, fixture.clock.height / 2)
    wait(650)
    mouseRelease(fixture.clock, fixture.clock.width / 2, fixture.clock.height / 2)
    wait(50)
    compare(editCalls, 1)
    compare(layoutController.selectedPath, "first")
    compare(fixture.timer.setupOpen, false)
    compare(fixture.weather.visible, true)
    comparePersistent(persistentSnapshot(), stateBefore, "long press", false)
  }

  function test_drawerReservationsAndTouchTargets_data() {
    return [
      { tag: "closed-036", width: 530, height: 380 },
      { tag: "left-036", width: 329, height: 380 },
      { tag: "right-036", width: 329, height: 380 },
      { tag: "top-036", width: 530, height: 288 },
      { tag: "bottom-036", width: 530, height: 250 },
      { tag: "closed-044", width: 660, height: 380 }
    ]
  }

  function test_drawerReservationsAndTouchTargets(data) {
    var tile = makeTile(data.width, data.height)
    var fixture = panelFixture(tile)
    var upper = rectIn(fixture.clockCard, tile)
    var lower = rectIn(fixture.companionCard, tile)
    verify(upper.height > 0, data.tag + " Clock height")
    verify(lower.height > 0, data.tag + " companion height")
    compare(lower.y - upper.y - upper.height, Style.spacing.panelGap, data.tag + " gap")
    mouseClick(fixture.clock, fixture.clock.width / 2, fixture.clock.height / 2)
    wait(200)
    var targets = []
    collectTargets(fixture.timer, fixture.companionContent, targets)
    verify(targets.length >= 10, data.tag + " target count " + targets.length)
    for (var index = 0; index < targets.length; index++) {
      var target = targets[index]
      verify(target.bounds.width >= 48, data.tag + " " + target.name + " width")
      verify(target.bounds.height >= 48, data.tag + " " + target.name + " height")
      verify(target.bounds.x >= -0.5, data.tag + " " + target.name + " left")
      verify(target.bounds.y >= -0.5, data.tag + " " + target.name + " top")
      verify(target.bounds.x + target.bounds.width <= fixture.companionContent.width + 0.5,
        data.tag + " " + target.name + " right")
      verify(target.bounds.y + target.bounds.height <= fixture.companionContent.height + 0.5,
        data.tag + " " + target.name + " bottom "
          + (target.bounds.y + target.bounds.height) + "/" + fixture.companionContent.height)
    }
  }

  function test_twentyLifecycleCyclesKeepExactlyTwoBoundaries() {
    for (var cycle = 0; cycle < 20; cycle++) {
      var tile = makeTile(530, 380)
      var fixture = panelFixture(tile)
      var stateBefore = persistentSnapshot()
      compare(countCardBoundaries(tile), 2)
      var weatherPresenters = []
      var timerPresenters = []
      collectNamed(tile, "weatherPresenter", weatherPresenters)
      collectNamed(tile, "timerPresenter", timerPresenters)
      compare(weatherPresenters.length, 1)
      compare(timerPresenters.length, 1)
      compare(Number(fixture.weather.visible) + Number(fixture.timer.visible), 1)
      mouseClick(fixture.clock, fixture.clock.width / 2, fixture.clock.height / 2)
      compare(Number(fixture.weather.visible) + Number(fixture.timer.visible), 1)
      timerController.previewSelectedSound()
      fixture.timer.cancelSetup()
      compare(timerController.previewRunning, false)
      compare(timerController.stopPreviewCalls, 1)
      comparePersistent(persistentSnapshot(), stateBefore, "lifecycle cycle " + cycle, true)
      tile.destroy()
      wait(0)
      compare(timerController.previewRunning, false)
    }
  }

  Component {
    id: moduleTileComponent
    Components.ModuleTile {}
  }

  QtObject {
    id: layoutController
    property int revision: 0
    property string moduleId: "clock"
    property bool editMode: false
    property string selectedPath: ""
    property string layoutBytes: "{\"root\":{\"type\":\"split\",\"ratio\":0.36}}"
    property string topology: "split(module:clock,module:command-center)"
    property string drawerState: "bottom"
    property int layoutMutationCalls: 0
    function nodeAt(path) { return { type: "module", moduleId: moduleId } }
    function beginEdit(path) { testCase.editCalls++; selectedPath = path; editMode = true }
    function selectOrSwap(path) { selectedPath = path; layoutMutationCalls++ }
    function swap(first, second) { layoutMutationCalls++ }
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
    property var current: ({
      ok: true,
      condition: "partly-cloudy",
      conditionLabel: "Partly cloudy",
      isDay: true,
      temperatureC: 18,
      feelsLikeC: 17,
      windKph: 13,
      humidity: 61,
      highC: 20,
      lowC: 12,
      location: "Portland",
      forecast: []
    })
  }

  QtObject {
    id: timerController
    property bool loaded: true
    property string status: "idle"
    property string remainingText: status === "completed" ? "0:00" : "12:34"
    property real progress: 0.5
    property string selectedSoundName: "Complete"
    property bool soundSettingsLoaded: true
    property string selectedSoundId: "complete"
    property int startCalls: 0
    property int stopPreviewCalls: 0
    property bool previewRunning: false
    function start(hours, minutes) { startCalls++; status = "active"; return { ok: true } }
    function stopPreview() { stopPreviewCalls++; previewRunning = false }
    function selectPreviousSound() {}
    function selectNextSound() {}
    function previewSelectedSound() { previewRunning = true }
    function pause() { status = "paused" }
    function resume() { status = "active" }
    function add(minutes) {}
    function restart() { status = "active" }
    function cancel() { status = "idle" }
    function dismiss() { status = "idle" }
  }
}
