import QtQuick
import QtTest
import "../../native/OmaDeck/Touch" as NativeTouch

TestCase {
  id: testCase
  name: "HostInputGuardIntegration"
  property bool lockRequested: false
  property bool sessionLocked: false
  property bool sessionSecure: false
  property bool strandedLock: false
  property bool strandedLockResolved: false
  readonly property bool locked: lockRequested || sessionLocked || sessionSecure
  NativeTouch.TouchBridge { id: observer }

  // Same optional Loader/binding installed inside the trusted lock plugin.
  Loader {
    id: publisher
    active: false
    source: Qt.resolvedUrl("../../integrations/omarchy/NativeInputGuard.qml")
    onLoaded: item.blocked = Qt.binding(function() {
      return testCase.locked || !testCase.strandedLockResolved || testCase.strandedLock
    })
  }

  function cleanup() {
    publisher.active = false
    verify(!observer.hostInputAllowed)
    tryCompare(observer, "hostGuardAvailable", false)
    lockRequested = sessionLocked = sessionSecure = strandedLock = strandedLockResolved = false
  }

  function test_allLockPhasesAndProviderUnloadBlockInputSynchronously() {
    verify(!observer.hostGuardAvailable)
    publisher.active = true
    tryCompare(publisher, "status", Loader.Ready)
    verify(observer.hostGuardAvailable)
    verify(!observer.hostInputAllowed) // recovery unresolved
    strandedLockResolved = true
    verify(observer.hostInputAllowed)
    lockRequested = true
    verify(!observer.hostInputAllowed) // before compositor acquires lock
    sessionLocked = true
    sessionSecure = true
    lockRequested = false
    verify(!observer.hostInputAllowed)
    sessionLocked = false
    verify(!observer.hostInputAllowed)
    sessionSecure = false
    verify(observer.hostInputAllowed)
    strandedLock = true
    verify(!observer.hostInputAllowed)
    strandedLock = false
    verify(observer.hostInputAllowed)
    publisher.active = false
    verify(!observer.hostInputAllowed)
    tryCompare(observer, "hostGuardAvailable", false)
    publisher.active = true
    tryCompare(publisher, "status", Loader.Ready)
    verify(observer.hostInputAllowed)
  }

  function test_missingOptionalProviderDoesNotDestroyLockOwner() {
    var loader = Qt.createQmlObject('import QtQuick; Loader {}', testCase)
    ignoreWarning(/.*omadeck-missing-input-guard.qml: No such file or directory/)
    loader.source = Qt.resolvedUrl("omadeck-missing-input-guard.qml")
    tryCompare(loader, "status", Loader.Error)
    verify(!observer.hostInputAllowed)
    verify(testCase !== null)
    loader.destroy()
  }
}
