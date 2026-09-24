import QtQuick
import QtTest
import qs.Commons
import "../../modules" as Modules
import "../../services" as Stores

TestCase {
  id: testCase
  name: "MonitorInputs"
  width: 1000; height: 1800
  visible: true
  when: windowShown
  Component { id: controllerComponent; Stores.MonitorInputController {} }
  Component { id: preferencesComponent; Modules.MonitorInputPreferences {} }
  Component { id: moduleComponent; Modules.MonitorInputModule {} }

  function controller() {
    var store = createTemporaryObject(controllerComponent, testCase)
    verify(store !== null)
    store.loaded = true
    store.directoryReady = true
    store.detectedMonitors = [
      { id: "a".repeat(64), label: "Office", connector: "card1-DP-1", error: "", inputs: [{ code: "0f", label: "DisplayPort 1" }, { code: "11", label: "HDMI 1" }, { code: "12", label: "HDMI 2" }] },
      { id: "b".repeat(64), label: "Studio", connector: "card1-DP-2", error: "", inputs: [{ code: "0f", label: "DisplayPort 1" }, { code: "11", label: "HDMI 1" }] }
    ]
    return store
  }

  function click(item) { verify(item !== null); mouseClick(item, item.width / 2, item.height / 2); wait(20) }

  function test_setupEnableInputsLabelsAndRemoval() {
    var store = controller()
    var view = createTemporaryObject(preferencesComponent, testCase, { controller: store, width: 940 })
    view.setupStep = ""
    verify(!store.showControls)
    wait(20)
    click(findChild(view, "detectedMonitor:" + "a".repeat(64)))
    compare(store.monitors.length, 1)
    verify(!store.showControls, "adding a monitor does not enable hardware buttons")
    click(findChild(view, "preferencesMonitorSwitching"))
    verify(store.showControls)
    compare(view.editingId, "a".repeat(64))
    click(findChild(view, "configuredInput:12"))
    compare(store.selectedMonitor.sources.length, 3)
    findChild(view, "preferencesInputToLabel").changed("12")
    findChild(view, "preferencesInputLabel").changed("Console")
    compare(store.selectedMonitor.sources[2].label, "Console")
    store.detectedMonitors = []
    wait(20)
    compare(findChild(view, "configuredInput:12").label, "HDMI 2", "port identity survives renaming and reopening without a scan")
    compare(findChild(view, "configuredInput:12").description, "Shown as Console")
    compare(findChild(view, "preferencesInputToLabel").options[2].label, "HDMI 2")
    store.detectedMonitors = [
      { id: "b".repeat(64), label: "Studio", connector: "card1-DP-2", error: "", inputs: [{ code: "0f", label: "DisplayPort 1" }, { code: "11", label: "HDMI 1" }] }
    ]
    wait(20)
    click(findChild(view, "detectedMonitor:" + "b".repeat(64)))
    compare(store.monitors.length, 2)
    compare(store.selectedMonitor.label, "Studio")
    verify(store.cycleMonitor(-1))
    compare(store.selectedMonitor.label, "Office")
    click(findChild(view, "preferencesRemoveMonitor"))
    compare(store.monitors.length, 1)
    compare(store.selectedMonitor.label, "Office")
    verify(!store.switchInput("a".repeat(64), "ff"))
    click(findChild(view, "preferencesMonitorSwitching"))
    verify(!store.showControls)
    verify(!store.switchInput("a".repeat(64), "0f"))
  }

  function test_guidedSetupFromEmptySettingsToNamedButtons() {
    var store = controller()
    var view = createTemporaryObject(preferencesComponent, testCase, { controller: store, width: 940 })
    wait(20)
    compare(view.setupStep, "computer")
    verify(!findChild(view, "preferencesMonitorSwitching").visible)
    store.setupStatus = { state: "missing-software", canPrepare: true }
    store.pluginDir = "/fixture"
    var primary = findChild(view, "monitorSetupPrimary")
    compare(primary.text, "Install monitor support")
    grabImage(view).save("/tmp/omadeck-monitor-setup-missing.png")
    click(primary)
    verify(store.setupWindowOpened)
    compare(view.setupStep, "computer", "opening an installer does not claim setup succeeded")
    compare(primary.text, "Check again")
    store.pluginDir = ""
    store.setupStatus = { state: "ready", canPrepare: false }
    store.setupWindowOpened = false
    click(primary)
    compare(view.setupStep, "monitor")
    grabImage(view).save("/tmp/omadeck-monitor-setup-discovery.png")
    click(findChild(view, "setupMonitor:" + "a".repeat(64)))
    compare(view.setupStep, "inputs")
    verify(!store.showControls)
    findChild(view, "preferencesInputToLabel").changed("0f")
    findChild(view, "preferencesInputLabel").changed("Mac")
    findChild(view, "preferencesInputToLabel").changed("11")
    findChild(view, "preferencesInputLabel").changed("Omarchy")
    click(findChild(view, "monitorSetupFinish"))
    compare(view.setupStep, "")
    verify(store.showControls)
    compare(store.selectedMonitor.sources[0].label, "Mac")
    compare(store.selectedMonitor.sources[1].label, "Omarchy")
    compare(store.operation, "", "guided setup never switches a hardware input")
  }

  function test_hiddenPreferencesDoNotStartSetupOnStartup() {
    var store = controller()
    store.pluginDir = "/fixture"
    var view = createTemporaryObject(preferencesComponent, testCase, { controller: store, width: 940, visible: false })
    wait(20)
    compare(store.operation, "")
    compare(view.setupStep, "")
    view.visible = true
    compare(view.setupStep, "computer")
    compare(store.operation, "check")
  }

  function test_inputButtonsRemainTouchSizedAndInactiveBehindOverlay() {
    var store = controller()
    verify(store.addMonitor("a".repeat(64)))
    verify(store.setShown(true))
    var module = createTemporaryObject(moduleComponent, testCase, { controller: store, width: 280, height: 104 })
    wait(20)
    var source = findChild(module, "monitorSource:11")
    verify(source.width >= 48 && source.height >= 48)
    module.enabled = false
    verify(!module.switchTo("a".repeat(64), "11"))
    compare(store.operation, "")
    verify(store.removeMonitor("a".repeat(64)))
    wait(20)
    compare(module.monitor, null)
  }

  function test_monitorNavigationDoesNotOverlapSourceButtons_data() {
    return [480, 360, 352, 336, 320, 304].map(function(width) {
      return { tag: "width-" + width, panelWidth: width }
    })
  }

  function test_monitorNavigationDoesNotOverlapSourceButtons(data) {
    var store = controller()
    verify(store.addMonitor("b".repeat(64)))
    verify(store.addMonitor("a".repeat(64)))
    verify(store.setShown(true))
    verify(store.setSource("a".repeat(64), "0f", true, "Omarchy"))
    verify(store.setSource("a".repeat(64), "11", true, "Mac"))
    var module = createTemporaryObject(moduleComponent, testCase, { controller: store, width: data.panelWidth, height: 104 })
    wait(20)
    var left = findChild(module, "monitorSource:0f")
    var right = findChild(module, "monitorSource:11")
    var details = findChild(module, "monitorDetails")
    var previous = findChild(module, "previousMonitor")
    var next = findChild(module, "nextMonitor")
    verify(module.centeredMonitor, "drawer resizing should retain the single row while its touch targets fit")
    verify(left.width >= 64 && right.width >= 64)
    compare(left.mapToItem(module, 0, 0).y, details.mapToItem(module, 0, 0).y)
    compare(left.height, details.height)
    compare(findChild(module, "monitorSourceIcon:0f").font.pixelSize, Style.font.displayLarge)
    verify(left.mapToItem(module, 0, 0).x >= previous.mapToItem(module, previous.width, 0).x)
    verify(left.mapToItem(module, left.width, 0).x <= details.mapToItem(module, 0, 0).x + 0.01)
    verify(right.mapToItem(module, 0, 0).x >= details.mapToItem(module, details.width, 0).x - 0.01)
    verify(right.mapToItem(module, right.width, 0).x <= next.mapToItem(module, 0, 0).x + 0.01)
    compare(findChild(module, "monitorSourceIcon:0f").font.family, "omarchy")
    compare(findChild(module, "monitorSourceIcon:11").text, "󰀵")
    click(details)
    compare(store.operation, "", "monitor label must not change the physical input")
    click(next)
    compare(store.selectedMonitor.label, "Studio")
    compare(store.operation, "", "monitor navigation only changes the displayed monitor")
    click(previous)
    compare(store.selectedMonitor.label, "Office")

    module.width = 280
    verify(store.setSource("a".repeat(64), "12", true, "Console"))
    wait(20)
    for (var code of ["0f", "11", "12"]) {
      var source = findChild(module, "monitorSource:" + code)
      verify(source.width >= 48 && source.height >= 48)
      verify(source.mapToItem(module, 0, 0).y >= next.mapToItem(module, 0, next.height).y)
    }
  }
}
