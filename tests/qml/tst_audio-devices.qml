import QtQuick
import QtTest
import Quickshell.Services.Pipewire as Pw
import "../../services" as Services

TestCase {
  id: testCase
  name: "AudioDevices"
  when: windowShown
  width: 400
  height: 400
  visible: true

  Component { id: controllerComponent; Services.AudioDeviceController {} }
  Component {
    id: nodeComponent
    QtObject {
      property int id: 1
      property string name: "qr65"
      property string description: "QR65"
      property bool isSink: true
      property bool isStream: false
      property var audio: ({volume: 0.47, muted: false})
    }
  }
  property var speaker
  property var headset
  property var microphone
  function init() {
    speaker = createTemporaryObject(nodeComponent, testCase)
    headset = createTemporaryObject(nodeComponent, testCase, {id: 2, name: "headset", description: "Headphones"})
    microphone = createTemporaryObject(nodeComponent, testCase, {id: 3, name: "alias", isSink: false})
    Pw.Pipewire.nodes.values = [speaker, headset, microphone]
    Pw.Pipewire.defaultAudioSink = speaker
    Pw.Pipewire.defaultAudioSource = microphone
  }
  function createController() {
    var controller = createTemporaryObject(controllerComponent, testCase)
    verify(controller !== null)
    return controller
  }
  function exitProcess(controller, code) {
    var process = findChild(controller, "audioDeviceSwitchProcess")
    process.running = false
    process.exited(code)
  }
  function test_successWaitsForObservedDefaultAndBlocksDuplicateTaps() {
    var controller = createController()
    verify(controller.selectDevice("output", "2", "headset"))
    verify(controller.busy)
    verify(!controller.selectDevice("input", "3", "alias"))
    var process = findChild(controller, "audioDeviceSwitchProcess")
    compare(process.command[6], "/usr/bin/omarchy-audio-output-set-default")
    compare(process.command[7], "2")
    compare(process.command[8], "headset")
    exitProcess(controller, 0)
    verify(controller.busy, "successful helper exit must not pretend default changed")
    Pw.Pipewire.defaultAudioSink = headset
    compare(controller.busy, false)
    compare(controller.outputName, "headset")
    compare(controller.error, "")
    compare(speaker.audio.volume, 0.47)
    compare(microphone.audio.muted, false)
  }
  function test_inputSwitchAndExternalChangesRemainIndependent() {
    var controller = createController()
    Pw.Pipewire.defaultAudioSource = null
    verify(controller.selectDevice("input", "3", "alias"))
    compare(findChild(controller, "audioDeviceSwitchProcess").command[6], "/usr/bin/omarchy-audio-input-set-default")
    Pw.Pipewire.defaultAudioSource = microphone
    exitProcess(controller, 0)
    compare(controller.busy, false)
    compare(controller.outputName, "qr65")
    Pw.Pipewire.defaultAudioSink = headset
    compare(controller.outputName, "headset")
  }
  function test_disconnectedDeviceAndReusedIdsCannotBeSelected() {
    var controller = createController()
    compare(controller.outputs.length, 2)
    Pw.Pipewire.nodes.values = [speaker, microphone]
    verify(!controller.selectDevice("output", "2", "headset"))
    verify(controller.error.length > 0)
    compare(findChild(controller, "audioDeviceSwitchProcess").running, false)
    headset.name = "replacement"
    Pw.Pipewire.nodes.values = [speaker, headset, microphone]
    verify(!controller.selectDevice("output", "2", "headset"))
    tryCompare(controller, "outputs", controller.candidates.outputs)
    Pw.Pipewire.nodes.values = []
    wait(100)
    compare(controller.outputs.length, 0)
    compare(controller.inputs.length, 0)
  }
  function test_failureAndUnconfirmedSuccessRemainVisibleAndAllowRetry() {
    var controller = createController()
    controller.selectDevice("output", "2", "headset")
    exitProcess(controller, 1)
    verify(!controller.busy && controller.error.length > 0)
    verify(controller.selectDevice("output", "2", "headset"))
    compare(controller.error, "")
    exitProcess(controller, 0)
    tryCompare(controller, "busy", false, 2500)
    verify(controller.error.length > 0)
    compare(controller.outputName, "qr65")
  }
}
