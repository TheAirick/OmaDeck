import QtQuick
import QtTest
import Quickshell
import qs.Commons
import "../../modules" as Modules
import "../../services" as Stores

TestCase {
  id: testCase
  name: "LauncherCustomization"
  when: windowShown
  width: 1600; height: 700
  visible: true
  function init() {
    store.customEntries = []; store.entryIds = ["terminal", "browser"]; store.loaded = true; store.directoryReady = true
    store.savePending = false; store.saveInFlight = false; store.saveError = ""; store.actionNotice = ""; store.revision++
    DesktopEntries.applications.values = [
      {id: "org.example.Hidden", name: "Hidden app", icon: "", startupClass: "hidden-class", noDisplay: true},
      {id: "org.example.Editor", name: "Editor", icon: "", genericName: "Write code", startupClass: "editor-class"}
    ]
  }
  function click(item) { verify(item !== null); wait(30); mouseClick(item, item.width / 2, item.height / 2); wait(20) }
  function view(width) {
    var result = createTemporaryObject(viewFactory, testCase, {width: width || 1550, height: 375})
    verify(result !== null); wait(80); return result
  }
  function test_allInstalledAppsAreSearchableAndCanBePinned() {
    var prefs = view(), editor = findChild(prefs, "launcherPreferences")
    click(findChild(editor, "launcherBrowseApps"))
    verify(editor.rows.some(function(entry) { return entry.id === "desktop:org.example.Hidden" }))
    editor.query = "write code"
    compare(editor.rows.length, 1)
    editor.choose(editor.rows[0])
    click(findChild(editor, "launcherPinSelected"))
    verify(store.entryIds.indexOf("desktop:org.example.Editor") !== -1)
    verify(!findChild(editor, "launcherPinSelected").enabled)
    editor.query = "not-an-app"
    compare(editor.rows.length, 0)
  }
  function test_commandDraftUsesTouchKeyboardAndSaveDoesNotExecute() {
    var prefs = view(), editor = findChild(prefs, "launcherPreferences")
    click(findChild(editor, "launcherNewCommand"))
    click(findChild(editor, "launcherField-name"))
    verify(prefs.keyboardRequested)
    var key = findChild(prefs, "launcherKey:b")
    verify(key.enabled && key.visible)
    click(key)
    compare(findChild(prefs, "launcherTextInput").text, "b")
    editor.finishText("Backup")
    verify(!prefs.keyboardRequested)
    editor.editField("command")
    var input = findChild(prefs, "launcherTextInput")
    input.forceActiveFocus(); for (var character of "printf '%s' 'quoted value' > result.txt") keyClick(character)
    compare(input.text, "printf '%s' 'quoted value' > result.txt")
    grabImage(prefs).save("/tmp/omadeck-launcher-keyboard.png")
    editor.finishText(input.text)
    editor.setDraft("directory", "~/Documents")
    editor.setDraft("terminal", true); editor.setDraft("iconId", "backup")
    editor.saveCommand()
    compare(store.customEntries.length, 1)
    compare(store.entries()[2].name, "Backup")
    compare(store.entries()[2].iconId, "backup")
    verify(store.entries()[2].terminal)
    compare(store.actionNotice, "", "saving must not launch")
    compare(store.launching, false)
    editor.choose(editor.rows[2]); editor.beginCommand(editor.selected)
    editor.setDraft("name", "Changed draft")
    editor.page = "pinned"
    compare(store.customEntries[0].name, "Backup", "leaving an unfinished draft preserves saved command")
    wait(60)
    grabImage(prefs).save("/tmp/omadeck-launcher-buttons.png")
  }
  function test_validationAndRemoval() {
    var prefs = view(), editor = findChild(prefs, "launcherPreferences")
    editor.beginCommand(null); editor.saveCommand()
    verify(editor.notice !== ""); compare(store.customEntries.length, 0)
    editor.draft = {name: "Build", command: "true", directory: "relative", terminal: false, iconId: "code"}
    editor.saveCommand(); verify(editor.notice.indexOf("folder") >= 0)
    editor.setDraft("directory", ""); editor.saveCommand()
    var id = store.entryIds[2]
    editor.choose(editor.rows[2])
    click(findChild(editor, "launcherRemoveSelected"))
    verify(store.entryIds.indexOf(id) !== -1)
    click(findChild(editor, "launcherRemoveSelected"))
    compare(store.customEntries.length, 0); compare(store.entryIds.length, 2)
  }
  function test_hideReleasesTypingAndScrollDoesNotSelect() {
    var prefs = view(1000), editor = findChild(prefs, "launcherPreferences")
    editor.browseApps(); editor.editField("query"); verify(prefs.keyboardRequested)
    prefs.selectedCategory = "timer"; wait(20)
    verify(!prefs.keyboardRequested)
    prefs.selectedCategory = "launcher"; wait(20)
    compare(editor.inputField, "")
    var many = []
    for (var i = 0; i < 30; i++) many.push({id: "fixture" + i, name: "Application " + i, icon: ""})
    DesktopEntries.applications.values = many
    wait(40)
    var list = findChild(editor, "launcherCatalogList")
    var touch = touchEvent(list)
    touch.press(0, list, 80, list.height - 10).commit()
    for (var y = list.height - 20; y >= 30; y -= 10) {
      wait(16); touch.move(0, list, 80, y).commit()
    }
    touch.release(0, list, 80, 30).commit()
    wait(60)
    compare(editor.selectedId, "")
    grabImage(prefs).save("/tmp/omadeck-launcher-apps.png")
  }
  function test_catalogRefreshPreservesScrolledPosition() {
    var many = [], ids = []
    for (var i = 0; i < 90; i++) {
      many.push({id: "fixture" + i, name: "Application " + String(i).padStart(2, "0"), icon: ""})
      ids.push("desktop:fixture" + i)
    }
    DesktopEntries.applications.values = many
    store.entryIds = ids; store.revision++
    var prefs = view(), editor = findChild(prefs, "launcherPreferences")
    var list = findChild(editor, "launcherCatalogList")
    for (var page of ["pinned", "apps"]) {
      editor.page = page; wait(40)
      list.contentY = 360; wait(30)
      var position = list.contentY
      // Desktop discovery and icon metadata refresh while the user is browsing.
      DesktopEntries.applications.values = many.map(function(app) { return Object.assign({}, app, {genericName: "Updated description"}) })
      store.revision++
      wait(60)
      compare(list.contentY, position, page + " must not jump during metadata updates")
      var first = list.itemAtIndex(0)
      DesktopEntries.applications.values = many
      store.revision++; wait(40)
      compare(list.itemAtIndex(0), first, "refresh keeps existing delegates")
      compare(list.contentY, position)
    }
  }
  function swipe(list) {
    var y = list.height - 12
    mousePress(list, 80, y)
    for (var i = 1; i <= 8; i++) mouseMove(list, 80, y - i * (list.height - 35) / 8, 16)
    mouseRelease(list, 80, 23, Qt.LeftButton, Qt.NoModifier, 16)
    tryCompare(list, "moving", false, 2000)
  }
  function test_shortSwipesAreBoundedAndDoNotActivateButtons() {
    var many = [], ids = []
    for (var i = 0; i < 90; i++) {
      many.push({id: "fixture" + i, name: "Application " + i, icon: ""})
      ids.push("desktop:fixture" + i)
    }
    DesktopEntries.applications.values = many
    store.entryIds = ids; store.revision++
    var prefs = view(), editor = findChild(prefs, "launcherPreferences")
    var list = findChild(editor, "launcherCatalogList")
    for (var page of ["pinned", "apps"]) {
      editor.page = page; wait(40)
      swipe(list)
      verify(list.contentY - list.originY > 20, page + " swipe must scroll")
      verify(list.contentY - list.originY < list.height * 2, page + " swipe must stay near the dragged distance")
      compare(editor.selectedId, "", "dragging must not select or activate a button")
      var end = list.originY + Math.max(0, list.contentHeight - list.height)
      list.contentY = end; swipe(list)
      fuzzyCompare(list.contentY, end, 1, "cannot scroll beyond last row")
      editor.query = "Application 89"; wait(60)
      compare(list.contentY, list.originY, "search intentionally starts at the first result")
      compare(list.count, 1)
      var result = list.itemAtIndex(0)
      verify(result !== null)
      fuzzyCompare(result.mapToItem(list, 0, 0).y, 0, 1, "the matching app is visible at the top")
    }
    editor.beginCommand(null); wait(40)
    var form = findChild(editor, "launcherCommandForm")
    swipe(form)
    verify(form.contentY > 20)
    verify(form.contentY <= Math.max(0, form.contentHeight - form.height) + 1)
    compare(editor.inputField, "", "scrolling a field must not open the keyboard")
    compare(store.customEntries.length, 0, "scrolling cannot save or run a command")
  }
  function test_gridUsesAvailableWidthAndActionsStayInView_data() {
    return [{tag: "edge", width: 1550}, {tag: "compact", width: 1000}]
  }
  function test_gridUsesAvailableWidthAndActionsStayInView(data) {
    store.entryIds = ["terminal", "browser", "discord", "files", "music", "steam"]; store.revision++
    var prefs = view(data.width), editor = findChild(prefs, "launcherPreferences")
    var list = findChild(editor, "launcherCatalogList")
    compare(list.width, editor.width)
    verify(list.cellWidth <= list.width / 2, "space is shared by multiple app columns")
    verify(list.height >= list.cellHeight)
    if (data.width === 1550) verify(list.contentHeight <= list.height, "six buttons fit without scrolling on the Edge")
    editor.draft = {name: "Backup files", command: "true", directory: "", terminal: false, iconId: "backup"}
    editor.saveCommand(); wait(40)
    for (var armed of [false, true]) {
      editor.removeArmed = armed; wait(40)
      var bar = findChild(editor, "launcherSelectionBar"), actions = findChild(editor, "launcherSelectionActions")
      verify(actions.x >= 0 && actions.x + actions.width <= bar.width + 1, "all actions fit horizontally")
      var bounds = bar.mapToItem(editor, 0, 0)
      verify(bounds.y >= list.height && bounds.y + bar.height <= editor.height + 1, "actions stay below the scroll area")
    }
    editor.removeArmed = false
    grabImage(prefs).save("/tmp/omadeck-launcher-layout-" + data.tag + ".png")
  }
  Component {
    id: viewFactory
    Modules.PreferencesModule {
      selectedCategory: "launcher"
      deck: deckFixture
      Rectangle { anchors.fill: parent; z: -1; color: Color.background }
    }
  }
  Stores.LauncherController { id: store }
  QtObject {
    id: deckFixture
    property var launcherController: store
    property var shell: null
    property string openOverlayName: "preferences"
  }
}
