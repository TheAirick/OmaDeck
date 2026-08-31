import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  required property var presenter
  readonly property int touchTarget: 48
  readonly property bool wideLayout: width >= Style.space(520)
  readonly property real rowGap: Style.spacing.controlGap

  implicitHeight: soundActions.y + soundActions.implicitHeight
  height: implicitHeight

  Row {
    id: durationRow
    x: root.wideLayout ? 0 : Math.max(0, (parent.width - implicitWidth) / 2)
    y: 0
    spacing: Style.spacing.labelGap

    Row {
      spacing: Style.spacing.labelGap
      Button {
        width: root.touchTarget; height: root.touchTarget; text: "−"; bordered: true
        Accessible.role: Accessible.Button; Accessible.name: "Decrease hours"
        onClicked: root.presenter.selectedHours = Math.max(0, root.presenter.selectedHours - 1)
      }
      Text {
        width: Style.space(42); height: root.touchTarget
        verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
        text: (root.presenter.selectedHours < 10 ? "0" : "") + root.presenter.selectedHours + "h"
        color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
      }
      Button {
        width: root.touchTarget; height: root.touchTarget; text: "+"; bordered: true
        Accessible.role: Accessible.Button; Accessible.name: "Increase hours"
        onClicked: root.presenter.selectedHours = Math.min(99, root.presenter.selectedHours + 1)
      }
    }

    Row {
      spacing: Style.spacing.labelGap
      Button {
        width: root.touchTarget; height: root.touchTarget; text: "−"; bordered: true
        Accessible.role: Accessible.Button; Accessible.name: "Decrease minutes"
        onClicked: root.presenter.selectedMinutes = Math.max(0, root.presenter.selectedMinutes - 1)
      }
      Text {
        width: Style.space(42); height: root.touchTarget
        verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
        text: (root.presenter.selectedMinutes < 10 ? "0" : "") + root.presenter.selectedMinutes + "m"
        color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
      }
      Button {
        width: root.touchTarget; height: root.touchTarget; text: "+"; bordered: true
        Accessible.role: Accessible.Button; Accessible.name: "Increase minutes"
        onClicked: root.presenter.selectedMinutes = Math.min(59, root.presenter.selectedMinutes + 1)
      }
    }
  }

  Row {
    id: presetRow
    x: root.wideLayout ? durationRow.implicitWidth + root.rowGap : 0
    y: root.wideLayout ? 0 : root.touchTarget + root.rowGap
    width: Math.max(0, parent.width - x)
    spacing: root.rowGap
    readonly property real buttonWidth: Math.max(root.touchTarget,
      (width - spacing * 3) / 4)

    Button {
      width: presetRow.buttonWidth; height: root.touchTarget; text: "5m"; bordered: true
      Accessible.role: Accessible.Button; Accessible.name: "Set 5 minutes"
      onClicked: root.presenter.setPreset(5)
    }
    Button {
      width: presetRow.buttonWidth; height: root.touchTarget; text: "15m"; bordered: true
      Accessible.role: Accessible.Button; Accessible.name: "Set 15 minutes"
      onClicked: root.presenter.setPreset(15)
    }
    Button {
      width: presetRow.buttonWidth; height: root.touchTarget; text: "30m"; bordered: true
      Accessible.role: Accessible.Button; Accessible.name: "Set 30 minutes"
      onClicked: root.presenter.setPreset(30)
    }
    Button {
      width: presetRow.buttonWidth; height: root.touchTarget; text: "60m"; bordered: true
      Accessible.role: Accessible.Button; Accessible.name: "Set 60 minutes"
      onClicked: root.presenter.setPreset(60)
    }
  }

  Flow {
    id: soundActions
    x: width >= Style.space(365) ? (parent.width - width) / 2 : 0
    y: root.wideLayout ? root.touchTarget + root.rowGap
      : root.touchTarget * 2 + root.rowGap * 2
    width: Math.min(parent.width, Style.space(365))
    spacing: Style.spacing.labelGap

    Button {
      width: root.touchTarget; height: root.touchTarget; text: "‹"; bordered: true
      Accessible.role: Accessible.Button; Accessible.name: "Select previous timer sound"
      onClicked: root.presenter.timer.selectPreviousSound()
    }
    Text {
      width: Style.space(52); height: root.touchTarget
      verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
      text: root.presenter.timer ? root.presenter.timer.selectedSoundName : "Complete"
      color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
    Button {
      width: root.touchTarget; height: root.touchTarget; text: "›"; bordered: true
      Accessible.role: Accessible.Button; Accessible.name: "Select next timer sound"
      onClicked: root.presenter.timer.selectNextSound()
    }
    Button {
      width: Style.space(64); height: root.touchTarget; text: "Preview"; bordered: true
      enabled: root.presenter.timer && root.presenter.timer.soundSettingsLoaded
        && root.presenter.timer.selectedSoundId !== ""
      Accessible.role: Accessible.Button; Accessible.name: "Preview timer sound"
      onClicked: root.presenter.timer.previewSelectedSound()
    }
    Button {
      width: Style.space(64); height: root.touchTarget; text: "Cancel"; bordered: true
      Accessible.role: Accessible.Button; Accessible.name: "Cancel timer setup"
      onClicked: root.presenter.cancelSetup()
    }
    Button {
      width: Style.space(64); height: root.touchTarget; text: "Start"; selected: true
      enabled: root.presenter.selectedDurationValid
      Accessible.role: Accessible.Button; Accessible.name: "Start timer"
      onClicked: root.presenter.startSelectedTimer()
    }
  }
}
