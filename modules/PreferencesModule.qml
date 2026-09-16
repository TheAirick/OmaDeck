import QtQuick
import qs.Commons
import "../theme"
import qs.Ui
import "../components"

Item {
  id: root
  objectName: "preferencesPresenter"

  property var deck: null
  property var appearanceController: null
  property var layoutController: null
  property var hardwareController: null
  property var monitorInputController: null
  property var weatherController: null
  property var timerController: null
  property string selectedCategory: "omadeck"
  property string notice: ""
  readonly property bool keyboardRequested: launcherPreferences.typing
  function browseLauncherApps() { selectedCategory = "launcher"; launcherPreferences.browseApps() }

  readonly property var screenOptions: {
    var names = hardwareController && hardwareController.availableScreenNames
      && typeof hardwareController.availableScreenNames.length === "number"
      ? hardwareController.availableScreenNames : []
    var options = []
    for (var index = 0; index < names.length; index++)
      options.push({ value: String(names[index]), label: String(names[index]) })
    return options
  }
  readonly property var touchOptions: {
    var names = hardwareController && hardwareController.availableTouchDeviceNames
      && typeof hardwareController.availableTouchDeviceNames.length === "number"
      ? hardwareController.availableTouchDeviceNames : []
    var options = []
    for (var index = 0; index < names.length; index++)
      options.push({ value: String(names[index]), label: String(names[index]) })
    return options
  }

  readonly property var timerSoundOptions: {
    var sounds = timerController && timerController.soundOptions ? timerController.soundOptions : []
    var options = []
    for (var index = 0; index < sounds.length; index++)
      options.push({ value: sounds[index].eventId, label: sounds[index].label })
    return options
  }

  readonly property var categories: [
    { id: "omadeck", label: "Dashboard", icon: "󰇄", description: "Layout, clock, and weather" },
    { id: "workspaces", label: "Workspaces", icon: "󰖲", description: "Choose what happens after switching windows or workspaces" },
    { id: "timer", label: "Timer", icon: "󰔛", description: "Choose and preview your timer sound" },
    { id: "hardware", label: "Display & touch", icon: "󰍹", description: "Choose where OmaDeck appears and which touchscreen it uses" },
    { id: "monitors", label: "Monitor switching", icon: "󰍹", description: "Choose your monitors and input buttons" },
    { id: "launcher", label: "Launcher", icon: "󰀻", description: "Customize your Command Center applications" }
  ]

  readonly property var selectedEntry: {
    for (var index = 0; index < categories.length; index++)
      if (categories[index].id === selectedCategory) return categories[index]
    return categories[0]
  }

  function showNotice(message) {
    notice = message
    noticeDelay.restart()
  }

  function startMonitorSetup() { monitorPreferences.startSetup() }

  function applyAppearance(key, value) {
    if (!appearanceController || typeof appearanceController.setOption !== "function") {
      showNotice("OmaDeck settings are not ready")
      return false
    }
    var saved = appearanceController.setOption(key, value)
    showNotice(saved ? "Saved" : "Could not save this setting")
    return saved
  }

  function editDashboard() {
    if (!layoutController || typeof layoutController.beginEdit !== "function") return
    if (deck && typeof deck.beginCustomize === "function") deck.beginCustomize()
    else { layoutController.beginEdit(""); if (deck) deck.closeOverlay() }
  }

  function refreshWeather() {
    if (!weatherController || typeof weatherController.refresh !== "function") return
    weatherController.refresh("manual")
    showNotice("Refreshing weather")
  }

  function applyTimerSound(value) {
    if (!timerController || !timerController.soundSettingsLoaded
        || typeof timerController.selectSoundId !== "function") {
      showNotice("Timer settings are not ready")
      return false
    }
    var saved = timerController.selectSoundId(value)
    showNotice(saved ? "Saved" : "Could not save this setting")
    return saved
  }

  function previewTimerSound() {
    if (!timerController || typeof timerController.previewSelectedSound !== "function") return
    var started = timerController.previewSelectedSound()
    showNotice(started ? "Playing timer sound" : "Timer sound is unavailable")
  }

  function applyHardware(key, value) {
    if (!hardwareController || !hardwareController.loaded) {
      showNotice("Hardware settings are not ready")
      return false
    }
    var saved = false
    if (key === "targetScreen" && typeof hardwareController.setTargetScreen === "function")
      saved = hardwareController.setTargetScreen(value)
    else if (key === "primaryMonitor" && typeof hardwareController.setPrimaryMonitor === "function")
      saved = hardwareController.setPrimaryMonitor(value)
    else if (key === "touchDevice" && typeof hardwareController.setTouchDevice === "function")
      saved = hardwareController.setTouchDevice(value)
    showNotice(saved ? "Saved" : "Could not save this hardware setting")
    return saved
  }

  function reconnectTouch() {
    if (!deck || typeof deck.reconnectTouch !== "function") return false
    deck.reconnectTouch()
    showNotice("Reconnecting touchscreen")
    return true
  }

  onSelectedCategoryChanged: {
    settingsList.contentY = 0
    if (selectedCategory === "hardware" && deck
        && typeof deck.refreshTouchDevices === "function") deck.refreshTouchDevices()
  }

  function openApplications() {
    if (!deck || typeof deck.setCommandCenterPage !== "function") return false
    deck.setCommandCenterPage("applications")
    deck.closeOverlay()
    return true
  }

  Timer {
    id: noticeDelay
    interval: 2200
    repeat: false
    onTriggered: root.notice = ""
  }

  Row {
    enabled: !root.keyboardRequested
    anchors.fill: parent
    spacing: Style.spacing.panelGap

    Item {
      id: categoryRail
      width: Math.min(Style.space(300), Math.max(Style.space(248), parent.width * 0.23))
      height: parent.height

      Column {
        anchors.fill: parent
        anchors.margins: Style.spacing.panelPadding
        spacing: Style.spacing.rowGap

        Text {
          text: "Categories"
          color: DeckColors.secondaryText
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1
        }

        Flickable {
          id: categoryList
          width: parent.width
          height: parent.height - y
          contentWidth: width
          contentHeight: categoryColumn.implicitHeight
          clip: true
          flickableDirection: Flickable.VerticalFlick
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: categoryColumn
            width: categoryList.width
            spacing: Style.spacing.labelGap

            Repeater {
              model: root.categories

              PreferenceCategoryButton {
                required property var modelData
                objectName: "preferenceCategory:" + modelData.id
                width: categoryColumn.width
                height: Style.space(50)
                label: modelData.label
                iconText: modelData.icon
                selected: root.selectedCategory === modelData.id
                onClicked: root.selectedCategory = modelData.id
              }
            }
          }
        }
      }
    }

    Item {
      id: settingsPane
      width: parent.width - x
      height: parent.height

      Column {
        anchors.fill: parent
        anchors.margins: Style.spacing.panelPadding
        spacing: Style.spacing.rowGap

        Row {
          width: parent.width
          height: Math.max(categoryTitle.implicitHeight + categoryDescription.implicitHeight
                           + Style.spacing.labelGap, Style.space(48))
          spacing: Style.spacing.panelGap

          Column {
            width: parent.width - noticePill.width - parent.spacing
            spacing: Style.spacing.labelGap

            Text {
              id: categoryTitle
              width: parent.width
              text: root.selectedEntry.label
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.display
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              id: categoryDescription
              width: parent.width
              text: root.selectedEntry.description
              color: DeckColors.secondaryText
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          Item {
            id: noticePill
            visible: root.notice !== ""
            width: visible ? noticeText.implicitWidth + Style.spacing.controlPaddingX * 2 : 0
            height: Style.space(34)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: noticeText
              anchors.centerIn: parent
              text: root.notice
              color: root.notice.indexOf("Could not") === 0 ? Color.urgent : Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }

        Item {
          width: parent.width
          height: parent.height - y

          LauncherPreferences {
            id: launcherPreferences
            objectName: "launcherPreferences"
            anchors.fill: parent
            visible: root.selectedCategory === "launcher"
            active: visible && root.visible && !!root.deck && root.deck.openOverlayName === "preferences"
            controller: root.deck ? root.deck.launcherController : null
            shell: root.deck ? root.deck.shell : null
            inputHost: root
          }
          Flickable {
            visible: root.selectedCategory !== "launcher"
            id: settingsList
            objectName: "omaDeckPreferencesList"
            anchors.fill: parent
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight + Style.spacing.panelPadding
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
              id: settingsColumn
              width: settingsList.width
              spacing: Style.spacing.controlGap

              MonitorInputPreferences {
                id: monitorPreferences
                objectName: "monitorInputPreferences"
                width: parent.width
                visible: root.selectedCategory === "monitors"
                controller: root.monitorInputController
                onSetupNavigation: settingsList.contentY = 0
              }

              Column {
                width: parent.width
                visible: root.selectedCategory === "workspaces"
                spacing: Style.spacing.controlGap

                PreferenceToggle {
                  objectName: "preferencesWorkspaceCloseOnActivate"
                  width: parent.width
                  height: Style.space(72)
                  label: "Close after switching"
                  description: "Dismiss Workspaces when you select a workspace or window"
                  checked: root.appearanceController ? root.appearanceController.workspaceCloseOnActivate === true : false
                  onClicked: root.applyAppearance("workspaceCloseOnActivate", !checked)
                }
              }

              Column {
                width: parent.width
                visible: root.selectedCategory === "omadeck"
                spacing: Style.spacing.controlGap

                Text {
                  height: Style.space(20)
                  text: "DASHBOARD"
                  color: DeckColors.secondaryText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                Button {
                  objectName: "preferencesEditDashboard"
                  width: parent.width
                  height: Style.space(58)
                  text: "Customize layout"
                  iconText: "󰆾"
                  iconSize: Style.font.iconLarge
                  leftAlign: true
                  bordered: false
                  onClicked: root.editDashboard()
                }

                Text {
                  height: Style.space(28)
                  text: "CLOCK"
                  color: DeckColors.secondaryText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                  verticalAlignment: Text.AlignBottom
                }

                PreferenceToggle {
                  objectName: "preferencesUse24Hour"
                  width: parent.width
                  height: Style.space(64)
                  label: "24-hour time"
                  description: "Use 18:30 instead of 6:30 PM"
                  checked: root.appearanceController && root.appearanceController.use24Hour
                  onClicked: root.applyAppearance("use24Hour", !checked)
                }

                PreferenceToggle {
                  objectName: "preferencesShowSeconds"
                  width: parent.width
                  height: Style.space(64)
                  label: "Show seconds"
                  description: "Add seconds to the live Clock readout"
                  checked: root.appearanceController && root.appearanceController.showSeconds
                  onClicked: root.applyAppearance("showSeconds", !checked)
                }

                Text {
                  height: Style.space(28)
                  text: "WEATHER"
                  color: DeckColors.secondaryText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                  verticalAlignment: Text.AlignBottom
                }

                PreferenceToggle {
                  objectName: "preferencesShowWeather"
                  width: parent.width
                  height: Style.space(64)
                  label: "Show weather"
                  description: "Keep the live forecast below the Clock"
                  checked: root.appearanceController && root.appearanceController.showWeather
                  onClicked: root.applyAppearance("showWeather", !checked)
                }

                PreferenceChoice {
                  objectName: "preferencesWeatherStyle"
                  width: parent.width
                  height: implicitHeight
                  enabled: root.appearanceController && root.appearanceController.showWeather
                  opacity: enabled ? 1 : 0.45
                  label: "Weather visual"
                  description: "Select the amount of illustration used by the forecast"
                  value: root.appearanceController ? root.appearanceController.weatherStyle : "scene"
                  options: [
                    { value: "scene", label: "Rich" },
                    { value: "glyph", label: "Glyph" },
                    { value: "minimal", label: "Minimal" }
                  ]
                  onChanged: value => root.applyAppearance("weatherStyle", value)
                }

                PreferenceChoice {
                  objectName: "preferencesWeatherDetail"
                  width: parent.width
                  height: implicitHeight
                  enabled: root.appearanceController && root.appearanceController.showWeather
                  opacity: enabled ? 1 : 0.45
                  label: "Weather detail"
                  description: "Control how much forecast information is visible"
                  value: root.appearanceController ? root.appearanceController.weatherDetail : "standard"
                  options: [
                    { value: "compact", label: "Compact" },
                    { value: "standard", label: "Standard" },
                    { value: "full", label: "Full" }
                  ]
                  onChanged: value => root.applyAppearance("weatherDetail", value)
                }

                PreferenceChoice {
                  objectName: "preferencesTemperatureUnit"
                  width: parent.width
                  height: implicitHeight
                  enabled: root.appearanceController && root.appearanceController.showWeather
                  opacity: enabled ? 1 : 0.45
                  label: "Temperature"
                  description: "Set the temperature and wind-speed units"
                  value: root.appearanceController ? root.appearanceController.temperatureUnit : "fahrenheit"
                  options: [
                    { value: "fahrenheit", label: "°F" },
                    { value: "celsius", label: "°C" }
                  ]
                  onChanged: value => root.applyAppearance("temperatureUnit", value)
                }

                Button {
                  objectName: "preferencesRefreshWeather"
                  width: parent.width
                  height: Style.space(54)
                  enabled: root.appearanceController && root.appearanceController.showWeather
                  opacity: enabled ? 1 : 0.45
                  text: "Refresh weather now"
                  iconText: "󰑓"
                  leftAlign: true
                  bordered: false
                  onClicked: root.refreshWeather()
                }
              }

              Column {
                width: parent.width
                visible: root.selectedCategory === "timer"
                spacing: Style.spacing.controlGap

                PreferenceChoice {
                  objectName: "preferencesTimerSound"
                  width: parent.width
                  height: implicitHeight
                  enabled: root.timerController && root.timerController.soundSettingsLoaded
                  opacity: enabled ? 1 : 0.45
                  label: "Completion sound"
                  description: "Choose the sound played when a timer finishes"
                  value: root.timerController ? root.timerController.selectedSoundId : "ocean"
                  options: root.timerSoundOptions
                  onChanged: value => root.applyTimerSound(value)
                }

                Button {
                  objectName: "preferencesPreviewTimerSound"
                  width: parent.width
                  height: Style.space(54)
                  enabled: root.timerController && root.timerController.soundSettingsLoaded
                    && root.timerController.selectedSoundId !== ""
                  opacity: enabled ? 1 : 0.45
                  text: "Preview timer sound"
                  iconText: "󰎆"
                  leftAlign: true
                  bordered: false
                  onClicked: root.previewTimerSound()
                }
              }

              Column {
                width: parent.width
                visible: root.selectedCategory === "hardware"
                spacing: Style.spacing.controlGap

                PreferenceChoice {
                  objectName: "preferencesTargetScreen"
                  width: parent.width
                  height: implicitHeight
                  enabled: root.hardwareController && root.hardwareController.loaded
                    && root.screenOptions.length > 0
                  opacity: enabled ? 1 : 0.45
                  label: "OmaDeck screen"
                  description: "Moves the dashboard immediately to the selected connected display"
                  value: root.hardwareController ? root.hardwareController.targetScreen : ""
                  options: root.screenOptions
                  onChanged: value => root.applyHardware("targetScreen", value)
                }

                PreferenceChoice {
                  objectName: "preferencesPrimaryMonitor"
                  width: parent.width
                  height: implicitHeight
                  enabled: root.hardwareController && root.hardwareController.loaded
                    && root.screenOptions.length > 0
                  opacity: enabled ? 1 : 0.45
                  label: "Primary workspace monitor"
                  description: "Receives launched applications and workspace actions"
                  value: root.hardwareController ? root.hardwareController.primaryMonitor : ""
                  options: root.screenOptions
                  onChanged: value => root.applyHardware("primaryMonitor", value)
                }

                PreferenceChoice {
                  objectName: "preferencesTouchDevice"
                  width: parent.width
                  height: implicitHeight
                  enabled: root.hardwareController && root.hardwareController.loaded
                    && root.touchOptions.length > 0
                  opacity: enabled ? 1 : 0.45
                  label: "OmaDeck touchscreen"
                  description: root.touchOptions.length > 0
                    ? "Choose the touchscreen that controls OmaDeck"
                    : "No readable direct touchscreen was detected"
                  value: root.hardwareController
                    ? root.hardwareController.selectedTouchDeviceName : ""
                  options: root.touchOptions
                  onChanged: value => root.applyHardware("touchDevice", value)
                }

                PreferenceAction {
                  objectName: "preferencesReconnectTouch"
                  width: parent.width
                  label: "Reconnect touchscreen"
                  description: "Reconnect if the selected touchscreen stops responding"
                  iconText: "󰑓"
                  actionText: "Reconnect"
                  onClicked: root.reconnectTouch()
                }
              }


            }
          }
        }
      }
    }
  }
}
