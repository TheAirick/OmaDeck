import QtQuick

Item {
  id: root

  property var controller: null
  property var weather: null
  property var timer: null
  property bool interactionEnabled: true

  clip: true

  ClockCompanionModule {
    anchors.fill: parent
    controller: root.controller
    weather: root.weather
    timer: root.timer
    interactionEnabled: root.interactionEnabled
  }
}
