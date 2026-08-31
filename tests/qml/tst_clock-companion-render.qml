import QtQuick
import QtTest
import "../../modules" as Modules

TestCase {
  id: testCase
  name: "ClockCompanionRender"
  when: windowShown

  width: 900
  height: 520
  visible: true

  function appearance(showWeather) {
    return {
      use24Hour: false,
      showSeconds: false,
      showWeather: showWeather,
      weatherStyle: "scene",
      weatherDetail: "standard",
      temperatureUnit: "fahrenheit"
    }
  }

  function weatherFor(state) {
    if (state === "weather-loading") return { loading: true, error: "", current: null }
    if (state === "weather-unavailable") return { loading: false, error: "network", current: null }
    if (state === "weather-current") return {
      loading: false,
      error: "",
      current: {
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
      }
    }
    return { loading: false, error: "", current: null }
  }

  function makeHost(width, height, state) {
    var timer = createTemporaryObject(timerStubComponent, testCase, {
      status: state === "setup" || state.indexOf("weather-") === 0 ? "idle" : state
    })
    verify(timer !== null)
    var host = createTemporaryObject(companionComponent, testCase, {
      width: width,
      height: height,
      controller: appearance(state !== "weather-disabled"),
      weather: weatherFor(state),
      timer: timer
    })
    verify(host !== null)
    wait(0)
    if (state === "setup") {
      var presenter = findChild(host, "timerPresenter")
      verify(presenter !== null)
      presenter.openSetup()
      wait(200)
    } else wait(200)
    return { host: host, timer: timer }
  }

  function visiblePresenters(host) {
    var weather = findChild(host, "weatherPresenter")
    var timer = findChild(host, "timerPresenter")
    verify(weather !== null)
    verify(timer !== null)
    return Number(weather.visible) + Number(timer.visible)
  }

  function collectTargets(item, host, result) {
    if (!item || !item.visible) return
    if (item.Accessible && item.Accessible.name) {
      var start = item.mapToItem(host, 0, 0)
      var end = item.mapToItem(host, item.width, item.height)
      result.push({
        name: item.Accessible.name,
        x: Math.min(start.x, end.x),
        y: Math.min(start.y, end.y),
        width: Math.abs(end.x - start.x),
        height: Math.abs(end.y - start.y)
      })
    }
    for (var index = 0; index < item.children.length; index++)
      collectTargets(item.children[index], host, result)
  }

  function test_stateRendering_data() {
    return [
      { tag: "weather-loading", state: "weather-loading" },
      { tag: "weather-disabled", state: "weather-disabled" },
      { tag: "weather-unavailable", state: "weather-unavailable" },
      { tag: "weather-current", state: "weather-current" },
      { tag: "setup", state: "setup" },
      { tag: "active", state: "active" },
      { tag: "paused", state: "paused" },
      { tag: "completed", state: "completed" }
    ]
  }

  function test_stateRendering(data) {
    var fixture = makeHost(530, 380, data.state)
    compare(visiblePresenters(fixture.host), 1)
    compare(fixture.host.occupant, data.state.indexOf("weather-") === 0 ? "weather" : "timer")
    wait(50)
    grabImage(fixture.host).save("/tmp/omadeck-companion-" + data.tag + ".png")
  }

  function test_drawerGeometry_data() {
    var bounds = [
      { tag: "closed-036", width: 530, height: 380 },
      { tag: "left-036", width: 329, height: 380 },
      { tag: "right-036", width: 329, height: 380 },
      { tag: "top-036", width: 530, height: 288 },
      { tag: "bottom-036", width: 530, height: 250 },
      { tag: "closed-044", width: 660, height: 380 },
      { tag: "left-044", width: 431, height: 380 },
      { tag: "right-044", width: 431, height: 380 },
      { tag: "top-044", width: 660, height: 288 },
      { tag: "bottom-044", width: 660, height: 250 }
    ]
    var states = ["setup", "active", "paused", "completed"]
    var result = []
    for (var boundsIndex = 0; boundsIndex < bounds.length; boundsIndex++) {
      for (var stateIndex = 0; stateIndex < states.length; stateIndex++) {
        result.push({
          tag: bounds[boundsIndex].tag + "-" + states[stateIndex],
          width: bounds[boundsIndex].width,
          height: bounds[boundsIndex].height,
          state: states[stateIndex]
        })
      }
    }
    return result
  }

  function test_drawerGeometry(data) {
    var fixture = makeHost(data.width, data.height, data.state)
    var slot = findChild(fixture.host, "companionSlot")
    verify(slot !== null)
    compare(visiblePresenters(fixture.host), 1)
    compare(fixture.host.clockHeight, Math.round((data.height - fixture.host.panelGap) * 0.37))
    compare(fixture.host.companionHeight,
      data.height - fixture.host.panelGap - fixture.host.clockHeight)

    var targets = []
    collectTargets(slot, fixture.host, targets)
    var minimumTargetCount = data.state === "setup" ? 10
      : data.state === "completed" ? 1 : 4
    verify(targets.length >= minimumTargetCount, data.tag + " target count " + targets.length)
    for (var index = 0; index < targets.length; index++) {
      var target = targets[index]
      verify(target.width >= 48, data.tag + " " + target.name + " width " + target.width)
      verify(target.height >= 48, data.tag + " " + target.name + " height " + target.height)
      verify(target.x >= slot.x - 0.5, data.tag + " " + target.name + " left")
      verify(target.y >= slot.y - 0.5, data.tag + " " + target.name + " top")
      verify(target.x + target.width <= slot.x + slot.width + 0.5, data.tag + " " + target.name + " right")
      verify(target.y + target.height <= slot.y + slot.height + 0.5, data.tag + " " + target.name + " bottom")
    }
  }

  function test_repeatedLifecycleChurn() {
    for (var cycle = 0; cycle < 20; cycle++) {
      var fixture = makeHost(530, 380, "setup")
      var presenter = findChild(fixture.host, "timerPresenter")
      compare(fixture.host.occupant, "timer")
      presenter.cancelSetup()
      compare(fixture.timer.stopPreviewCalls, 1)
      compare(fixture.host.occupant, "weather")
      presenter.openSetup()
      presenter.startSelectedTimer()
      compare(fixture.timer.startCalls, 1)
      compare(fixture.timer.status, "active")
      compare(fixture.host.occupant, "timer")
      fixture.timer.cancel()
      compare(fixture.host.occupant, "weather")
      fixture.host.destroy()
      fixture.timer.destroy()

      var recreation = makeHost(530, 380, "setup")
      recreation.timer.previewSelectedSound()
      compare(recreation.timer.previewRunning, true)
      recreation.host.destroy()
      wait(0)
      compare(recreation.timer.stopPreviewCalls, 1)
      compare(recreation.timer.previewRunning, false)
      recreation.timer.destroy()

      var externalRestore = makeHost(530, 380, "setup")
      externalRestore.timer.previewSelectedSound()
      externalRestore.timer.status = "active"
      wait(0)
      compare(findChild(externalRestore.host, "timerPresenter").setupOpen, false)
      compare(externalRestore.timer.stopPreviewCalls, 1)
      compare(externalRestore.timer.previewRunning, false)
      externalRestore.host.destroy()
      wait(0)
      compare(externalRestore.timer.stopPreviewCalls, 2)
      externalRestore.timer.destroy()
    }
  }

  Component {
    id: companionComponent
    Modules.ClockCompanionModule {}
  }

  Component {
    id: timerStubComponent
    QtObject {
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
      function add() {}
      function restart() { status = "active" }
      function cancel() { status = "idle" }
      function dismiss() { status = "idle" }
    }
  }
}
