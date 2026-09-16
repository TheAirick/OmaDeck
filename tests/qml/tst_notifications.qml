import QtQuick
import QtTest
import qs.Commons
import "../../modules" as Modules
import "../../components" as Components

TestCase {
  id: testCase
  name: "NotificationDrawer"
  when: windowShown
  width: 1800; height: 700
  visible: true
  function rows() {
    return [
      { app: "Build tools", appIcon: "", summary: "Build finished", body: "Your preview is ready.\n\nThe build completed with all checks passing.", timestamp: Date.now() - 65000, originalId: 11, live: false },
      { app: "Chat", appIcon: "", summary: "A long notification title that should wrap without obscuring the controls", body: Array(80).join("This is a longer message with detail. ") + "<img src='https://invalid.example/track'>", timestamp: Date.now() - 600000, originalId: 12, live: false }
    ]
  }
  function init() { state.entries = rows(); state.clearCalls = 0; state.openCalls = 0; state.refreshCalls = 0; state.dnd = false; state.night = false; state.busy = false; state.loading = false; state.historyError = ""; state.notice = "" }
  function make(width, height) {
    var view = createTemporaryObject(viewComponent, testCase, { width: width, height: height, active: true, controller: state })
    verify(view !== null)
    wait(50)
    return view
  }
  function bounds(item, parent) { var p = item.mapToItem(parent, 0, 0); return { x: p.x, y: p.y, width: item.width, height: item.height } }
  function click(item) { mouseClick(item, item.width / 2, item.height / 2); wait(10) }

  function test_wideLayoutReadsMessageAndSeparatesActivation() {
    var view = make(1550, 375)
    var list = findChild(view, "notificationCenterList")
    var detail = findChild(view, "notificationMessagePane")
    var controls = findChild(view, "notificationControlsPane")
    verify(view.wide)
    verify(list.visible && detail.visible && controls.visible)
    verify(controls.contentHeight <= controls.height, "all quick controls fit the Edge-height fixture")
    verify(detail.x > list.width)
    verify(detail.x + detail.width < controls.x)
    compare(state.openCalls, 0)
    list.positionViewAtIndex(1, ListView.Contain)
    wait(20)
    click(list.itemAtIndex(1))
    compare(findChild(view, "notificationMessageBody").text, state.entries[1].body)
    compare(findChild(view, "notificationMessageBody").textFormat, Text.PlainText)
    compare(state.openCalls, 0, "reading does not execute notification actions")
    var scroll = findChild(view, "notificationMessageScroll")
    wait(50)
    grabImage(view).save("/tmp/omadeck-notifications-fixture-wide.png")
    verify(scroll.contentHeight > scroll.height, "long message scroll geometry: " + scroll.contentHeight + "/" + scroll.height)
    var key = view.selectedKey
    state.entries = [ {app: "New app", summary: "New arrival", body: "Arrived while open", timestamp: Date.now(), originalId: 99} ].concat(state.entries)
    compare(view.selectedKey, key, "new arrivals preserve the selected message")
    click(findChild(view, "notificationOpenApp"))
    compare(state.openCalls, 1)
    grabImage(view).save("/tmp/omadeck-notifications-fixture-wide.png")
  }

  function test_touchScrollDoesNotOpenNotification() {
    var view = make(900, 260)
    state.entries = rows().concat(rows()).concat(rows())
    var list = findChild(view, "notificationCenterList")
    var gesture = touchEvent(list)
    gesture.press(0, list, 120, 160).commit()
    gesture.move(0, list, 120, 40).commit()
    gesture.release(0, list, 120, 40).commit()
    wait(100)
    compare(view.reading, false)
    compare(state.openCalls, 0)
  }

  function test_narrowListReaderAndControls_data() {
    return [{ tag: "medium", width: 900, height: 350 }, {tag: "narrow", width: 480, height: 320}]
  }
  function test_narrowListReaderAndControls(data) {
    var view = make(data.width, data.height)
    var list = findChild(view, "notificationCenterList")
    click(list.itemAtIndex(0))
    verify(findChild(view, "notificationMessagePane").visible)
    var action = findChild(view, "notificationOpenApp")
    verify(action.x + action.width <= findChild(view, "notificationMessagePane").width)
    verify(!findChild(view, "notificationFeedPane").visible)
    click(findChild(view, "notificationBackToList"))
    verify(findChild(view, "notificationFeedPane").visible)
    if (view.narrow) {
      click(findChild(view, "notificationShowControls"))
      verify(findChild(view, "notificationControlsPane").visible)
      verify(!findChild(view, "notificationFeedPane").visible)
      click(findChild(view, "notificationBackFromControls"))
      verify(findChild(view, "notificationFeedPane").visible)
    }
    var feed = findChild(view, "notificationFeedPane")
    for (var name of ["notificationClearControl", "notificationRefreshControl"]) {
      var button = findChild(view, name), r = bounds(button, feed)
      verify(r.x >= 0 && r.x + r.width <= feed.width + 1, name)
      verify(button.height >= 48)
    }
    grabImage(view).save("/tmp/omadeck-notifications-fixture-" + data.tag + ".png")
  }

  function test_clearRequiresConfirmationAndCanBeCancelled() {
    var view = make(1550, 375)
    click(findChild(view, "notificationClearControl"))
    compare(state.clearCalls, 0)
    verify(view.clearArmed)
    click(findChild(view, "notificationCancelClear"))
    compare(state.clearCalls, 0)
    verify(!view.clearArmed)
    click(findChild(view, "notificationClearControl"))
    click(findChild(view, "notificationConfirmClear"))
    compare(state.clearCalls, 1)
    compare(state.entries.length, 0)
    verify(!findChild(view, "notificationClearControl").enabled)
    grabImage(view).save("/tmp/omadeck-notifications-fixture-empty.png")
  }

  function test_controlStatesAndDisabledActions() {
    var view = make(1550, 375)
    var dnd = findChild(view, "notificationDndControl")
    var night = findChild(view, "notificationNightlightControl")
    click(dnd)
    verify(state.dnd && dnd.checked)
    click(dnd)
    verify(!state.dnd && !dnd.checked)
    click(night)
    verify(state.night && night.checked)
    state.busy = true
    click(dnd)
    verify(!state.dnd)
    state.busy = false
    view.active = false
    click(night)
    verify(state.night)
    verify(!findChild(view, "notificationWifiControl").available)
  }

  Component {
    id: viewComponent
    Modules.NotificationCenterModule {
      Rectangle { anchors.fill: parent; color: Color.background; z: -1 }
    }
  }
  QtObject {
    id: state
    property var entries: []
    property bool loading: false
    property bool busy: false
    property bool dnd: false
    property bool night: false
    property bool dndAvailable: true
    property bool nightAvailable: true
    property string historyError: ""
    property string notice: ""
    property int clearCalls: 0
    property int openCalls: 0
    property int refreshCalls: 0
    signal appOpened()
    function refresh() { refreshCalls++ }
    function clearAll() { clearCalls++; entries = [] }
    function openApp(entry) { openCalls++ }
    function toggleDnd() { dnd = !dnd }
    function toggleNightlight() { night = !night }
  }
}
