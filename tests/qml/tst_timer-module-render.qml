import QtQuick
import QtTest
import "../../modules" as Modules

TestCase {
  id: testCase
  name: "TimerModuleRenderParity"
  when: windowShown

  width: 1900
  height: 1000
  visible: true

  function timerFor(state) {
    return {
      loaded: true,
      status: state === "setup" ? "idle" : state,
      remainingText: state === "completed" ? "0:00" : "12:34",
      progress: 0.5,
      selectedSoundName: "Complete",
      soundSettingsLoaded: true,
      selectedSoundId: "complete",
      start: function() { return { ok: true } },
      selectPreviousSound: function() {},
      selectNextSound: function() {},
      previewSelectedSound: function() {},
      stopPreview: function() {},
      pause: function() {},
      resume: function() {},
      add: function() {},
      restart: function() {},
      cancel: function() {},
      dismiss: function() {}
    }
  }

  function rows() {
    var result = []
    var states = ["setup", "active", "paused", "completed"]
    var bounds = [
      { name: "normal", width: 800, height: 500 },
      { name: "constrained", width: 328, height: 374 },
      { name: "short-wide", width: 527, height: 244 }
    ]
    for (var stateIndex = 0; stateIndex < states.length; stateIndex++) {
      for (var boundsIndex = 0; boundsIndex < bounds.length; boundsIndex++) {
        result.push({
          tag: states[stateIndex] + "-" + bounds[boundsIndex].name,
          state: states[stateIndex],
          width: bounds[boundsIndex].width,
          height: bounds[boundsIndex].height
        })
      }
    }
    return result
  }

  function test_renderParity_data() {
    return rows()
  }

  function test_renderParity(data) {
    var properties = {
      width: data.width,
      height: data.height,
      timer: timerFor(data.state),
      companionMode: true,
      setupOpen: data.state === "setup"
    }
    var after = createTemporaryObject(timerModuleComponent, testCase, properties)
    verify(after !== null)
    if (data.state !== "setup") after.openForCurrentStatus()
    wait(1)

    compare(after.width, data.width)
    compare(after.height, data.height)
    var overlay = findChild(after, "timerOverlay")
    verify(overlay !== null && overlay.visible)
    if (data.state === "setup") {
      var setup = findChild(after, "compactTimerSetupContent")
      var duration = findChild(after, "timerDurationSelector")
      var actions = findChild(after, "timerSetupActions")
      verify(setup !== null && duration !== null && actions !== null)
      verify(setup.height <= data.height + 0.5)
      verify(actions.width <= data.width + 0.5)
    }
    grabImage(after).save("/tmp/omadeck-timer-" + data.tag + ".png")
  }

  function test_exactDurationSelectionAndStart() {
    var timer = timerFor("setup")
    timer.startedHours = -1
    timer.startedMinutes = -1
    timer.startedSeconds = -1
    timer.start = function(hours, minutes, seconds) {
      timer.startedHours = hours
      timer.startedMinutes = minutes
      timer.startedSeconds = seconds
      return { ok: true }
    }
    var presenter = createTemporaryObject(timerModuleComponent, testCase, {
      width: 530,
      height: 180,
      timer: timer,
      companionMode: true,
      setupOpen: true
    })
    verify(presenter !== null)
    wait(1)

    var setupPanel = findChild(presenter, "compactTimerSetupContent")
    verify(setupPanel !== null)
    var secondsInput = findChild(setupPanel, "secondsTimerField")
    verify(secondsInput !== null)
    secondsInput.forceActiveFocus()
    secondsInput.text = "17"
    setupPanel.commitFields()
    wait(1)
    compare(presenter.selectedSeconds, 17)
    compare(presenter.selectedSegment, "seconds")

    presenter.adjustSelectedPart(1)
    compare(presenter.selectedSeconds, 18)
    compare(secondsInput.text, "18")
    presenter.selectedSeconds = 59
    presenter.adjustSelectedPart(1)
    compare(presenter.selectedMinutes, 6)
    compare(presenter.selectedSeconds, 0)
    presenter.startSelectedTimer()
    compare(timer.startedHours, 0)
    compare(timer.startedMinutes, 6)
    compare(timer.startedSeconds, 0)
    compare(presenter.open, false)
  }

  Component {
    id: timerModuleComponent
    Modules.TimerModule {}
  }
}
