import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../modules"
import "../theme"

Item {
  id: root
  property var deck: null
  property var shell: null
  property var launcherController: null
  property string primaryMonitor: "DP-1"
  property real canvasX: 0
  property real canvasY: 0
  property var watch: null
  property var appearanceController: null
  property var weatherController: null
  property var timerController: null
  readonly property bool focused: !!(watch && watch.focused)
  property var videoRect: watch ? watch.videoRect : null
  readonly property real videoWidth: videoRect ? videoRect.width : 0
  readonly property real videoHeight: videoRect ? videoRect.height : 0
  readonly property real companionWidth: Math.min(Style.space(340), Math.max(0, width - videoWidth - gap * 2) * 0.42)
  readonly property real gap: Style.spacing.panelGap

  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0) return "0:00"
    var whole = Math.floor(seconds)
    var hours = Math.floor(whole / 3600)
    var minutes = Math.floor((whole % 3600) / 60)
    var remainder = String(whole % 60).padStart(2, "0")
    return hours ? hours + ":" + String(minutes).padStart(2, "0") + ":" + remainder
      : minutes + ":" + remainder
  }

  property bool controlsVisible: true
  function revealControls() { controlsVisible = true; hideControls.restart() }
  Timer {
    id: hideControls
    interval: 4000
    running: root.controlsVisible && root.watch && root.watch.videoPlaying
    onTriggered: if (!overlayHover.hovered) root.controlsVisible = false; else restart()
  }

  Item {
    id: videoBacking
    objectName: "watchVideoRegion"
    x: root.videoRect ? root.videoRect.left - root.canvasX : 0
    width: root.videoWidth
    height: root.videoHeight
    y: root.videoRect ? root.videoRect.top - root.canvasY : 0

    MouseArea {
      anchors.fill: parent
      onClicked: root.controlsVisible ? root.controlsVisible = false : root.revealControls()
    }

    Rectangle {
      anchors.fill: parent
      visible: root.watch && (root.watch.state === "launching" || root.watch.state === "loading")
      color: "black"
      Text {
        anchors.centerIn: parent
        text: "Opening video…"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }

    Item {
      id: watchControls
      objectName: "watchControls"
      anchors.fill: parent
      visible: root.controlsVisible || !root.watch || !root.watch.videoPlaying
      HoverHandler { id: overlayHover }

      Button {
        objectName: "watchClose"
        anchors.top: parent.top; anchors.right: parent.right
        anchors.margins: Style.spacing.controlGap
        width: Style.space(44); height: Style.space(44)
        Accessible.name: "Close video"
        tooltipText: "Close video"
        iconText: "󰅖"
        iconSize: Style.space(22)
        foreground: Color.foreground
        background: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.88)
        bordered: false; borderSpec: Border.none()
        enabled: root.watch && root.watch.active
        onClicked: root.watch.abort()
      }

      Rectangle {
        objectName: "watchControlBar"
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: Style.spacing.controlGap
        height: Style.space(56)
        color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.88)
        radius: Style.cornerRadius

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.spacing.labelGap
          anchors.rightMargin: Style.spacing.labelGap
          spacing: Style.spacing.labelGap

          Button {
            objectName: "watchSeekBack"
            Accessible.name: "Back 10 seconds"
            text: "−10"
            foreground: Color.accent
            background: "transparent"; bordered: false; borderSpec: Border.none()
            Layout.preferredWidth: Style.space(44); Layout.preferredHeight: Style.space(44)
            enabled: root.watch && root.watch.state === "playing"
            onClicked: { root.revealControls(); root.watch.seekBy(-10) }
          }
          Button {
            objectName: "watchTogglePlayback"
            Accessible.name: root.watch && root.watch.videoPlaying ? "Pause video" : "Play video"
            iconText: root.watch && root.watch.videoPlaying ? "󰏤" : "󰐊"
            foreground: Color.accent
            background: "transparent"; bordered: false; borderSpec: Border.none()
            iconSize: Style.space(24)
            Layout.preferredWidth: Style.space(44); Layout.preferredHeight: Style.space(44)
            enabled: root.watch && root.watch.state === "playing"
            onClicked: { root.revealControls(); root.watch.togglePlayback() }
          }
          Button {
            objectName: "watchSeekForward"
            Accessible.name: "Forward 10 seconds"
            text: "+10"
            foreground: Color.accent
            background: "transparent"; bordered: false; borderSpec: Border.none()
            Layout.preferredWidth: Style.space(44); Layout.preferredHeight: Style.space(44)
            enabled: root.watch && root.watch.state === "playing"
            onClicked: { root.revealControls(); root.watch.seekBy(10) }
          }
          Text {
            text: root.watch ? root.formatTime(root.watch.videoPosition) : "0:00"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          PanelSlider {
            objectName: "watchTimeline"
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(44)
            minimum: 0
            maximum: root.watch ? Math.max(1, root.watch.videoDuration) : 1
            value: root.watch ? root.watch.videoPosition : 0
            enabled: root.watch && root.watch.state === "playing" && root.watch.videoDuration > 0
            fillColor: Color.accent; knobColor: Color.accent
            onReleased: value => { root.revealControls(); root.watch.seekTo(value) }
          }
          Text {
            text: root.watch ? root.formatTime(root.watch.videoDuration) : "0:00"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          Button {
            objectName: "watchCaptions"
            Accessible.name: root.watch && root.watch.captionsEnabled ? "Turn captions off" : "Turn captions on"
            Layout.preferredWidth: Style.space(44); Layout.preferredHeight: Style.space(44)
            text: "CC"
            selected: root.watch && root.watch.captionsEnabled
            background: "transparent"; bordered: false; borderSpec: Border.none()
            foreground: root.watch && root.watch.captionsEnabled ? Color.accent : Color.foreground
            enabled: root.watch && root.watch.state === "playing" && root.watch.captionsAvailable
            onClicked: { root.revealControls(); root.watch.toggleCaptions() }
          }
          Button {
            objectName: "watchFocus"
            Accessible.name: root.focused ? "Exit focused video" : "Focus video"
            tooltipText: root.focused ? "Show dashboard" : "Focus video"
            iconText: root.focused ? "󰊔" : "󰊓"
            iconSize: Style.space(22)
            Layout.preferredWidth: Style.space(44); Layout.preferredHeight: Style.space(44)
            background: "transparent"; bordered: false; borderSpec: Border.none()
            foreground: Color.accent
            enabled: root.deck && root.watch && root.watch.state === "playing"
            onClicked: { root.revealControls(); root.deck.toggleWatchFocus() }
          }
          Button {
            objectName: "watchReturn"
            Accessible.name: root.watch && root.watch.sourceClosed ? "Close video" : "Return video to browser"
            tooltipText: root.watch && root.watch.sourceClosed ? "Original tab closed" : "Return to browser at this position"
            text: root.watch && root.watch.sourceClosed ? "Close" : "Return"
            Layout.preferredWidth: Style.space(72); Layout.preferredHeight: Style.space(44)
            background: "transparent"; bordered: false; borderSpec: Border.none()
            foreground: Color.accent
            enabled: root.watch && root.watch.state === "playing"
            onClicked: { root.revealControls(); root.watch.returnToSource() }
          }
        }
      }
      Text {
        anchors.top: parent.top; anchors.left: parent.left
        anchors.margins: Style.spacing.panelPadding
        width: Math.max(0, parent.width - Style.space(220))
        text: root.watch ? root.watch.notice : ""
        visible: text !== ""
        color: Color.foreground
        style: Text.Outline; styleColor: "black"
        font.family: Style.font.family; font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
      }
    }
  }

  BorderSurface {
    objectName: "watchVideoBorder"
    x: videoBacking.x
    y: videoBacking.y
    width: videoBacking.width
    height: videoBacking.height
    visible: !root.focused
    enabled: false
    color: "transparent"
    radius: Style.cornerRadius
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
  }

  DeckCard {
    objectName: "watchCommandCenterCard"
    visible: !root.focused
    x: root.videoWidth + root.companionWidth + root.gap * 2
    width: Math.max(0, root.width - x)
    height: parent.height
    title: "Command center"
    CommandCenterModule {
      anchors.fill: parent
      deck: root.deck
      shell: root.shell
      launcherController: root.launcherController
      pluginDir: root.deck ? root.deck.pluginDir : ""
      primaryMonitor: root.primaryMonitor
    }
  }

  Column {
    visible: !root.focused
    x: root.videoWidth + root.gap
    width: root.companionWidth
    height: parent.height
    spacing: root.gap

    DeckCard {
      objectName: "watchClockCard"
      width: parent.width
      height: (parent.height - parent.spacing) * 0.43
      title: "Clock"
      ClockModule {
        anchors.fill: parent
        controller: root.appearanceController
        timer: root.timerController
        interactionEnabled: false
      }
    }
    DeckCard {
      objectName: "watchWeatherCard"
      width: parent.width
      height: (parent.height - parent.spacing) * 0.57
      title: "Weather"
      WeatherModule {
        anchors.fill: parent
        weatherController: root.weatherController
        visualStyle: root.appearanceController ? root.appearanceController.weatherStyle : "scene"
        temperatureUnit: root.appearanceController ? root.appearanceController.temperatureUnit : "fahrenheit"
      }
    }
  }
}
