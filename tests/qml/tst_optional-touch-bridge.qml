import QtQuick
import QtTest
import "../../components" as Components

TestCase {
  name: "OptionalTouchRouting"
  Component {
    id: bridgeComponent
    Components.OptionalTouchBridge {
      nativeSource: Qt.resolvedUrl("TouchBridgeFixture.qml")
    }
  }

  function test_privateLockHostNeverGrabsEvenAfterReconnectOrArtifactLoad() {
    var wrapper = createTemporaryObject(bridgeComponent, this, { directRoutingAllowed: false })
    wrapper.start()
    wrapper.nativeArtifactPresent = true
    tryCompare(wrapper, "nativeAvailable", true)
    compare(wrapper.bridge.starts, 0)
    compare(wrapper.active, false)
    compare(wrapper.mode, "compositor")
    wrapper.stop()
    wrapper.start()
    compare(wrapper.bridge.starts, 0)
    compare(wrapper.active, false)
  }

  function test_revokingLockAccessReleasesActiveNativeBridge() {
    var wrapper = createTemporaryObject(bridgeComponent, this)
    wrapper.nativeArtifactPresent = true
    tryCompare(wrapper, "nativeAvailable", true)
    wrapper.start()
    verify(wrapper.active)
    compare(wrapper.mode, "native")
    wrapper.directRoutingAllowed = false
    compare(wrapper.active, false)
    compare(wrapper.devicePath, "")
    compare(wrapper.mode, "compositor")
    wrapper.directRoutingAllowed = true
    verify(wrapper.active)
    compare(wrapper.bridge.starts, 2)
    wrapper.stop()
  }

  function test_privateHostGuardRestoresIndependentRoutingAndFailsClosedOnLoss() {
    var wrapper = createTemporaryObject(bridgeComponent, this, { directRoutingAllowed: false })
    wrapper.nativeArtifactPresent = true
    tryCompare(wrapper, "nativeAvailable", true)
    wrapper.start()
    verify(!wrapper.active)
    wrapper.bridge.hostGuardAvailable = true
    compare(wrapper.mode, "native")
    verify(wrapper.active)
    verify(wrapper.bridge.requireHostGuard)
    verify(!wrapper.hostInputAllowed)
    wrapper.bridge.hostInputAllowed = true
    verify(wrapper.hostInputAllowed)
    wrapper.bridge.hostInputAllowed = false
    verify(wrapper.active) // locking retains isolated device ownership
    wrapper.bridge.hostGuardAvailable = false
    verify(!wrapper.active)
    compare(wrapper.mode, "compositor")
    wrapper.bridge.hostGuardAvailable = true
    verify(wrapper.active)
  }
}
