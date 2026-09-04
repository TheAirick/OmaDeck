import QtQuick
import qs.Commons
import qs.Ui
import "../components"

Item {
  id: root

  required property var presenter
  readonly property int touchTarget: 48
  readonly property real naturalAdjustWidth: touchTarget * 2
    + durationSelector.implicitWidth + Style.spacing.controlGap * 2
  readonly property real naturalActionWidth: touchTarget * 3 + Style.spacing.controlGap * 2
  readonly property bool oneRow: presenter.height < Style.space(95)
    && width >= naturalAdjustWidth + naturalActionWidth + Style.spacing.controlGap

  implicitHeight: Math.max(adjustRow.y + adjustRow.height,
    actionRow.y + actionRow.height)
  height: implicitHeight

  function commitFields() {
    hoursField.commit()
    minutesField.commit()
    secondsField.commit()
  }

  Row {
    id: adjustRow
    objectName: "timerDurationActions"
    x: root.oneRow
      ? (root.width - root.naturalAdjustWidth - root.naturalActionWidth
         - Style.spacing.controlGap) / 2
      : (root.width - implicitWidth) / 2
    spacing: Style.spacing.controlGap

    TimerStepButton {
      width: root.touchTarget
      height: root.touchTarget
      text: "−"
      accessibleName: "Subtract one " + root.presenter.selectedSegment.slice(0, -1)
      onClicked: {
        root.commitFields()
        root.presenter.adjustSelectedPart(-1)
      }
    }

    Row {
      id: durationSelector
      objectName: "timerDurationSelector"
      spacing: Math.max(2, Style.spacing.labelGap / 2)

      TimerDurationField {
        id: hoursField
        objectName: "timerHoursField"
        value: root.presenter.selectedHours
        maximum: 99
        segment: "hours"
        accessibleName: "Hours"
        selected: root.presenter.selectedSegment === segment
        onChosen: root.presenter.selectedSegment = segment
        onEdited: function(value) { root.presenter.setSelectedPart(segment, value) }
      }

      Text {
        height: root.touchTarget
        text: ":"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
        verticalAlignment: Text.AlignVCenter
      }

      TimerDurationField {
        id: minutesField
        objectName: "timerMinutesField"
        value: root.presenter.selectedMinutes
        maximum: 59
        segment: "minutes"
        accessibleName: "Minutes"
        selected: root.presenter.selectedSegment === segment
        onChosen: root.presenter.selectedSegment = segment
        onEdited: function(value) { root.presenter.setSelectedPart(segment, value) }
      }

      Text {
        height: root.touchTarget
        text: ":"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
        verticalAlignment: Text.AlignVCenter
      }

      TimerDurationField {
        id: secondsField
        objectName: "timerSecondsField"
        value: root.presenter.selectedSeconds
        maximum: 59
        segment: "seconds"
        accessibleName: "Seconds"
        selected: root.presenter.selectedSegment === segment
        onChosen: root.presenter.selectedSegment = segment
        onEdited: function(value) { root.presenter.setSelectedPart(segment, value) }
      }
    }

    TimerStepButton {
      width: root.touchTarget
      height: root.touchTarget
      text: "+"
      accessibleName: "Add one " + root.presenter.selectedSegment.slice(0, -1)
      onClicked: {
        root.commitFields()
        root.presenter.adjustSelectedPart(1)
      }
    }
  }

  Row {
    id: actionRow
    objectName: "timerSetupActions"
    x: root.oneRow ? adjustRow.x + adjustRow.implicitWidth
      + Style.spacing.controlGap : (root.width - width) / 2
    y: root.oneRow ? 0 : adjustRow.height + Style.spacing.controlGap
    width: root.oneRow ? root.naturalActionWidth
      : Math.min(parent.width, Style.space(360))
    spacing: Style.spacing.controlGap
    readonly property real cellWidth: Math.max(root.touchTarget,
      (width - spacing * 2) / 3)

    Button {
      width: actionRow.cellWidth
      height: root.touchTarget
      iconText: "󰎆"
      bordered: true
      iconSize: Style.font.title
      enabled: root.presenter.timer && root.presenter.timer.soundSettingsLoaded
      opacity: enabled ? 1 : 0.4
      Accessible.role: Accessible.Button
      Accessible.name: "Choose next timer sound"
      onClicked: root.presenter.timer.selectNextSound()
    }
    Button {
      width: actionRow.cellWidth
      height: root.touchTarget
      text: "Cancel"
      bordered: true
      Accessible.role: Accessible.Button
      Accessible.name: "Cancel timer setup"
      onClicked: root.presenter.cancelSetup()
    }
    Button {
      width: actionRow.cellWidth
      height: root.touchTarget
      text: "Start"
      selected: true
      enabled: root.presenter.selectedDurationValid
      opacity: enabled ? 1 : 0.4
      Accessible.role: Accessible.Button
      Accessible.name: "Start timer"
      onClicked: {
        root.commitFields()
        root.presenter.startSelectedTimer()
      }
    }
  }
}
