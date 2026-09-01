import QtQuick
import qs.Commons
import "../modules"

Item {
  id: root

  property var controller: null
  property var weather: null
  property var timer: null
  property bool interactionEnabled: true
  property bool active: false

  readonly property int panelGap: Style.spacing.panelGap
  readonly property real splitHeight: Math.max(0, height - panelGap)
  readonly property real clockShare: root.occupant === "weather" ? 0.48 : 0.37
  readonly property real clockHeight: Math.round(splitHeight * clockShare)
  readonly property real companionHeight: Math.max(0, splitHeight - clockHeight)
  readonly property string occupant: companionModule.occupant

  clip: true

  DeckCard {
    id: clockCard
    objectName: "clockPanelCard"
    width: parent.width
    height: root.clockHeight
    title: "Clock"
    subtitle: "DP-3 · edge workspace"
    padding: Style.spacing.panelPadding
    active: root.active

    ClockModule {
      anchors.fill: parent
      controller: root.controller
      timer: root.timer
      interactionEnabled: root.interactionEnabled && !companionModule.timerSetupOpen
      onSetupRequested: companionModule.openSetup()
    }
  }

  DeckCard {
    id: companionCard
    objectName: "companionPanelCard"
    y: root.clockHeight + root.panelGap
    width: parent.width
    height: root.companionHeight
    title: root.occupant === "timer" ? "Timer" : "Weather"
    padding: root.occupant === "timer" ? Style.spacing.labelGap : Style.spacing.panelPadding
    active: root.active

    ClockCompanionModule {
      id: companionModule
      anchors.fill: parent
      controller: root.controller
      weather: root.weather
      timer: root.timer
    }
  }
}
