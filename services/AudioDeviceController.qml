import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "AudioDevices.js" as Devices

Item {
  id: root
  objectName: "audioDeviceController"
  visible: false

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var output: Pipewire.defaultAudioSink
  readonly property var input: Pipewire.defaultAudioSource
  readonly property string outputName: output ? String(output.name) : ""
  readonly property string inputName: input ? String(input.name) : ""
  readonly property string outputLabel: Devices.label(output)
  readonly property string inputLabel: Devices.label(input)
  readonly property var candidates: ({
    outputs: Devices.snapshot(nodes, "output"),
    inputs: Devices.snapshot(nodes, "input")
  })
  property var outputs: []
  property var inputs: []
  property string error: ""
  property string pendingKind: ""
  property string pendingName: ""
  readonly property bool busy: pendingName !== ""
  signal selected(string kind)

  // Defer presentation changes beyond PipeWire's node removal signal stack.
  onCandidatesChanged: snapshotDelay.restart()
  Component.onCompleted: refresh()
  function refresh() {
    outputs = candidates.outputs.slice()
    inputs = candidates.inputs.slice()
  }
  Timer { id: snapshotDelay; interval: 75; onTriggered: root.refresh() }

  function selectDevice(kind, id, name) {
    if (busy || switchProcess.running) return false
    error = ""
    // A device may disappear, or its numeric ID be reused, between paint and tap.
    if (!Devices.find(nodes, kind, id, name) || !/^[0-9]+$/.test(String(id))) {
      error = "Device disconnected. Choose another device."
      refresh()
      return false
    }
    if ((kind === "output" ? outputName : inputName) === name) {
      selected(kind)
      return true
    }
    pendingKind = kind
    pendingName = name
    // Installed Omarchy owns routing, including moving current app streams and
    // preserving DSP filter connections. No shell interpolation or saved copy.
    switchProcess.command = ["/usr/bin/env", "PATH=/usr/bin:/usr/share/omarchy/bin",
      "/usr/bin/timeout", "--signal=TERM", "--kill-after=1s", "8s",
      kind === "output" ? "/usr/bin/omarchy-audio-output-set-default"
        : "/usr/bin/omarchy-audio-input-set-default", String(id), name]
    switchProcess.running = true
    switchDeadline.restart()
    return true
  }

  function finish(success) {
    var kind = pendingKind
    switchDeadline.stop()
    confirmDelay.stop()
    pendingKind = ""
    pendingName = ""
    if (success) selected(kind)
    else error = "Couldn't confirm the switch. Check the selected device and try again."
  }
  function confirm() {
    if (!busy) return
    if ((pendingKind === "output" ? outputName : inputName) === pendingName) finish(true)
  }
  onOutputNameChanged: if (confirmDelay.running) confirm()
  onInputNameChanged: if (confirmDelay.running) confirm()

  Process {
    id: switchProcess
    objectName: "audioDeviceSwitchProcess"
    onExited: function(exitCode) {
      if (!root.busy) return
      if (exitCode !== 0) { root.finish(false); return }
      // The helper's exit status alone is insufficient: observe PipeWire's
      // actual default, allowing its metadata update to arrive asynchronously.
      confirmDelay.restart()
      root.confirm()
    }
  }
  Timer { id: confirmDelay; interval: 2000; onTriggered: root.finish(false) }
  Timer {
    id: switchDeadline
    interval: 11000
    onTriggered: {
      if (switchProcess.running) switchProcess.signal(9)
      root.finish(false)
    }
  }
  Component.onDestruction: {
    if (switchProcess.running) switchProcess.running = false
  }
}
