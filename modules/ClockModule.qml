import QtQuick
import Quickshell
import qs.Commons
import "../components"

Item {
  id: root

  property var controller: null
  property var weather: null
  property date now: new Date()
  property bool editing: false

  readonly property string clockStyle: controller ? controller.clockStyle : "hero"
  readonly property bool use24Hour: controller ? controller.use24Hour : false
  readonly property bool showSeconds: controller ? controller.showSeconds : false
  readonly property bool showWeather: controller ? controller.showWeather : true
  readonly property string weatherStyle: controller ? controller.weatherStyle : "scene"
  readonly property string weatherDetail: controller ? controller.weatherDetail : "standard"
  readonly property string temperatureUnit: controller ? controller.temperatureUnit : "fahrenheit"

  function timeText() {
    var pattern = use24Hour ? (showSeconds ? "HH:mm:ss" : "HH:mm") : (showSeconds ? "h:mm:ss AP" : "h:mm AP")
    return Qt.formatDateTime(now, pattern)
  }

  function setOption(key, value) {
    if (controller) controller.setOption(key, value)
  }

  function openLocationSettings() {
    Quickshell.execDetached(["omarchy-shell", "omarchy.weather", "edit"])
  }

  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

  Loader {
    anchors.fill: parent
    visible: !root.editing
    sourceComponent: root.clockStyle === "split" ? splitClock : root.clockStyle === "compact" ? compactClock : heroClock
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
            text: Qt.formatDateTime(root.now, "dddd, MMMM d")
            color: Color.muted
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
          text: Qt.formatDateTime(root.now, "ddd, MMM d")
          color: Color.muted
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
          text: Qt.formatDateTime(root.now, "ddd, MMM d")
          color: Color.muted
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

  Rectangle {
    anchors.fill: parent
    visible: root.editing
    color: Color.popups.background
    radius: Style.cornerRadius

    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: settingsColumn.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      clip: true

      Column {
        id: settingsColumn
        width: parent.width
        spacing: Style.spacing.controlGap

      Row {
        width: parent.width
        height: Style.space(36)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Clock & weather"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
        Text {
          width: parent.width - x
          anchors.verticalCenter: parent.verticalCenter
          text: root.weather && root.weather.current.ok ? root.weather.current.location : "Uses Omarchy weather location"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideRight
        }
      }

      SettingRow {
        label: "Clock"
        options: [{label:"Hero", value:"hero"}, {label:"Split", value:"split"}, {label:"Compact", value:"compact"}]
        selectedValue: root.clockStyle
        onChosen: function(value) { root.setOption("clockStyle", value) }
      }
      SettingRow {
        label: "Time"
        options: [{label:"12 hour", value:"12"}, {label:"24 hour", value:"24"}]
        selectedValue: root.use24Hour ? "24" : "12"
        onChosen: function(value) { root.setOption("use24Hour", value === "24") }
      }
      SettingRow {
        label: "Seconds"
        options: [{label:"Hidden", value:"hidden"}, {label:"Shown", value:"shown"}]
        selectedValue: root.showSeconds ? "shown" : "hidden"
        onChosen: function(value) { root.setOption("showSeconds", value === "shown") }
      }
      SettingRow {
        label: "Weather"
        options: [{label:"Shown", value:"shown"}, {label:"Hidden", value:"hidden"}, {label:"Refresh", value:"refresh"}]
        selectedValue: root.showWeather ? "shown" : "hidden"
        onChosen: function(value) {
          if (value === "refresh") { if (root.weather) root.weather.refresh() }
          else root.setOption("showWeather", value === "shown")
        }
      }
      SettingRow {
        label: "Visual"
        enabled: root.showWeather
        options: [{label:"Rich", value:"scene"}, {label:"Glyph", value:"glyph"}, {label:"Minimal", value:"minimal"}]
        selectedValue: root.weatherStyle
        onChosen: function(value) { root.setOption("weatherStyle", value) }
      }
      SettingRow {
        label: "Details"
        enabled: root.showWeather
        options: [{label:"Compact", value:"compact"}, {label:"Standard", value:"standard"}, {label:"Full", value:"full"}]
        selectedValue: root.weatherDetail
        onChosen: function(value) { root.setOption("weatherDetail", value) }
      }
      SettingRow {
        label: "Units"
        enabled: root.showWeather
        options: [{label:"Fahrenheit", value:"fahrenheit"}, {label:"Celsius", value:"celsius"}]
        selectedValue: root.temperatureUnit
        onChosen: function(value) { root.setOption("temperatureUnit", value) }
      }
        SettingRow {
          label: "Location"
          enabled: root.showWeather
          options: [{label:"Set in Omarchy", value:"edit"}]
          selectedValue: ""
          onChosen: function(value) { root.openLocationSettings() }
        }
      }
    }
  }

  Rectangle {
    id: settingsButton
    anchors.top: parent.top
    anchors.right: parent.right
    width: Style.space(42)
    height: width
    radius: width / 2
    color: settingsTap.pressed ? Style.pressedFill : (settingsHover.hovered || root.editing ? Style.hoverFill : Style.normalFill)
    border.width: root.editing ? 1 : 0
    border.color: Color.accent
    z: 20
    Text {
      anchors.centerIn: parent
      text: root.editing ? "󰅖" : "󰒓"
      color: root.editing ? Color.accent : Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    HoverHandler { id: settingsHover }
    TapHandler { id: settingsTap; onTapped: root.editing = !root.editing }
  }

  component SettingRow: Item {
    id: settingRow
    required property string label
    required property var options
    required property string selectedValue
    signal chosen(string value)

    width: parent ? parent.width : 0
    height: Style.space(43)
    opacity: enabled ? 1 : 0.4

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(Style.space(86), parent.width * 0.22)
      text: settingRow.label
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Row {
      anchors.left: parent.left
      anchors.leftMargin: Math.min(Style.space(92), parent.width * 0.24)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.labelGap

      Repeater {
        model: settingRow.options
        Rectangle {
          required property var modelData
          width: (parent.width - (settingRow.options.length - 1) * parent.spacing) / settingRow.options.length
          height: Style.space(37)
          radius: Style.cornerRadius
          color: modelData.value === settingRow.selectedValue ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
            : choiceTap.pressed ? Style.pressedFill : (choiceHover.hovered ? Style.hoverFill : Style.normalFill)
          border.width: modelData.value === settingRow.selectedValue ? 1 : 0
          border.color: Color.accent
          Text {
            anchors.centerIn: parent
            text: modelData.label
            color: modelData.value === settingRow.selectedValue ? Color.accent : Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: modelData.value === settingRow.selectedValue
          }
          HoverHandler { id: choiceHover; enabled: settingRow.enabled }
          TapHandler { id: choiceTap; enabled: settingRow.enabled; onTapped: settingRow.chosen(String(modelData.value)) }
        }
      }
    }
  }
}
