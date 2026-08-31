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
      timer: timerFor(data.state)
    }
    var after = createTemporaryObject(clockModuleComponent, testCase, properties)
    verify(after !== null)

    mouseClick(after, data.width / 2, data.height / 2)
    wait(200)

    compare(after.width, data.width)
    compare(after.height, data.height)
    grabImage(after).save("/tmp/omadeck-timer-" + data.tag + ".png")
  }

  Component {
    id: clockModuleComponent
    Modules.ClockModule {}
  }
}
