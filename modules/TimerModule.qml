import QtQuick
import qs.Commons
import qs.Ui
import "../components"

Item {
  id: root

  property var timer: null
  property bool companionMode: false
  property bool setupOpen: false
  property bool controlsOpen: false
  property int selectedHours: 0
  property int selectedMinutes: 5
  property int selectedSeconds: 0
  property string selectedSegment: "minutes"

  readonly property string timerStatus: timer ? timer.status : "idle"
  readonly property string timerRemainingText: timer ? timer.remainingText : "0:00"
  readonly property int selectedTotalSeconds: selectedHours * 3600
    + selectedMinutes * 60 + selectedSeconds
  readonly property bool selectedDurationValid: selectedHours >= 0 && selectedHours <= 99
    && selectedMinutes >= 0 && selectedMinutes <= 59
    && selectedSeconds >= 0 && selectedSeconds <= 59
    && selectedTotalSeconds > 0
  readonly property bool open: setupOpen || controlsOpen
  readonly property bool presenterActive: root.open
  readonly property int touchTarget: 48

  function openForCurrentStatus() {
    if (!timer || !timer.loaded) return
    if (timerStatus === "idle") openSetup()
    else openControls()
  }

  function openSetup() {
    if (!timer || !timer.loaded || timerStatus !== "idle") return
    controlsOpen = false
    setupOpen = true
  }

  function openControls() {
    if (!timer || !timer.loaded || timerStatus === "idle") return
    setupOpen = false
    controlsOpen = true
  }

  function close() {
    setupOpen = false
    controlsOpen = false
  }

  function cancelSetup() {
    if (timer) timer.stopPreview()
    close()
  }

  function setSelectedPart(part, value) {
    var maximum = part === "hours" ? 99 : 59
    var normalized = Math.max(0, Math.min(maximum, Number(value) || 0))
    if (part === "hours") selectedHours = Math.floor(normalized)
    else if (part === "minutes") selectedMinutes = Math.floor(normalized)
    else if (part === "seconds") selectedSeconds = Math.floor(normalized)
  }

  function adjustSelectedPart(delta) {
    var step = selectedSegment === "hours" ? 3600
      : selectedSegment === "seconds" ? 1 : 60
    var next = Math.max(0, Math.min(99 * 3600 + 59 * 60 + 59,
      selectedTotalSeconds + delta * step))
    selectedHours = Math.floor(next / 3600)
    selectedMinutes = Math.floor((next % 3600) / 60)
    selectedSeconds = next % 60
  }

  function startSelectedTimer() {
    if (!selectedDurationValid || !timer) return
    var response = timer.start(selectedHours, selectedMinutes, selectedSeconds)
    if (response && response.ok) close()
  }

  onTimerStatusChanged: {
    if (setupOpen && timerStatus !== "idle") {
      if (timer) timer.stopPreview()
      setupOpen = false
    }
    if (timerStatus === "completed") controlsOpen = true
    else if (controlsOpen && timerStatus === "idle") controlsOpen = false
  }

  Component.onCompleted: if (timerStatus === "completed") controlsOpen = true
  Component.onDestruction: if (timer) timer.stopPreview()

  Item {
    id: timerOverlay
    objectName: "timerOverlay"
    visible: root.open
    anchors.fill: parent
    z: 50

    ResponsivePanel {
      id: timerViewport
      anchors.fill: parent
      padding: root.companionMode ? 0 : Style.space(12)
      maximumContentWidth: Style.space(620)

      TimerSetupPanel {
        id: pickerContent
        objectName: "timerSetupContent"
        visible: root.setupOpen && !root.companionMode
        width: parent.width
        presenter: root
      }

      TimerSetupPanel {
        id: compactSetupContent
        objectName: "compactTimerSetupContent"
        visible: root.setupOpen && root.companionMode
        width: parent.width
        presenter: root
      }

      Column {
        id: controlsContent
        visible: root.controlsOpen
        width: parent.width
        spacing: Style.spacing.labelGap

        Text {
          visible: !root.companionMode || root.height >= Style.space(110)
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.timerStatus === "completed" ? "Time's up"
            : root.timerStatus === "paused" ? "Paused · " + root.timerRemainingText
            : root.timerRemainingText + " remaining"
          color: root.timerStatus === "completed" ? Color.accent : Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Row {
          id: activeTimerActions
          objectName: "activeTimerActions"
          visible: root.timerStatus === "active" || root.timerStatus === "paused"
          width: parent.width
          spacing: Style.spacing.controlGap
          readonly property real cellWidth: Math.max(root.touchTarget,
            (width - spacing * 3) / 4)

          Button {
            width: activeTimerActions.cellWidth
            height: root.touchTarget
            text: root.timerStatus === "paused" ? "Resume" : "Pause"
            bordered: false
            selected: root.timerStatus === "paused"
            Accessible.role: Accessible.Button
            Accessible.name: root.timerStatus === "paused" ? "Resume timer" : "Pause timer"
            onClicked: root.timerStatus === "paused" ? root.timer.resume() : root.timer.pause()
          }
          Button {
            width: activeTimerActions.cellWidth
            height: root.touchTarget
            text: "Hide"
            bordered: false
            Accessible.role: Accessible.Button
            Accessible.name: "Close timer controls"
            onClicked: root.close()
          }
          Button {
            width: activeTimerActions.cellWidth
            height: root.touchTarget
            text: "+5 min"
            bordered: false
            Accessible.role: Accessible.Button
            Accessible.name: "Add 5 minutes"
            onClicked: root.timer.add(5)
          }
          Button {
            width: activeTimerActions.cellWidth
            height: root.touchTarget
            text: "Cancel"
            bordered: false
            foreground: Color.accent
            Accessible.role: Accessible.Button
            Accessible.name: "Cancel timer"
            onClicked: root.timer.cancel()
          }
        }

        Button {
          visible: root.timerStatus === "completed"
          anchors.horizontalCenter: parent.horizontalCenter
          width: Style.space(180)
          height: root.touchTarget
          text: "Dismiss"
          selected: true
          Accessible.role: Accessible.Button
          Accessible.name: "Dismiss timer"
          onClicked: root.timer.dismiss()
        }
      }
    }
  }
}
