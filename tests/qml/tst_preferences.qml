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

  function test_onlyAppCategoriesAreExposed() {
    var module = createTemporaryObject(preferencesComponent, testCase, { width: 1100, height: 800 })
    compare(module.categories.map(function(entry) { return entry.id }).join(","),
      "omadeck,workspaces,timer,hardware,monitors,launcher")
    for (var name of ["preferencesClockStyle", "preferencesTheme", "preferencesConfig",
      "preferencesDoNotDisturb", "preferencesBarPosition", "preferencesPowerActions"])
      compare(findChild(module, name), null)
  }

  function test_workspaceCloseSetting() {
    var saves = []
    var module = createTemporaryObject(preferencesComponent, testCase, {
      width: 1100, height: 450, selectedCategory: "workspaces",
      appearanceController: {
        workspaceCloseOnActivate: false, use24Hour: false, showSeconds: false,
        showWeather: true, weatherStyle: "scene", weatherDetail: "standard", temperatureUnit: "fahrenheit",
        setOption: function(key, value) { saves.push([key, value]); return true }
      }
    })
    wait(30)
    var control = findChild(module, "preferencesWorkspaceCloseOnActivate")
    verify(control !== null)
    mouseClick(control, control.width / 2, control.height / 2)
    compare(saves.length, 1)
    compare(saves[0][0], "workspaceCloseOnActivate")
    compare(saves[0][1], true)
    compare(module.notice, "Saved")
  }

  function test_categoryChangeResetsScrollAndRefreshesTouchDevices() {
    var refreshes = 0
    var module = createTemporaryObject(preferencesComponent, testCase, {
      width: 1100, height: 450,
      deck: { refreshTouchDevices: function() { refreshes++ } }
    })
    var list = findChild(module, "omaDeckPreferencesList")
    list.contentY = 300
    module.selectedCategory = "hardware"
    compare(list.contentY, 0)
    compare(refreshes, 1)
    module.selectedCategory = "timer"
    compare(refreshes, 1)
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
      { tag: "target", category: "hardware", name: "preferencesTargetScreen" },
      { tag: "primary", category: "hardware", name: "preferencesPrimaryMonitor" },
      { tag: "touch", category: "hardware", name: "preferencesTouchDevice" }
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

}
