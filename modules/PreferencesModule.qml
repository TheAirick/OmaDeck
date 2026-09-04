import QtQuick
import qs.Commons
import qs.Ui
import "../components"

Item {
  id: root
  objectName: "preferencesPresenter"

  property var shell: null
  property var deck: null
  property var appearanceController: null
  property var layoutController: null
  property var hardwareController: null
  property var weatherController: null
  property var timerController: null
  property string selectedCategory: "omadeck"
  property string notice: ""

  readonly property var notificationService: shell && typeof shell.firstPartyServiceFor === "function"
    ? shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var nightlightService: shell && typeof shell.firstPartyServiceFor === "function"
    ? shell.firstPartyServiceFor("omarchy.nightlight") : null
  readonly property var idleService: shell && typeof shell.firstPartyServiceFor === "function"
    ? shell.firstPartyServiceFor("omarchy.idle") : null
  readonly property var shellConfig: shell && shell.shellConfig ? shell.shellConfig : ({})
  readonly property var barConfig: shellConfig.bar || ({})
  readonly property string barPosition: shell && shell.bar && shell.bar.position
    ? shell.bar.position : String(barConfig.position || "top")
  readonly property bool barTransparent: shell && shell.bar
    && shell.bar.requestedTransparent !== undefined
    ? shell.bar.requestedTransparent === true : barConfig.transparent === true
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

  readonly property var categories: [
    { id: "omadeck", label: "OmaDeck", icon: "󰍹", description: "Dashboard, clock, weather, and touch-surface preferences" },
    { id: "appearance", label: "Appearance", icon: "󰏘", description: "Themes, wallpaper, fonts, borders, gaps, and visual effects" },
    { id: "desktop", label: "Desktop", icon: "󰇄", description: "Windows, workspaces, animations, and compositor behavior" },
    { id: "displays", label: "Displays", icon: "󰍹", description: "Monitor arrangement, scale, refresh rate, and brightness" },
    { id: "input", label: "Input", icon: "󰌌", description: "Keyboard, mouse, touchpad, and touchscreen behavior" },
    { id: "sound", label: "Sound", icon: "󰕾", description: "Output, microphone, routing, and speaker tuning" },
    { id: "shell", label: "Shell", icon: "󰆍", description: "Bar, notifications, idle, lock, and screensaver" },
    { id: "applications", label: "Applications", icon: "󰀻", description: "Default applications, startup items, and launchers" },
    { id: "power", label: "Power", icon: "󰂄", description: "Power profiles, suspend, and battery behavior" },
    { id: "advanced", label: "Advanced", icon: "󰒓", description: "Keybindings, backups, validation, and configuration files" }
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
    layoutController.beginEdit("")
    if (deck) deck.closeOverlay()
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

  function applyDoNotDisturb(value) {
    if (!notificationService || typeof notificationService.setDoNotDisturb !== "function") {
      showNotice("Notifications are not ready")
      return false
    }
    notificationService.setDoNotDisturb(value)
    showNotice("Saved")
    return true
  }

  function applyNightlight(value) {
    if (!nightlightService || !nightlightService.stateLoaded
        || typeof nightlightService.setNightlight !== "function") {
      showNotice("Night Light is not ready")
      return false
    }
    nightlightService.setNightlight(value)
    showNotice("Saved")
    return true
  }

  function applyKeepAwake(value) {
    if (!idleService || !idleService.stayAwakeStateLoaded
        || typeof idleService.setIdleEnabled !== "function") {
      showNotice("Idle settings are not ready")
      return false
    }
    idleService.setIdleEnabled(!value)
    showNotice("Saved")
    return true
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
    if (selectedCategory === "input" && deck
        && typeof deck.refreshTouchDevices === "function") deck.refreshTouchDevices()
  }

  function mutateShellConfig(mutator) {
    if (!shell || typeof shell.mutateShellConfig !== "function") {
      showNotice("Omarchy settings are not ready")
      return false
    }
    shell.mutateShellConfig(mutator)
    showNotice("Saved")
    return true
  }

  function applyBarPosition(value) {
    var allowed = ["top", "bottom", "left", "right"]
    if (allowed.indexOf(value) < 0) return false
    return mutateShellConfig(function(config) {
      if (!config.bar || typeof config.bar !== "object") config.bar = {}
      config.bar.position = value
    })
  }

  function applyBarTransparency(value) {
    return mutateShellConfig(function(config) {
      if (!config.bar || typeof config.bar !== "object") config.bar = {}
      config.bar.transparent = value === true
    })
  }

  function applyIdleTimeout(key, rawValue) {
    if (key !== "screensaver" && key !== "lock") return false
    var seconds = Number(rawValue)
    var allowed = key === "screensaver"
      ? [60, 150, 300, 600, 900]
      : [300, 600, 900, 1800, 3600]
    if (!Number.isInteger(seconds) || allowed.indexOf(seconds) < 0) return false
    return mutateShellConfig(function(config) {
      if (!config.idle || typeof config.idle !== "object") config.idle = {}
      config.idle[key] = seconds
    })
  }

  function openOmarchyMenu(route) {
    if (!shell || typeof shell.summon !== "function") {
      showNotice("Omarchy menu is not ready")
      return false
    }
    var opened = shell.summon("omarchy.menu", '{"menu":"' + route + '"}')
    if (opened && deck) deck.closeOverlay()
    if (!opened) showNotice("This Omarchy menu is unavailable")
    return opened === true
  }

  function openOmarchyPanel(pluginId) {
    if (!shell || typeof shell.summon !== "function") {
      showNotice("Omarchy panel is not ready")
      return false
    }
    var opened = shell.summon(pluginId, "")
    if (opened && deck) deck.closeOverlay()
    if (!opened) showNotice("This Omarchy panel is unavailable")
    return opened === true
  }

  function openVolume() {
    if (!deck || typeof deck.setOpenDrawer !== "function") return false
    deck.setOpenDrawer("left", "preferences:sound")
    deck.closeOverlay()
    return true
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
          color: Color.muted
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
              color: Color.muted
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

          Flickable {
            id: omaDeckSettings
            objectName: "omaDeckPreferencesList"
            anchors.fill: parent
            visible: root.selectedCategory === "omadeck"
            contentWidth: width
            contentHeight: omaDeckColumn.implicitHeight + Style.spacing.panelPadding
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
              id: omaDeckColumn
              width: omaDeckSettings.width
              spacing: Style.spacing.controlGap

              Text {
                height: Style.space(20)
                text: "DASHBOARD"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }

              Button {
                objectName: "preferencesEditDashboard"
                width: parent.width
                height: Style.space(58)
                text: "Edit dashboard layout"
                iconText: "󰆾"
                iconSize: Style.font.iconLarge
                leftAlign: true
                bordered: false
                onClicked: root.editDashboard()
              }

              Text {
                height: Style.space(28)
                text: "CLOCK"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
                verticalAlignment: Text.AlignBottom
              }

              PreferenceChoice {
                objectName: "preferencesClockStyle"
                width: parent.width
                height: Style.space(68)
                label: "Clock style"
                description: "Choose how prominently the current time is presented"
                value: root.appearanceController ? root.appearanceController.clockStyle : "hero"
                options: [
                  { value: "hero", label: "Hero" },
                  { value: "split", label: "Split" },
                  { value: "compact", label: "Compact" }
                ]
                onChanged: value => root.applyAppearance("clockStyle", value)
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
                color: Color.muted
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
                height: Style.space(68)
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
                height: Style.space(68)
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
                height: Style.space(68)
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

              Text {
                height: Style.space(28)
                text: "TIMER"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
                verticalAlignment: Text.AlignBottom
              }

              PreferenceChoice {
                objectName: "preferencesTimerSound"
                width: parent.width
                height: Style.space(68)
                enabled: root.timerController && root.timerController.soundSettingsLoaded
                opacity: enabled ? 1 : 0.45
                label: "Completion sound"
                description: "Choose the sound played when a timer finishes"
                value: root.timerController ? root.timerController.selectedSoundId : "complete"
                options: [
                  { value: "", label: "Silent" },
                  { value: "alarm-clock-elapsed", label: "Alarm" },
                  { value: "complete", label: "Complete" },
                  { value: "bell", label: "Bell" },
                  { value: "phone-incoming-call", label: "Ring" },
                  { value: "dialog-warning", label: "Warning" }
                ]
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
          }

          Flickable {
            id: shellSettings
            objectName: "shellPreferencesList"
            anchors.fill: parent
            visible: root.selectedCategory === "shell"
            contentWidth: width
            contentHeight: shellColumn.implicitHeight + Style.spacing.panelPadding
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
              id: shellColumn
              width: shellSettings.width
              spacing: Style.spacing.controlGap

              Text {
                height: Style.space(20)
                text: "NOTIFICATIONS & COLOR"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }

              PreferenceToggle {
                objectName: "preferencesDoNotDisturb"
                width: parent.width
                height: Style.space(64)
                enabled: root.notificationService !== null
                opacity: enabled ? 1 : 0.45
                label: "Do Not Disturb"
                description: "Silence notification popups while preserving notification history"
                checked: root.notificationService && root.notificationService.doNotDisturb
                onClicked: root.applyDoNotDisturb(!checked)
              }

              PreferenceToggle {
                objectName: "preferencesNightlight"
                width: parent.width
                height: Style.space(64)
                enabled: root.nightlightService && root.nightlightService.stateLoaded
                opacity: enabled ? 1 : 0.45
                label: "Night Light"
                description: "Use Omarchy's warmer evening color temperature"
                checked: root.nightlightService && root.nightlightService.enabled
                onClicked: root.applyNightlight(!checked)
              }

              Text {
                height: Style.space(28)
                text: "IDLE & LOCK"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
                verticalAlignment: Text.AlignBottom
              }

              PreferenceToggle {
                objectName: "preferencesKeepAwake"
                width: parent.width
                height: Style.space(64)
                enabled: root.idleService && root.idleService.stayAwakeStateLoaded
                opacity: enabled ? 1 : 0.45
                label: "Keep Awake"
                description: root.idleService
                  ? "Temporarily prevent screensaver and automatic lock · Current schedule: "
                    + root.idleService.screensaverTimeoutSeconds + "s screensaver, "
                    + root.idleService.lockTimeoutSeconds + "s lock"
                  : "Temporarily prevent screensaver and automatic lock"
                checked: root.idleService && root.idleService.stayAwakeStateLoaded
                  && !root.idleService.idleEnabled
                onClicked: root.applyKeepAwake(!checked)
              }
            }
          }

          Flickable {
            id: nativeSettings
            objectName: "nativePreferencesList"
            anchors.fill: parent
            visible: root.selectedCategory !== "omadeck" && root.selectedCategory !== "shell"
            contentWidth: width
            contentHeight: nativeColumn.implicitHeight + Style.spacing.panelPadding
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
              id: nativeColumn
              width: nativeSettings.width
              spacing: Style.spacing.controlGap

              Column {
                id: appearanceGroup
                width: parent.width
                visible: root.selectedCategory === "appearance"
                spacing: Style.spacing.controlGap

                Text {
                  height: Style.space(20)
                  text: "STYLE"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                PreferenceAction {
                  objectName: "preferencesTheme"
                  width: parent.width
                  label: "Theme"
                  description: "Choose from installed Omarchy themes"
                  iconText: "󰸌"
                  actionText: "Choose"
                  onClicked: root.openOmarchyMenu("style.theme")
                }

                PreferenceAction {
                  objectName: "preferencesBackground"
                  width: parent.width
                  label: "Background"
                  description: "Choose a wallpaper from the current theme"
                  iconText: ""
                  actionText: "Choose"
                  onClicked: root.openOmarchyMenu("style.background")
                }

                PreferenceAction {
                  objectName: "preferencesFont"
                  width: parent.width
                  label: "Monospace font"
                  description: "Use Omarchy's installed-font selector"
                  iconText: ""
                  actionText: "Choose"
                  onClicked: root.openOmarchyMenu("style.font")
                }

                Text {
                  height: Style.space(28)
                  text: "MENU BAR"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                  verticalAlignment: Text.AlignBottom
                }

                PreferenceChoice {
                  objectName: "preferencesBarPosition"
                  width: parent.width
                  height: Style.space(68)
                  label: "Position"
                  description: "Place the Omarchy bar on any screen edge"
                  value: root.barPosition
                  options: [
                    { value: "top", label: "Top" },
                    { value: "bottom", label: "Bottom" },
                    { value: "left", label: "Left" },
                    { value: "right", label: "Right" }
                  ]
                  onChanged: value => root.applyBarPosition(value)
                }

                PreferenceToggle {
                  objectName: "preferencesBarTransparency"
                  width: parent.width
                  height: Style.space(64)
                  label: "Transparent bar"
                  description: "Let the active wallpaper show through the menu bar"
                  checked: root.barTransparent
                  onClicked: root.applyBarTransparency(!checked)
                }
              }

              Column {
                id: desktopGroup
                width: parent.width
                visible: root.selectedCategory === "desktop"
                spacing: Style.spacing.controlGap

                Text {
                  height: Style.space(20)
                  text: "WINDOWS & WORKSPACES"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                PreferenceAction {
                  objectName: "preferencesDesktopToggles"
                  width: parent.width
                  label: "Window and workspace toggles"
                  description: "Gaps, workspace layout, one-window ratio, and more"
                  iconText: "󱂬"
                  actionText: "Manage"
                  onClicked: root.openOmarchyMenu("trigger.toggle")
                }

                PreferenceAction {
                  objectName: "preferencesKeybindings"
                  width: parent.width
                  label: "Keybindings"
                  description: "Browse the active Omarchy shortcuts"
                  iconText: ""
                  actionText: "Browse"
                  onClicked: root.openOmarchyMenu("learn.keybindings")
                }

                Text {
                  height: Style.space(28)
                  text: "IDLE & LOCK"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                  verticalAlignment: Text.AlignBottom
                }

                PreferenceChoice {
                  objectName: "preferencesScreensaverTimeout"
                  width: parent.width
                  height: Style.space(68)
                  label: "Screensaver"
                  description: "Start after this much inactivity"
                  value: String(root.idleService ? root.idleService.screensaverTimeoutSeconds : 150)
                  options: [
                    { value: "60", label: "1m" },
                    { value: "150", label: "2.5m" },
                    { value: "300", label: "5m" },
                    { value: "600", label: "10m" },
                    { value: "900", label: "15m" }
                  ]
                  onChanged: value => root.applyIdleTimeout("screensaver", value)
                }

                PreferenceChoice {
                  objectName: "preferencesLockTimeout"
                  width: parent.width
                  height: Style.space(68)
                  label: "Automatic lock"
                  description: "Lock after this much inactivity"
                  value: String(root.idleService ? root.idleService.lockTimeoutSeconds : 300)
                  options: [
                    { value: "300", label: "5m" },
                    { value: "600", label: "10m" },
                    { value: "900", label: "15m" },
                    { value: "1800", label: "30m" },
                    { value: "3600", label: "1h" }
                  ]
                  onChanged: value => root.applyIdleTimeout("lock", value)
                }

                PreferenceToggle {
                  objectName: "preferencesDesktopKeepAwake"
                  width: parent.width
                  height: Style.space(64)
                  enabled: root.idleService && root.idleService.stayAwakeStateLoaded
                  opacity: enabled ? 1 : 0.45
                  label: "Keep Awake"
                  description: "Temporarily suspend the idle and lock schedule"
                  checked: root.idleService && root.idleService.stayAwakeStateLoaded
                    && !root.idleService.idleEnabled
                  onClicked: root.applyKeepAwake(!checked)
                }
              }

              Column {
                width: parent.width
                visible: root.selectedCategory === "displays"
                spacing: Style.spacing.controlGap

                Text {
                  height: Style.space(20)
                  text: "DISPLAYS"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                PreferenceChoice {
                  objectName: "preferencesTargetScreen"
                  width: parent.width
                  height: Style.space(68)
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
                  height: Style.space(68)
                  enabled: root.hardwareController && root.hardwareController.loaded
                    && root.screenOptions.length > 0
                  opacity: enabled ? 1 : 0.45
                  label: "Primary workspace monitor"
                  description: "Receives launched applications and workspace actions"
                  value: root.hardwareController ? root.hardwareController.primaryMonitor : ""
                  options: root.screenOptions
                  onChanged: value => root.applyHardware("primaryMonitor", value)
                }

                PreferenceAction {
                  objectName: "preferencesDisplayPanel"
                  width: parent.width
                  label: "Brightness and display controls"
                  description: "Open Omarchy's live monitor panel"
                  iconText: "󰃠"
                  actionText: "Open"
                  onClicked: root.openOmarchyPanel("omarchy.monitor")
                }

                PreferenceAction {
                  objectName: "preferencesMonitorLayout"
                  width: parent.width
                  label: "Monitor layout"
                  description: "Open Omarchy's monitor configuration"
                  iconText: "󰍹"
                  actionText: "Configure"
                  onClicked: root.openOmarchyMenu("setup.monitors")
                }
              }

              Column {
                width: parent.width
                visible: root.selectedCategory === "input"
                spacing: Style.spacing.controlGap

                Text {
                  height: Style.space(20)
                  text: "INPUT"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                PreferenceChoice {
                  objectName: "preferencesTouchDevice"
                  width: parent.width
                  height: Style.space(68)
                  enabled: root.hardwareController && root.hardwareController.loaded
                    && root.touchOptions.length > 0
                  opacity: enabled ? 1 : 0.45
                  label: "OmaDeck touchscreen"
                  description: root.touchOptions.length > 0
                    ? "Only this detected direct-touch device may be exclusively captured"
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
                  description: "Release and reacquire the configured direct-touch device"
                  iconText: "󰑓"
                  actionText: "Reconnect"
                  onClicked: root.reconnectTouch()
                }

                PreferenceAction {
                  objectName: "preferencesInputHardware"
                  width: parent.width
                  label: "Hardware controls"
                  description: "Touchpad, touchscreen, keyboard lighting, and GPU options"
                  iconText: "󰌌"
                  actionText: "Manage"
                  onClicked: root.openOmarchyMenu("trigger.hardware")
                }

                PreferenceAction {
                  objectName: "preferencesInputConfig"
                  width: parent.width
                  label: "Advanced input behavior"
                  description: "Open Omarchy's keyboard, mouse, touchpad, and touch configuration"
                  iconText: ""
                  actionText: "Configure"
                  onClicked: root.openOmarchyMenu("setup.input")
                }
              }

              Column {
                width: parent.width
                visible: root.selectedCategory === "sound"
                spacing: Style.spacing.controlGap

                Text {
                  height: Style.space(20)
                  text: "SOUND"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                PreferenceAction {
                  objectName: "preferencesVolumeMixer"
                  width: parent.width
                  label: "OmaDeck volume mixer"
                  description: "Adjust output, microphone, and active audio categories"
                  iconText: "󰕾"
                  actionText: "Open"
                  onClicked: root.openVolume()
                }

                PreferenceAction {
                  objectName: "preferencesAudioPanel"
                  width: parent.width
                  label: "Devices and routing"
                  description: "Open Omarchy's audio device panel"
                  iconText: "󰓃"
                  actionText: "Open"
                  onClicked: root.openOmarchyPanel("omarchy.audio")
                }

                PreferenceAction {
                  objectName: "preferencesBluetoothPanel"
                  width: parent.width
                  label: "Bluetooth audio"
                  description: "Pair, connect, and manage wireless audio devices"
                  iconText: "󰂯"
                  actionText: "Open"
                  onClicked: root.openOmarchyPanel("omarchy.bluetooth")
                }
              }

              Column {
                width: parent.width
                visible: root.selectedCategory === "applications"
                spacing: Style.spacing.controlGap

                Text {
                  height: Style.space(20)
                  text: "APPLICATIONS"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                PreferenceAction {
                  objectName: "preferencesLauncherApps"
                  width: parent.width
                  label: "OmaDeck launcher"
                  description: "Add, remove, and rearrange Command Center applications"
                  iconText: "󰀻"
                  actionText: "Edit"
                  onClicked: root.openApplications()
                }

                PreferenceAction {
                  objectName: "preferencesDefaultApps"
                  width: parent.width
                  label: "Default applications"
                  description: "Choose the browser, terminal, editor, and coding agent"
                  iconText: ""
                  actionText: "Choose"
                  onClicked: root.openOmarchyMenu("setup.default")
                }

                PreferenceAction {
                  objectName: "preferencesAppLibrary"
                  width: parent.width
                  label: "Application library"
                  description: "Search and launch installed desktop applications"
                  iconText: "󰀻"
                  actionText: "Browse"
                  onClicked: root.openOmarchyMenu("apps")
                }
              }

              Column {
                width: parent.width
                visible: root.selectedCategory === "power"
                spacing: Style.spacing.controlGap

                Text {
                  height: Style.space(20)
                  text: "POWER"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                PreferenceAction {
                  objectName: "preferencesPowerPanel"
                  width: parent.width
                  label: "Battery and power profile"
                  description: "Inspect battery state and choose a supported power profile"
                  iconText: "󰂄"
                  actionText: "Open"
                  onClicked: root.openOmarchyPanel("omarchy.power")
                }

                PreferenceToggle {
                  objectName: "preferencesPowerKeepAwake"
                  width: parent.width
                  height: Style.space(64)
                  enabled: root.idleService && root.idleService.stayAwakeStateLoaded
                  opacity: enabled ? 1 : 0.45
                  label: "Keep Awake"
                  description: "Temporarily prevent screensaver and automatic lock"
                  checked: root.idleService && root.idleService.stayAwakeStateLoaded
                    && !root.idleService.idleEnabled
                  onClicked: root.applyKeepAwake(!checked)
                }

                PreferenceAction {
                  objectName: "preferencesPowerActions"
                  width: parent.width
                  label: "Session and power actions"
                  description: "Lock, suspend, hibernate, restart, or shut down"
                  iconText: ""
                  actionText: "Open"
                  onClicked: root.openOmarchyMenu("system")
                }
              }

              Column {
                width: parent.width
                visible: root.selectedCategory === "advanced"
                spacing: Style.spacing.controlGap

                Text {
                  height: Style.space(20)
                  text: "OMARCHY"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                PreferenceAction {
                  objectName: "preferencesPlugins"
                  width: parent.width
                  label: "Plugins"
                  description: "Enable, disable, clone, add, or remove shell plugins"
                  iconText: "󰐱"
                  actionText: "Manage"
                  onClicked: root.openOmarchyMenu("setup.plugin")
                }

                PreferenceAction {
                  objectName: "preferencesConfig"
                  width: parent.width
                  label: "Configuration files"
                  description: "Open Omarchy's validated configuration routes"
                  iconText: ""
                  actionText: "Open"
                  onClicked: root.openOmarchyMenu("setup.config")
                }

                PreferenceAction {
                  objectName: "preferencesUpdates"
                  width: parent.width
                  label: "Updates and recovery"
                  description: "Update Omarchy, themes, firmware, or refresh a component"
                  iconText: ""
                  actionText: "Open"
                  onClicked: root.openOmarchyMenu("update")
                }
              }
            }
          }
        }
      }
    }
  }
}
