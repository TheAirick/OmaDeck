import QtQuick
import QtTest
import "services"
TestCase {
  name: "ControllerRecovery"
  function test_directoryFailureKeepsEditsUntilRecovery() {
    var controllers = [createTemporaryObject(layoutFactory, this),
                       createTemporaryObject(launcherFactory, this)]
    for (var i = 0; i < 2; ++i) {
      var c = controllers[i]
      c.scheduleSave() // edits are not discarded before mkdir completes
      var p = findChild(c, "mkdirProcess")
      if (i === 0) p.exited(1)
      p.running = false // launcher exercises FailedToStart, no exited
      compare(c.directoryReady, false)
      compare(c.savePending, true)
      verify(c.saveError !== "")
    }
    var first = findChild(controllers[0], "mkdirProcess")
    tryCompare(first, "running", true, 6000)
    for (i = 0; i < 2; ++i) {
      c = controllers[i]
      p = findChild(c, "mkdirProcess")
      tryCompare(p, "running", true)
      p.started()
      p.exited(0)
      p.running = false
      compare(c.directoryReady, true)
      tryCompare(c, "savePending", false)
      compare(c.saveError, "")
    }
  }
  function test_settingsIdenticalSaveDoesNotWaitForMissingSignal() {
    var controllers = [createTemporaryObject(layoutFactory, this),
                       createTemporaryObject(launcherFactory, this)]
    for (var i = 0; i < controllers.length; ++i) {
      var c = controllers[i]
      c.directoryReady = true
      c.scheduleSave()
      tryCompare(c, "savePending", false)
      c.scheduleSave()
      tryCompare(c, "savePending", false, 500)
      compare(c.saveInFlight, false)
    }
  }
  function test_settingsAutomaticallyRetryWithoutBusyLoop() {
    var controllers = [createTemporaryObject(layoutFactory, this),
                       createTemporaryObject(launcherFactory, this)]
    var files = [findChild(controllers[0], "layoutFile"),
                 findChild(controllers[1], "settingsFile")]
    for (var i = 0; i < 2; ++i) {
      controllers[i].directoryReady = true
      controllers[i].loaded = true
      files[i].failWrites = true
      controllers[i].scheduleSave()
    }
    tryCompare(files[0], "writes", 1)
    tryCompare(files[1], "writes", 1)
    wait(300)
    for (i = 0; i < 2; ++i) {
      compare(files[i].writes, 1)
      files[i].failWrites = false
    }
    tryCompare(controllers[0], "savePending", false, 6000)
    tryCompare(controllers[1], "savePending", false, 6000)
    for (i = 0; i < 2; ++i) {
      compare(controllers[i].saveError, "")
      compare(files[i].writes, 2)
    }
  }
  Component { id: launcherFactory; LauncherController {} }
  function test_launcherWriteFailurePreservesLatestDirtyState() {
    var c = createTemporaryObject(launcherFactory, this)
    c.directoryReady = true
    c.loaded = true
    var file = findChild(c, "settingsFile")
    file.failWrites = true
    c.remove(c.entryIds[0])
    var expected = JSON.stringify(c.entryIds)
    tryCompare(file, "writes", 1)
    compare(c.savePending, true)
    verify(c.saveError !== "")
    c.load("{}")
    compare(JSON.stringify(c.entryIds), expected)
    file.failWrites = false
    file.deferWrites = true
    c.persist()
    c.remove(c.entryIds[0])
    expected = JSON.stringify(c.entryIds)
    wait(250)
    compare(file.writes, 2)
    file.finishWrite()
    compare(c.savePending, true)
    tryCompare(file, "writes", 3)
    file.finishWrite()
    compare(c.savePending, false)
    compare(c.saveError, "")
    compare(JSON.stringify(JSON.parse(file.content).entries), expected)
  }
  Component { id: layoutFactory; LayoutController {} }
  function test_layoutWriteFailurePreservesLatestDirtyState() {
    var c = createTemporaryObject(layoutFactory, this)
    c.directoryReady = true
    c.loaded = true
    var file = findChild(c, "layoutFile")
    file.failWrites = true
    c.setRatio("", 0.6)
    tryCompare(file, "writes", 1)
    compare(c.savePending, true)
    verify(c.saveError !== "")
    file.content = JSON.stringify(c.defaultLayout())
    file.loaded() // stale watch/load completion must not overwrite edits
    compare(c.layout.root.ratio, 0.6)
    wait(300)
    compare(file.writes, 1)
    file.failWrites = false
    file.deferWrites = true
    c.persist()
    compare(c.savePending, true)
    c.setRatio("", 0.7)
    wait(250)
    compare(file.writes, 2) // no overlapping async writes
    file.finishWrite()
    compare(c.savePending, true)
    tryCompare(file, "writes", 3)
    file.finishWrite()
    compare(c.savePending, false)
    compare(c.saveError, "")
    compare(JSON.parse(file.content).root.ratio, 0.7)
  }
  Component { id: trayFactory; TrayOwner {} }
  function test_trayFailedLaunchBackoff() {
    var c = createTemporaryObject(trayFactory, this)
    var p = findChild(c, "trayController")
    var delay = findChild(c, "trayRestartDelay")
    c.startTray()
    p.running = false
    compare(c.trayRestartFailures, 1)
    compare(delay.running, true)
    compare(delay.interval, 1000)
    delay.stop()
    for (var i = 0; i < 8; ++i) {
      c.startTray()
      p.running = false
      delay.stop()
    }
    compare(delay.interval, 30000)
    c.startTray()
    p.started()
    p.exited(0)
    p.running = false
    compare(delay.running, false)
    compare(c.trayRestartFailures, 0)
    c.startTray()
    c.unloading = true
    c.stopTray()
    compare(delay.running, false)
  }
  Component { id: weatherFactory; WeatherController { pluginDir: "/nonexistent-test" } }
  function test_weatherFailedStartReleasesRequest() {
    var c = createTemporaryObject(weatherFactory, this)
    c.enabled = true
    var p = findChild(c, "weatherProcess")
    compare(c.loading, true)
    // Quickshell 0.3.1 FailedToStart emits runningChanged only.
    p.running = false
    tryCompare(c, "loading", false)
    compare(c.requestActive, false)
    compare(c.error, "Weather unavailable")
    c.refresh()
    compare(p.running, true)
    p.started()
    p.stdout.text = JSON.stringify({ok: true, code: 0, forecast: []})
    p.exited(0)
    p.running = false
    compare(c.loading, false)
    compare(c.error, "")
    compare(c.current.ok, true)
    wait(20)
    compare(c.error, "") // runningChanged after exited must not fail twice
    c.enabled = false
  }
  Component { id: timerFactory; TimerController {} }
  function test_liveDeadlineFailureDoesNotWriteEveryClockTick() {
    var c = createTemporaryObject(timerFactory, this)
    c.directoryReady = true
    c.soundSettingsLoaded = true
    c.selectedSoundId = ""
    var file = findChild(c, "timerFile")
    file.failWrites = true
    c.load(JSON.stringify({version: 1, status: "active", originalDurationMs: 60000,
      currentDurationMs: 60000, deadlineMs: Date.now() + 100, pausedRemainingMs: 0,
      notificationSent: false}))
    wait(450)
    compare(file.writes, 1)
    compare(c.status, "completed")
    compare(c.timerState.notificationSent, false)
  }
  function test_overdueClaimRecoversOnce() {
    var c = createTemporaryObject(timerFactory, this)
    verify(c)
    c.directoryReady = true
    c.soundSettingsLoaded = true
    c.selectedSoundId = ""
    var file = findChild(c, "timerFile")
    var notification = findChild(c, "completionNotification")
    file.failWrites = true
    c.load(JSON.stringify({version: 1, status: "active", originalDurationMs: 60000,
      currentDurationMs: 60000, deadlineMs: Date.now() - 1000, pausedRemainingMs: 0,
      notificationSent: false}))
    compare(c.status, "completed")
    compare(notification.running, false)
    var attempts = file.writes
    wait(300)
    compare(file.writes, attempts) // no per-frame failed-claim write loop
    file.failWrites = false
    tryCompare(notification, "running", true, 6500)
    compare(c.timerState.notificationSent, true)
    var savedAttempts = file.writes
    notification.running = false
    c.load(file.content)
    wait(1200)
    compare(notification.running, false)
    compare(file.writes, savedAttempts)
  }
}
