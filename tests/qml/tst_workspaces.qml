import QtQuick
import QtTest
import Quickshell
import Quickshell.Hyprland
import "../../modules" as Modules

TestCase {
  id: testCase
  name: "Workspaces"
  when: windowShown
  width: 1600; height: 720
  visible: true
  property var one
  property var two
  property var parked
  property var browser
  property var editor
  property var monitor

  QtObject { id: deckFixture; property int closed: 0; function closeOverlay() { closed++ } }
  Component { id: viewComponent; Modules.OverviewModule { deck: deckFixture } }
  Component { id: workspaceComponent; QtObject { property int id; property string name; property var monitor } }
  Component { id: monitorComponent; QtObject {
    property string name: "DP-1"
    property var activeWorkspace
    property var lastIpcObject: ({ specialWorkspace: { id: 0, name: "" } })
  } }
  Component {
    id: windowComponent
    QtObject {
      property string address
      property string title: "A window"
      property var lastIpcObject: ({ "class": "browser", mapped: true })
      property var workspace
      property var monitor
    }
  }

  function init() {
    monitor = createTemporaryObject(monitorComponent, testCase)
    one = createTemporaryObject(workspaceComponent, testCase, { id: 1, name: "1", monitor: monitor })
    two = createTemporaryObject(workspaceComponent, testCase, { id: 2, name: "2", monitor: monitor })
    parked = createTemporaryObject(workspaceComponent, testCase, { id: -98, name: "special:scratchpad", monitor: monitor })
    monitor.activeWorkspace = one
    browser = createTemporaryObject(windowComponent, testCase, { address: "abc", title: "Article", workspace: one, monitor: monitor })
    editor = createTemporaryObject(windowComponent, testCase, { address: "0xdef", title: "Notes", workspace: parked, monitor: monitor, lastIpcObject: ({ "class": "editor" }) })
    DesktopEntries.applications.values = [{ id: "browser", name: "Browser", icon: "" }, { id: "editor", name: "Editor", icon: "" }]
    Hyprland.workspaces.values = [one, two, parked]
    Hyprland.toplevels.values = [browser, editor]
    Hyprland.monitors.values = [monitor]
    Hyprland.focusedWorkspace = one
    Hyprland.activeToplevel = browser
    Hyprland.requests = []
    deckFixture.closed = 0
  }

  function cleanup() {
    Hyprland.workspaces.values = []
    Hyprland.toplevels.values = []
    Hyprland.monitors.values = []
    Hyprland.activeToplevel = null
    Hyprland.focusedWorkspace = null
  }

  function makeView(width, height) {
    var view = createTemporaryObject(viewComponent, testCase, { width: width || 1550, height: height || 350 })
    verify(view !== null)
    wait(20)
    return view
  }

  function test_liveMoveCloseAndFocus() {
    var view = makeView()
    var controller = findChild(view, "workspaceController")
    compare(controller.workspaces.length, 5)
    compare(controller.workspaces[0].windows[0].appName, "Browser")
    verify(findChild(view, "workspaceCard1").occupied)
    verify(!findChild(view, "workspaceCard2").occupied)
    compare(controller.parkedWindows.length, 1)
    browser.workspace = two
    Hyprland.focusedWorkspace = two
    tryCompare(findChild(view, "workspaceCard2"), "focused", true)
    verify(!findChild(view, "workspaceCard1").occupied)
    compare(controller.workspaces[1].windows.length, 1)
    browser.title = "Updated title"
    compare(controller.workspaces[1].windows[0].title, "Updated title")
    Hyprland.toplevels.values = [editor]
    verify(!controller.focusWindow("0xabc"))
    verify(!controller.parkFocusedWindow())
    compare(Hyprland.requests.length, 0)
  }

  function test_workspaceAndExactWindowTap() {
    var view = makeView()
    var header = findChild(view, "workspaceHeader2")
    mouseClick(header, header.width / 2, header.height / 2)
    compare(Hyprland.requests[0], 'hl.dsp.focus({ workspace = "2" })')
    compare(deckFixture.closed, 0)
    var list = findChild(view, "workspaceWindows1")
    var row = list.itemAtIndex(0)
    verify(row !== null)
    mouseClick(row, row.width / 2, row.height / 2)
    compare(Hyprland.requests[1], 'hl.dsp.focus({ window = "address:0xabc" })')
    compare(deckFixture.closed, 0)
  }

  function test_focusChangesOutlineWithoutChangingFill() {
    var view = makeView()
    var occupied = findChild(view, "workspaceCard1")
    var empty = findChild(view, "workspaceCard2")
    var occupiedFill = occupied.color
    var emptyFill = empty.color
    var activeBorder = occupied.borderSpec.color
    Hyprland.focusedWorkspace = two
    compare(occupied.color, occupiedFill)
    compare(empty.color, emptyFill)
    compare(empty.borderSpec.color, activeBorder)
    verify(occupied.borderSpec.color !== activeBorder)
  }

  function test_pointerFocusOnDeckPreservesPrimaryWorkspaceHighlight() {
    var view = makeView()
    var controller = findChild(view, "workspaceController")
    var edgeMonitor = createTemporaryObject(monitorComponent, testCase, { name: "DP-3" })
    var edgeWorkspace = createTemporaryObject(workspaceComponent, testCase, { id: -1337, name: "edge", monitor: edgeMonitor })
    edgeMonitor.activeWorkspace = edgeWorkspace
    Hyprland.monitors.values = [edgeMonitor, monitor]
    monitor.activeWorkspace = two
    Hyprland.focusedWorkspace = two
    verify(findChild(view, "workspaceCard2").focused)
    Hyprland.focusedWorkspace = edgeWorkspace
    verify(findChild(view, "workspaceCard2").focused)
    compare(controller.returnWorkspaceId, 2)
    // A shortcut can change the main display while the pointer stays on deck.
    monitor.activeWorkspace = one
    verify(findChild(view, "workspaceCard1").focused)
    verify(!findChild(view, "workspaceCard2").focused)
    Hyprland.focusedWorkspace = parked
    verify(findChild(view, "workspaceCard1").focused)
    Hyprland.focusedWorkspace = null
    verify(findChild(view, "workspaceCard1").focused)
    Hyprland.monitors.values = [edgeMonitor]
    compare(controller.focusedWorkspaceId, 0, "removed monitor cannot leave a stale selection")
    compare(controller.returnWorkspaceId, 0)
    compare(Hyprland.requests.length, 0, "pointer focus never dispatches workspace navigation")
  }

  function test_blankSpaceNavigatesButRowsDoNotDoubleDispatch() {
    var view = makeView()
    var card = findChild(view, "workspaceCard1")
    mouseClick(card, card.width / 2, card.height - 28)
    compare(Hyprland.requests.length, 1)
    compare(Hyprland.requests[0], 'hl.dsp.focus({ workspace = "1" })')
    var list = findChild(view, "workspaceWindows1")
    var row = list.itemAtIndex(0)
    mouseClick(row, row.width / 2, row.height / 2)
    compare(Hyprland.requests.length, 2)
    compare(Hyprland.requests[1], 'hl.dsp.focus({ window = "address:0xabc" })')
    var emptyCard = findChild(view, "workspaceCard4")
    mouseClick(emptyCard, emptyCard.width / 2, emptyCard.height - 28)
    compare(Hyprland.requests.length, 3)
    compare(Hyprland.requests[2], 'hl.dsp.focus({ workspace = "4" })')
  }

  function test_closePreferenceAndRefreshOnReopen() {
    var view = makeView()
    view.appearanceController = { workspaceCloseOnActivate: true }
    var controller = findChild(view, "workspaceController")
    controller.focusWorkspace(2)
    compare(deckFixture.closed, 1)
    view.appearanceController = { workspaceCloseOnActivate: false }
    controller.focusWindow("0xabc")
    compare(deckFixture.closed, 1)
    view.active = false
    wait(100)
    Hyprland.refreshCount = 0
    Hyprland.rawEvent({ name: "openwindow" })
    wait(100)
    compare(Hyprland.refreshCount, 0)
    view.active = true
    tryCompare(Hyprland, "refreshCount", 1)
    Hyprland.rawEvent({ name: "openwindow" })
    Hyprland.rawEvent({ name: "movewindowv2" })
    tryCompare(Hyprland, "refreshCount", 2)
    Hyprland.rawEvent({ name: "activespecial" })
    Hyprland.rawEvent({ name: "activespecialv2" })
    tryCompare(Hyprland, "refreshCount", 3)
  }

  function test_cardDragDoesNotSwitchWorkspace() {
    var view = makeView()
    var card = findChild(view, "workspaceCard1")
    mousePress(card, card.width / 2, card.height - 28)
    mouseMove(card, card.width / 2, card.height - 110, 40)
    mouseRelease(card, card.width / 2, card.height - 110)
    compare(Hyprland.requests.length, 0)
  }

  function test_scratchpadActionsAndStaleRows() {
    var view = makeView()
    var parkButton = findChild(view, "sendToScratchpadControl")
    verify(parkButton.enabled)
    compare(parkButton.bordered, false)
    mouseClick(parkButton, parkButton.width / 2, parkButton.height / 2)
    compare(Hyprland.requests[0], 'hl.dsp.window.move({ workspace = "special:scratchpad", follow = false, window = "address:0xabc" })')
    compare(deckFixture.closed, 0)
    var list = findChild(view, "parkedWindows")
    var row = list.itemAtIndex(0)
    var returnButton = findChild(row, "returnParkedWindow")
    compare(returnButton.borderSpec.widths.top, 0)
    mouseClick(returnButton, returnButton.width / 2, returnButton.height / 2)
    compare(Hyprland.requests[1], 'hl.dsp.window.move({ workspace = "1", follow = false, window = "address:0xdef" })')
    compare(deckFixture.closed, 0)
    Hyprland.toplevels.values = [browser]
    var controller = findChild(view, "workspaceController")
    verify(!controller.returnWindow("0xdef"))
    verify(!controller.toggleScratchpad())
    compare(Hyprland.requests.length, 2)
  }

  function test_scratchpadCardTogglesOnceAndFollowsCompositorVisibility() {
    var view = makeView()
    view.appearanceController = { workspaceCloseOnActivate: true }
    var panel = findChild(view, "scratchpadPanel")
    var header = findChild(view, "scratchpadHeader")
    var list = findChild(view, "parkedWindows")
    var hiddenBorder = panel.borderSpec.color
    compare(panel.showing, false)
    compare(findChild(view, "toggleScratchpadControl"), null)
    mouseClick(header, header.width / 2, header.height / 2)
    compare(Hyprland.requests.length, 1)
    compare(Hyprland.requests[0], 'hl.dsp.workspace.toggle_special("scratchpad")')
    compare(panel.showing, false, "visibility waits for compositor confirmation")
    monitor.lastIpcObject = { specialWorkspace: { id: -98, name: "special:scratchpad" } }
    compare(panel.showing, true)
    verify(panel.borderSpec.color !== hiddenBorder)
    mouseClick(list, list.width / 2, list.height - 20)
    compare(Hyprland.requests.length, 2)
    compare(Hyprland.requests[1], Hyprland.requests[0])
    monitor.lastIpcObject = { specialWorkspace: { id: 0, name: "" } }
    compare(panel.showing, false)
    compare(panel.borderSpec.color, hiddenBorder)
    var row = list.itemAtIndex(0)
    mouseClick(row, 30, row.height / 2)
    compare(Hyprland.requests.length, 3)
    compare(Hyprland.requests[2], Hyprland.requests[0])
    monitor.lastIpcObject = { specialWorkspace: { id: -98, name: "special:scratchpad" } }
    mouseClick(row, 30, row.height / 2)
    compare(Hyprland.requests.length, 4)
    compare(Hyprland.requests[3], Hyprland.requests[0])
    compare(deckFixture.closed, 0, "scratchpad remains available to tap again")
    // Changes made outside OmaDeck must update the same outline.
    monitor.lastIpcObject = { specialWorkspace: { id: -99, name: "special:other" } }
    compare(panel.showing, false)
    mousePress(list, list.width / 2, list.height - 20)
    mouseMove(list, list.width / 2, list.height - 90, 40)
    mouseRelease(list, list.width / 2, list.height - 90)
    compare(Hyprland.requests.length, 4, "dragging does not toggle")
  }

  function test_scratchpadTouchToggleAndReturn() {
    var view = makeView()
    var list = findChild(view, "parkedWindows")
    var gesture = touchEvent(list)
    gesture.press(0, list, list.width / 2, list.height - 20).commit()
    gesture.release(0, list, list.width / 2, list.height - 20).commit()
    compare(Hyprland.requests.length, 1)
    compare(Hyprland.requests[0], 'hl.dsp.workspace.toggle_special("scratchpad")')
    var row = list.itemAtIndex(0)
    gesture.press(0, row, 30, row.height / 2).commit()
    gesture.release(0, row, 30, row.height / 2).commit()
    compare(Hyprland.requests.length, 2)
    compare(Hyprland.requests[1], Hyprland.requests[0])
    var returnButton = findChild(row, "returnParkedWindow")
    gesture.press(0, returnButton, returnButton.width / 2, returnButton.height / 2).commit()
    gesture.release(0, returnButton, returnButton.width / 2, returnButton.height / 2).commit()
    compare(Hyprland.requests.length, 3)
    compare(Hyprland.requests[2], 'hl.dsp.window.move({ workspace = "1", follow = false, window = "address:0xdef" })')
    gesture.press(0, list, list.width / 2, list.height - 20).commit()
    gesture.move(0, list, list.width / 2, list.height - 90).commit()
    gesture.release(0, list, list.width / 2, list.height - 90).commit()
    compare(Hyprland.requests.length, 3)
  }

  function test_additionalWorkspaceAppearsAndDisappears() {
    var view = makeView()
    var extra = createTemporaryObject(workspaceComponent, testCase, { id: 8, name: "8", monitor: monitor })
    Hyprland.workspaces.values = [one, two, parked, extra]
    wait(20)
    verify(findChild(view, "workspaceCard8") !== null)
    Hyprland.workspaces.values = [one, two, parked]
    wait(20)
    compare(findChild(view, "workspaceCard8"), null)
    verify(findChild(view, "workspaceCard5") !== null)
  }

  function test_titlesPreserveCardsAndScroll() {
    var windows = [browser, editor]
    for (var i = 0; i < 18; i++)
      windows.push(createTemporaryObject(windowComponent, testCase, { address: "a" + (i + 16).toString(16), workspace: one, monitor: monitor }))
    Hyprland.toplevels.values = windows
    var view = makeView()
    var card = findChild(view, "workspaceCard1")
    var list = findChild(view, "workspaceWindows1")
    list.contentY = 120
    browser.title = "A title changed while browsing"
    wait(20)
    compare(findChild(view, "workspaceCard1"), card)
    compare(list.contentY, 120)
  }

  function test_windowReplacementDuringPressDoesNotRetargetTap() {
    var view = makeView()
    var list = findChild(view, "workspaceWindows1")
    var row = list.itemAtIndex(0)
    mousePress(row, 30, 25)
    var replacement = createTemporaryObject(windowComponent, testCase, { address: "0xaaa", workspace: one, monitor: monitor })
    Hyprland.toplevels.values = [replacement, editor]
    mouseRelease(row, 30, 25)
    compare(Hyprland.requests.length, 0)
  }

  function test_responsive_data() {
    return [{ tag: "edge", w: 1550, h: 350 }, { tag: "compact", w: 1000, h: 320 }, { tag: "narrow", w: 640, h: 360 }]
  }
  function test_responsive(data) {
    var view = makeView(data.w, data.h)
    var browserView = findChild(view, "workspaceBrowser")
    compare(browserView.columnCount, data.w === 1550 ? 5 : data.w === 1000 ? 4 : 3)
    var card = findChild(view, "workspaceCard1")
    verify(card.width >= 170)
    verify(card.height >= 210)
    var list = findChild(view, "parkedWindows")
    verify(list.height >= 62)
    var panel = findChild(view, "scratchpadPanel")
    verify(panel.x + panel.width <= view.width + 1)
    var park = findChild(view, "sendToScratchpadControl")
    verify(park.height >= 48)
  }
}
