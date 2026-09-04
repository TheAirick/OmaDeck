import QtQuick
import QtTest
import "../../modules" as Modules

TestCase {
  id: testCase
  name: "Preferences"
  when: windowShown
  width: 1100
  height: 800
  visible: true

  Component { id: preferencesComponent; Modules.PreferencesModule {} }

  function test_legacyClockStyleIsExplicitlyInactive() {
    var module = createTemporaryObject(preferencesComponent, testCase, { width: 1100, height: 800 })
    var choice = findChild(module, "preferencesClockStyle")
    verify(choice !== null)
    compare(choice.label, "Clock style (legacy)")
    compare(choice.description, "Retained for compatibility; the current Clock always uses Compact")
    compare(choice.enabled, false)
  }

  function test_configRouteDoesNotClaimValidation() {
    var module = createTemporaryObject(preferencesComponent, testCase, {
      width: 1100, height: 800, selectedCategory: "advanced"
    })
    var action = findChild(module, "preferencesConfig")
    verify(action !== null)
    compare(action.description, "Open Omarchy's configuration files in an editor")
  }

  function optionsIn(item) {
    var found = []
    if (item.modelData !== undefined && item.selected !== undefined)
      found.push(item)
    for (var i = 0; i < item.children.length; i++)
      found = found.concat(optionsIn(item.children[i]))
    return found
  }

  function test_dynamicHardwareChoicesFit_data() {
    return [
      { tag: "target", category: "displays", name: "preferencesTargetScreen" },
      { tag: "primary", category: "displays", name: "preferencesPrimaryMonitor" },
      { tag: "touch", category: "input", name: "preferencesTouchDevice" }
    ]
  }

  function test_dynamicHardwareChoicesFit(data) {
    var names = ["DP-1", "DP-2", "DP-3", "DP-4", "DP-5",
      "Synthetic touchscreen with a very long descriptive product name",
      "SyntheticUnbrokenDeviceIdentityABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
    var selected = []
    var hardware = {
      loaded: true, availableScreenNames: names, availableTouchDeviceNames: names,
      targetScreen: names[0], primaryMonitor: names[0], selectedTouchDeviceName: names[0],
      setTargetScreen: function(v) { selected.push(v); return true },
      setPrimaryMonitor: function(v) { selected.push(v); return true },
      setTouchDevice: function(v) { selected.push(v); return true }
    }
    var module = createTemporaryObject(preferencesComponent, testCase, {
      width: 1100, height: 800, hardwareController: hardware, selectedCategory: data.category
    })
    verify(module !== null)
    var choice = findChild(module, data.name)
    verify(choice !== null)
    for (var w of [1100, 650, 900]) {
      module.width = w
      wait(30)
      var options = optionsIn(choice)
      compare(options.length, names.length)
      var rows = {}
      for (var option of options) {
        var origin = option.mapToItem(choice, 0, 0)
        verify(option.width >= 48 && option.height >= 48, "touch target")
        verify(origin.x >= 0 && origin.x + option.width <= choice.width + 0.5,
          "option fits choice width: " + option.modelData.label)
        verify(origin.y >= 0 && origin.y + option.height <= choice.height + 0.5,
          "option fits choice height: " + option.modelData.label)
        compare(option.Accessible.name, option.modelData.label)
        for (var child of option.children) {
          if (child.text !== undefined) {
            compare(child.text, option.modelData.label)
            verify(child.x >= 0 && child.x + child.width <= option.width + 0.5,
              "full label stays inside target horizontally")
            verify(child.y >= 0 && child.y + child.implicitHeight <= option.height + 0.5,
              "wrapped label stays inside target vertically")
            compare(child.truncated, false)
          }
        }
        rows[Math.round(origin.y)] = true
      }
      verify(Object.keys(rows).length > 1, "many options wrap")
      compare(choice.height, choice.implicitHeight, "parent honors wrapped height")
      var siblings = choice.parent.children
      for (var sibling of siblings) {
        if (sibling !== choice && sibling.visible && sibling.y > choice.y)
          verify(sibling.y >= choice.y + choice.height, "next setting does not overlap")
      }
      // Scroll the final option into view, then exercise the real pointer route.
      var last = options[options.length - 1]
      var list = choice.parent.parent
      while (list && list.contentY === undefined) list = list.parent
      verify(list !== null)
      list.contentY = Math.max(0, last.mapToItem(list.contentItem, 0, 0).y - 20)
      wait(1)
      var previousCalls = selected.length
      mouseClick(last, last.width / 2, last.height / 2)
      compare(selected.length, previousCalls + 1)
      compare(selected[selected.length - 1], names[names.length - 1])
    }
  }

  function test_hostRequestsDoNotClaimPersistence_data() {
    return [
      { tag: "dnd", method: "applyDoNotDisturb", args: [true], call: "dnd", value: true },
      { tag: "nightlight", method: "applyNightlight", args: [true], call: "nightlight", value: true },
      { tag: "awake", method: "applyKeepAwake", args: [true], call: "idle", value: false },
      { tag: "position", method: "applyBarPosition", args: ["left"], key: "bar", field: "position", value: "left" },
      { tag: "transparency", method: "applyBarTransparency", args: [true], key: "bar", field: "transparent", value: true },
      { tag: "screensaver", method: "applyIdleTimeout", args: ["screensaver", "600"], key: "idle", field: "screensaver", value: 600 },
      { tag: "lock", method: "applyIdleTimeout", args: ["lock", "900"], key: "idle", field: "lock", value: 900 }
    ]
  }

  function test_hostRequestsDoNotClaimPersistence(data) {
    // Void host APIs can queue work without changing live state or saving disk.
    var calls = []
    var pendingMutator = null
    var service = {
      stateLoaded: true, stayAwakeStateLoaded: true, idleEnabled: true,
      doNotDisturb: false, enabled: false,
      screensaverTimeoutSeconds: 150, lockTimeoutSeconds: 300,
      setDoNotDisturb: function(v) { calls.push(["dnd", v]) },
      setNightlight: function(v) { calls.push(["nightlight", v]) },
      setIdleEnabled: function(v) { calls.push(["idle", v]) }
    }
    var host = {
      shellConfig: {},
      firstPartyServiceFor: function(id) { return service },
      mutateShellConfig: function(fn) { pendingMutator = fn }
    }
    var module = createTemporaryObject(preferencesComponent, testCase, {
      width: 1100, height: 800, shell: host
    })
    verify(module !== null)
    compare(module[data.method].apply(module, data.args), true)
    if (data.call) {
      compare(calls.length, 1)
      compare(calls[0][0], data.call)
      compare(calls[0][1], data.value)
    } else {
      verify(pendingMutator !== null)
      var config = { unrelated: "preserved" }
      pendingMutator(config)
      compare(config[data.key][data.field], data.value)
      compare(config.unrelated, "preserved")
    }
    compare(module.notice, "Requested")
    compare(service.doNotDisturb, false)
    compare(service.enabled, false)
    compare(service.idleEnabled, true)
    compare(module.barPosition, "top")
  }
}
