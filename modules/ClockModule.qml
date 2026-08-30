import QtQuick
import qs.Commons
import qs.Ui
import "../components"

Item {
  id: root

  clip: true

  property var controller: null
  property var weather: null
  property var timer: null
  property bool interactionEnabled: true
  property date now: new Date()
  property bool pickerOpen: false
  property bool controlsOpen: false
  property int selectedHours: 0
  property int selectedMinutes: 5

  readonly property string clockStyle: controller ? controller.clockStyle : "hero"
  readonly property bool use24Hour: controller ? controller.use24Hour : false
  readonly property bool showSeconds: controller ? controller.showSeconds : false
  readonly property bool showWeather: controller ? controller.showWeather : true
  readonly property string weatherStyle: controller ? controller.weatherStyle : "scene"
  readonly property string weatherDetail: controller ? controller.weatherDetail : "standard"
  readonly property string temperatureUnit: controller ? controller.temperatureUnit : "fahrenheit"
  readonly property string timerStatus: timer ? timer.status : "idle"
  readonly property string timerRemainingText: timer ? timer.remainingText : "0:00"
  readonly property real timerProgress: timer ? timer.progress : 0
  readonly property bool selectedDurationValid: selectedHours >= 0 && selectedHours <= 99
    && selectedMinutes >= 0 && selectedMinutes <= 59
    && (selectedHours > 0 || selectedMinutes > 0)
  readonly property int touchTarget: 48

  function timeText() {
    var pattern = use24Hour ? (showSeconds ? "HH:mm:ss" : "HH:mm") : (showSeconds ? "h:mm:ss AP" : "h:mm AP")
    return Qt.formatDateTime(now, pattern)
  }

  function secondaryText(datePattern) {
    if (timerStatus === "paused") return "Paused · " + timerRemainingText
    if (timerStatus === "completed") return "● Time's up"
    if (timerStatus === "active") return "● " + timerRemainingText
    return Qt.formatDateTime(now, datePattern)
  }

  function openTimerControls() {
    if (!interactionEnabled || !timer || !timer.loaded) return
    if (timerStatus === "idle") pickerOpen = true
    else controlsOpen = true
  }

  function closeTimerControls() {
    pickerOpen = false
    controlsOpen = false
  }

  function setPreset(minutes) {
    selectedHours = Math.floor(minutes / 60)
    selectedMinutes = minutes % 60
  }

  function startSelectedTimer() {
    if (!selectedDurationValid || !timer) return
    var response = timer.start(selectedHours, selectedMinutes)
    if (response && response.ok) closeTimerControls()
  }

  onTimerStatusChanged: {
    if (pickerOpen && timerStatus !== "idle") pickerOpen = false
    if (controlsOpen && (timerStatus === "idle" || timerStatus === "completed")) controlsOpen = false
  }

  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

  Loader {
    anchors.fill: parent
    sourceComponent: root.clockStyle === "split" ? splitClock : root.clockStyle === "compact" ? compactClock : heroClock
  }

  TapHandler {
    enabled: root.interactionEnabled && !root.pickerOpen && !root.controlsOpen
    onTapped: root.openTimerControls()
  }

  Rectangle {
    id: timerProgressRail
    visible: root.timerStatus === "active" || root.timerStatus === "paused"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 4
    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
    z: 20

    Rectangle {
      height: parent.height
      width: parent.width * root.timerProgress
      color: Color.accent
      opacity: root.timerStatus === "paused" ? 0.62 : 0.9

      Behavior on width {
        NumberAnimation { duration: 100; easing.type: Easing.Linear }
      }
    }
  }

  Rectangle {
    id: timerOverlay
    visible: root.pickerOpen || root.controlsOpen
    anchors.fill: parent
    color: Color.background
    border.color: Color.accent
    border.width: Math.max(1, Style.normalBorderWidth)
    radius: Style.cornerRadius
    z: 50

    ResponsivePanel {
      id: timerViewport
      anchors.fill: parent
      padding: Style.space(12)
      maximumContentWidth: Style.space(620)

    Column {
      id: pickerContent
      visible: root.pickerOpen
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
          onClicked: root.closeTimerControls()
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

    Column {
      id: controlsContent
      visible: root.controlsOpen
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

      Button {
        visible: root.timerStatus !== "completed"
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(140)
        height: root.touchTarget
        text: "Close"
        bordered: true
        Accessible.role: Accessible.Button
        Accessible.name: "Close timer controls"
        onClicked: root.closeTimerControls()
      }
    }
    }
  }

  Component {
    id: heroClock
    Column {
      anchors.fill: parent
      spacing: Style.spacing.controlGap

      Item {
        width: parent.width
        height: root.showWeather ? Math.max(90, parent.height * 0.48) : parent.height
        Column {
          anchors.centerIn: parent
          spacing: Style.spacing.labelGap
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeText()
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Math.min(root.width * 0.17, root.height * 0.30)
            font.weight: Font.DemiBold
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.secondaryText("dddd, MMMM d")
            color: root.timerStatus !== "idle" ? Color.accent : Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }
      }

      WeatherVisual {
        visible: root.showWeather
        width: parent.width
        height: Math.max(0, parent.height - y)
        weather: root.weather ? root.weather.current : null
        loading: root.weather ? root.weather.loading : false
        error: root.weather ? root.weather.error : ""
        visualStyle: root.weatherStyle
        detailMode: root.weatherDetail
        temperatureUnit: root.temperatureUnit
      }
    }
  }

  Component {
    id: splitClock
    Row {
      anchors.fill: parent
      spacing: Style.spacing.panelGap

      Column {
        width: root.showWeather ? Math.max(160, parent.width * 0.43) : parent.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.labelGap
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.timeText()
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Math.min(parent.width * 0.26, root.height * 0.24)
          font.weight: Font.DemiBold
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.secondaryText("ddd, MMM d")
          color: root.timerStatus !== "idle" ? Color.accent : Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      WeatherVisual {
        visible: root.showWeather
        width: Math.max(0, parent.width - x)
        height: parent.height
        weather: root.weather ? root.weather.current : null
        loading: root.weather ? root.weather.loading : false
        error: root.weather ? root.weather.error : ""
        visualStyle: root.weatherStyle
        detailMode: root.weatherDetail
        temperatureUnit: root.temperatureUnit
      }
    }
  }

  Component {
    id: compactClock
    Column {
      anchors.centerIn: parent
      width: parent.width
      spacing: Style.spacing.controlGap

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        height: Math.max(56, Style.space(56))
        spacing: Style.spacing.panelGap
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.timeText()
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Math.min(root.width * 0.13, Style.font.displayLarge * 1.35)
          font.weight: Font.DemiBold
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.secondaryText("ddd, MMM d")
          color: root.timerStatus !== "idle" ? Color.accent : Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      WeatherVisual {
        visible: root.showWeather
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, Style.space(430))
        height: Math.max(64, Style.space(70))
        weather: root.weather ? root.weather.current : null
        loading: root.weather ? root.weather.loading : false
        error: root.weather ? root.weather.error : ""
        visualStyle: root.weatherStyle === "scene" ? "minimal" : root.weatherStyle
        detailMode: root.weatherDetail
        temperatureUnit: root.temperatureUnit
      }
    }
  }

}
