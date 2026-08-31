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

  readonly property string timerStatus: timer ? timer.status : "idle"
  readonly property string timerRemainingText: timer ? timer.remainingText : "0:00"
  readonly property bool selectedDurationValid: selectedHours >= 0 && selectedHours <= 99
    && selectedMinutes >= 0 && selectedMinutes <= 59
    && (selectedHours > 0 || selectedMinutes > 0)
  readonly property bool open: setupOpen || controlsOpen
  readonly property bool presenterActive: root.setupOpen || root.timerStatus !== "idle"
  readonly property int touchTarget: 48

  function openForCurrentStatus() {
    if (!timer || !timer.loaded) return
    if (timerStatus === "idle") openSetup()
    else openControls()
  }

  function openSetup() {
    if (!timer || !timer.loaded || timerStatus !== "idle") return
    setupOpen = true
  }

  function openControls() {
    if (!timer || !timer.loaded || timerStatus === "idle") return
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

  function setPreset(minutes) {
    selectedHours = Math.floor(minutes / 60)
    selectedMinutes = minutes % 60
  }

  function startSelectedTimer() {
    if (!selectedDurationValid || !timer) return
    var response = timer.start(selectedHours, selectedMinutes)
    if (response && response.ok) close()
  }

  onTimerStatusChanged: {
    if (setupOpen && timerStatus !== "idle") {
      if (timer) timer.stopPreview()
      setupOpen = false
    }
    if (controlsOpen && (timerStatus === "idle" || timerStatus === "completed")) controlsOpen = false
  }

  Component.onDestruction: if (timer) timer.stopPreview()

  Rectangle {
    id: timerOverlay
    objectName: "timerOverlay"
    visible: root.companionMode ? root.presenterActive : root.open
    anchors.fill: parent
    color: Color.background
    border.color: Color.accent
    border.width: Math.max(1, Style.normalBorderWidth)
    radius: Style.cornerRadius
    z: 50

    ResponsivePanel {
      id: timerViewport
      anchors.fill: parent
      padding: root.companionMode ? 0 : Style.space(12)
      maximumContentWidth: Style.space(620)

      Column {
        id: pickerContent
        visible: root.setupOpen && !root.companionMode
        width: parent.width
        spacing: Style.spacing.controlGap

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Set timer"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.spacing.panelGap

          Column {
            spacing: Style.spacing.labelGap
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "HOURS"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Row {
              spacing: Style.spacing.controlGap
              Button {
                width: root.touchTarget
                height: root.touchTarget
                text: "−"
                bordered: true
                Accessible.role: Accessible.Button
                Accessible.name: "Decrease hours"
                onClicked: root.selectedHours = Math.max(0, root.selectedHours - 1)
              }
              Text {
                width: Style.space(54)
                height: root.touchTarget
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.selectedHours < 10 ? "0" + root.selectedHours : String(root.selectedHours)
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.display
                font.bold: true
              }
              Button {
                width: root.touchTarget
                height: root.touchTarget
                text: "+"
                bordered: true
                Accessible.role: Accessible.Button
                Accessible.name: "Increase hours"
                onClicked: root.selectedHours = Math.min(99, root.selectedHours + 1)
              }
            }
          }

          Column {
            spacing: Style.spacing.labelGap
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "MINUTES"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Row {
              spacing: Style.spacing.controlGap
              Button {
                width: root.touchTarget
                height: root.touchTarget
                text: "−"
                bordered: true
                Accessible.role: Accessible.Button
                Accessible.name: "Decrease minutes"
                onClicked: root.selectedMinutes = Math.max(0, root.selectedMinutes - 1)
              }
              Text {
                width: Style.space(54)
                height: root.touchTarget
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.selectedMinutes < 10 ? "0" + root.selectedMinutes : String(root.selectedMinutes)
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.display
                font.bold: true
              }
              Button {
                width: root.touchTarget
                height: root.touchTarget
                text: "+"
                bordered: true
                Accessible.role: Accessible.Button
                Accessible.name: "Increase minutes"
                onClicked: root.selectedMinutes = Math.min(59, root.selectedMinutes + 1)
              }
            }
          }
        }

        Grid {
          id: presetGrid
          width: parent.width
          columns: width < Style.space(400) ? 2 : 4
          spacing: Style.spacing.controlGap
          property real cellWidth: Math.max(root.touchTarget, (width - spacing * (columns - 1)) / columns)

          Button {
            width: presetGrid.cellWidth; height: root.touchTarget; text: "5 min"; bordered: true
            Accessible.role: Accessible.Button; Accessible.name: "Set 5 minutes"
            onClicked: root.setPreset(5)
          }
          Button {
            width: presetGrid.cellWidth; height: root.touchTarget; text: "15 min"; bordered: true
            Accessible.role: Accessible.Button; Accessible.name: "Set 15 minutes"
            onClicked: root.setPreset(15)
          }
          Button {
            width: presetGrid.cellWidth; height: root.touchTarget; text: "30 min"; bordered: true
            Accessible.role: Accessible.Button; Accessible.name: "Set 30 minutes"
            onClicked: root.setPreset(30)
          }
          Button {
            width: presetGrid.cellWidth; height: root.touchTarget; text: "60 min"; bordered: true
            Accessible.role: Accessible.Button; Accessible.name: "Set 60 minutes"
            onClicked: root.setPreset(60)
          }
        }

        Flow {
          id: soundSelector
          width: parent.width
          spacing: Style.spacing.controlGap

          Text {
            width: Style.space(52)
            height: root.touchTarget
            verticalAlignment: Text.AlignVCenter
            text: "Sound"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }
          Button {
            width: root.touchTarget
            height: root.touchTarget
            text: "‹"
            bordered: true
            Accessible.role: Accessible.Button
            Accessible.name: "Select previous timer sound"
            onClicked: root.timer.selectPreviousSound()
          }
          Text {
            width: Style.space(100)
            height: root.touchTarget
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: root.timer ? root.timer.selectedSoundName : "Complete"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
          }
          Button {
            width: root.touchTarget
            height: root.touchTarget
            text: "›"
            bordered: true
            Accessible.role: Accessible.Button
            Accessible.name: "Select next timer sound"
            onClicked: root.timer.selectNextSound()
          }
          Button {
            width: Style.space(88)
            height: root.touchTarget
            text: "Preview"
            bordered: true
            enabled: root.timer && root.timer.soundSettingsLoaded && root.timer.selectedSoundId !== ""
            opacity: enabled ? 1 : 0.4
            Accessible.role: Accessible.Button
            Accessible.name: "Preview timer sound"
            onClicked: root.timer.previewSelectedSound()
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.spacing.panelGap
          Button {
            width: Style.space(120)
            height: root.touchTarget
            text: "Cancel"
            bordered: true
            Accessible.role: Accessible.Button
            Accessible.name: "Cancel timer setup"
            onClicked: root.cancelSetup()
          }
          Button {
            width: Style.space(120)
            height: root.touchTarget
            text: "Start"
            selected: true
            enabled: root.selectedDurationValid
            opacity: enabled ? 1 : 0.4
            Accessible.role: Accessible.Button
            Accessible.name: "Start timer"
            onClicked: root.startSelectedTimer()
          }
        }
      }

      TimerSetupPanel {
        id: compactSetupContent
        visible: root.setupOpen && root.companionMode
        width: parent.width
        presenter: root
      }

      Column {
        id: controlsContent
        visible: root.companionMode ? root.timerStatus !== "idle" : root.controlsOpen
        width: parent.width
        spacing: Style.spacing.panelGap

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.timerStatus === "completed" ? "Time's up"
            : root.timerStatus === "paused" ? "Paused · " + root.timerRemainingText
            : root.timerRemainingText + " remaining"
          color: root.timerStatus === "completed" ? Color.accent : Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Grid {
          id: activeTimerGrid
          visible: root.timerStatus === "active" || root.timerStatus === "paused"
          width: parent.width
          columns: width < Style.space(500) ? 2 : 4
          spacing: Style.spacing.controlGap
          property real cellWidth: Math.max(root.touchTarget, (width - spacing * (columns - 1)) / columns)

          Button {
            visible: root.timerStatus === "active"
            width: activeTimerGrid.cellWidth; height: root.touchTarget; text: "Pause"; bordered: true
            Accessible.role: Accessible.Button; Accessible.name: "Pause timer"
            onClicked: root.timer.pause()
          }
          Button {
            visible: root.timerStatus === "paused"
            width: activeTimerGrid.cellWidth; height: root.touchTarget; text: "Resume"; selected: true
            Accessible.role: Accessible.Button; Accessible.name: "Resume timer"
            onClicked: root.timer.resume()
          }
          Button {
            width: activeTimerGrid.cellWidth; height: root.touchTarget; text: "+5 min"; bordered: true
            Accessible.role: Accessible.Button; Accessible.name: "Add 5 minutes"
            onClicked: root.timer.add(5)
          }
          Button {
            width: activeTimerGrid.cellWidth; height: root.touchTarget; text: "Restart"; bordered: true
            Accessible.role: Accessible.Button; Accessible.name: "Restart timer"
            onClicked: root.timer.restart()
          }
          Button {
            width: activeTimerGrid.cellWidth; height: root.touchTarget; text: "Cancel"; bordered: true
            Accessible.role: Accessible.Button; Accessible.name: "Cancel timer"
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
