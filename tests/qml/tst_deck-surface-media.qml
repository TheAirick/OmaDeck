import QtQuick
import QtTest
import Quickshell.Services.Pipewire as Pw
import "../../components" as Components

TestCase {
  id: testCase
  name: "DeckSurfaceMediaPanels"
  when: windowShown

  width: 2700
  height: 800
  visible: true
  property var fixtureStreams: []

  function init() {
    mediaFixture.activePlayer = playerFixture
    var sinkAudio = createTemporaryObject(audioComponent, testCase, { volume: 0.7 })
    var sourceAudio = createTemporaryObject(audioComponent, testCase, { volume: 0.5 })
    var sink = createTemporaryObject(nodeComponent, testCase, {
      name: "fixture-sink", isSink: true, audio: sinkAudio
    })
    var source = createTemporaryObject(nodeComponent, testCase, {
      name: "fixture-source", audio: sourceAudio
    })
    var streams = []
    for (var index = 0; index < 4; index++) {
      var streamAudio = createTemporaryObject(audioComponent, testCase, { volume: 0.2 + index * 0.1 })
      streams.push(createTemporaryObject(nodeComponent, testCase, {
        name: "firefox-stream-" + index,
        description: "Firefox " + index,
        isStream: true,
        isSink: true,
        type: "Stream/Output/Audio",
        audio: streamAudio,
        properties: ({ "application.name": "Firefox" })
      }))
    }
    fixtureStreams = streams
    Pw.Pipewire.defaultAudioSink = sink
    Pw.Pipewire.defaultAudioSource = source
    Pw.Pipewire.nodes.values = streams
  }

  function createDeck(width, height) {
    var deck = createTemporaryObject(deckSurfaceComponent, testCase, {
      width: width || 2560,
      height: height || 720,
      targetScreen: "DP-3",
      shell: shellFixture,
      layoutController: layoutFixture,
      appearanceController: appearanceFixture,
      launcherController: launcherFixture,
      hardwareController: hardwareFixture,
      weatherController: weatherFixture,
      timerController: timerFixture
    })
    verify(deck !== null)
    return deck
  }

  function findByProperty(item, propertyName, value) {
    if (item && item[propertyName] === value) return item
    if (!item || !item.children) return null
    for (var index = 0; index < item.children.length; index++) {
      var found = findByProperty(item.children[index], propertyName, value)
      if (found) return found
    }
    return null
  }

  function findWhere(item, predicate) {
    if (item && predicate(item)) return item
    if (!item || !item.children) return null
    for (var index = 0; index < item.children.length; index++) {
      var found = findWhere(item.children[index], predicate)
      if (found) return found
    }
    return null
  }

  function rectIn(item, ancestor) {
    var origin = item.mapToItem(ancestor, 0, 0)
    return { x: origin.x, y: origin.y, width: item.width, height: item.height }
  }

  function collectByObjectName(item, objectName, result) {
    if (!item) return
    if (item.objectName === objectName) result.push(item)
    var descendants = item.data !== undefined ? item.data : item.children
    for (var index = 0; descendants && index < descendants.length; index++)
      collectByObjectName(descendants[index], objectName, result)
  }

  function clickItem(deck, item) {
    verify(item !== null)
    var point = item.mapToItem(deck, item.width / 2, item.height / 2)
    verify(point.x >= 0 && point.x <= deck.width,
      "pointer x " + point.x + " outside 0.." + deck.width)
    verify(point.y >= 0 && point.y <= deck.height,
      "pointer y " + point.y + " outside 0.." + deck.height)
    mouseClick(item, item.width / 2, item.height / 2)
  }

  function test_nowPlayingIsStaticAndLeftDrawerOwnsOnlyVolume() {
    var deck = createDeck()
    deck.setOpenDrawer("left", "test")
    wait(260)

    var left = findChild(deck, "leftVolumeDrawer")
    var right = findChild(deck, "rightSystemDrawer")
    var notifications = findChild(deck, "notificationCenterOverlay")
    var overview = findChild(deck, "omadeckOverviewOverlay")
    var preferences = findChild(deck, "preferencesOverlay")
    var center = findChild(deck, "deckCenterCanvas")
    var media = findChild(deck, "staticMediaPanel")
    var nowPlayingCard = findChild(deck, "nowPlayingPanelCard")
    var mixerCard = findChild(deck, "audioMixerPanelCard")
    verify(left !== null)
    verify(right !== null)
    verify(notifications !== null)
    verify(overview !== null)
    verify(preferences !== null)
    verify(center !== null)
    verify(media !== null)
    verify(nowPlayingCard !== null)
    verify(mixerCard !== null)

    compare(left.framed, false)
    compare(left.color.a, 0)
    compare(left.border.width, 0)
    verify(left.dismissInset > 0)
    compare(right.framed, true)
    verify(right.border.width > 0)
    compare(notifications.open, false)
    compare(overview.open, false)
    compare(preferences.open, false)

    verify(nowPlayingCard.parent !== mixerCard.parent)
    verify(nowPlayingCard.parent !== left)
    verify(mixerCard.parent !== media)
    verify(nowPlayingCard.visible)
    verify(mixerCard.visible)
    compare(nowPlayingCard.y, mixerCard.y)
    compare(nowPlayingCard.height, mixerCard.height)
    var mixerBounds = rectIn(mixerCard, deck)
    var nowPlayingBounds = rectIn(nowPlayingCard, deck)
    compare(nowPlayingBounds.x - (mixerBounds.x + mixerBounds.width), deck.innerGap)
    compare(nowPlayingCard.width, deck.staticMediaWidth)
    verify(mixerCard.y + mixerCard.height <= left.height)

    compare(deck.reservedLeft, deck.leftDrawerWidth + deck.innerGap)
    compare(center.x, deck.outerGap + deck.staticMediaReserve + deck.reservedLeft)
    compare(center.width, deck.usableWidth - deck.staticMediaReserve - deck.reservedLeft)
  }

  function test_standardInstallReportsCompositorTouchWithoutNativeArtifact() {
    var deck = createDeck()
    var state = JSON.parse(deck.touchState())

    compare(state.active, false)
    compare(state.exclusiveGrab, false)
    compare(state.nativeAvailable, false)
    compare(state.mode, "compositor")
    compare(state.devicePath, "")
    verify(state.status.indexOf("compositor-managed input") !== -1)
  }

  function test_verticalOverlaysPreserveCenterGeometryAndHorizontalDrawers() {
    var deck = createDeck()
    var center = findChild(deck, "deckCenterCanvas")
    var notifications = findChild(deck, "notificationCenterOverlay")
    var overview = findChild(deck, "omadeckOverviewOverlay")
    var preferences = findChild(deck, "preferencesOverlay")
    verify(center !== null && notifications !== null && overview !== null && preferences !== null)
    deck.setOpenDrawer("left", "test:before-overlay")
    wait(260)
    verify(deck.reservedLeft > 0)
    var underlyingCenter = rectIn(center, deck)
    var underlyingMedia = rectIn(findChild(deck, "nowPlayingPanelCard"), deck)
    deck.openOverlay("notifications")
    wait(280)
    compare(deck.openDrawer, "left")
    compare(deck.openOverlayName, "notifications")
    compare(deck.reservedTop, 0)
    compare(deck.reservedBottom, 0)
    compare(JSON.stringify(rectIn(center, deck)), JSON.stringify(underlyingCenter))
    compare(JSON.stringify(rectIn(findChild(deck, "nowPlayingPanelCard"), deck)), JSON.stringify(underlyingMedia))
    compare(notifications.y, 0)

    deck.openOverlay("overview")
    wait(280)
    compare(deck.openDrawer, "left")
    compare(deck.openOverlayName, "overview")
    compare(JSON.stringify(rectIn(center, deck)), JSON.stringify(underlyingCenter))
    compare(overview.y, 0)

    deck.openOverlay("preferences")
    wait(280)
    compare(deck.openDrawer, "left")
    compare(deck.openOverlayName, "preferences")
    compare(JSON.stringify(rectIn(center, deck)), JSON.stringify(underlyingCenter))
    compare(preferences.y, 0)

    deck.closeOverlay()
    wait(280)
    compare(deck.openDrawer, "left")
    compare(deck.openOverlayName, "")
    compare(JSON.stringify(rectIn(center, deck)), JSON.stringify(underlyingCenter))
  }

  function test_preferencesOverlayEditsOmaDeckThroughSharedControllers() {
    appearanceFixture.reset()
    timerFixture.resetPreferences()
    var deck = createDeck()
    wait(100)
    var preferencesButton = findByProperty(deck, "label", "Preferences")
    verify(preferencesButton !== null)

    clickItem(deck, preferencesButton)
    wait(280)
    compare(deck.openOverlayName, "preferences")
    var preferences = findChild(deck, "preferencesOverlay")
    var use24Hour = findChild(preferences, "preferencesUse24Hour")
    var timerSound = findChild(preferences, "preferencesTimerSound")
    var previewTimerSound = findChild(preferences, "preferencesPreviewTimerSound")
    var editDashboard = findChild(preferences, "preferencesEditDashboard")
    verify(use24Hour !== null && timerSound !== null
      && previewTimerSound !== null && editDashboard !== null)

    clickItem(deck, use24Hour)
    compare(appearanceFixture.use24Hour, true)
    compare(appearanceFixture.lastKey, "use24Hour")
    compare(appearanceFixture.lastValue, true)

    var omaDeckList = findChild(preferences, "omaDeckPreferencesList")
    verify(omaDeckList !== null)
    omaDeckList.contentY = Math.max(0, omaDeckList.contentHeight - omaDeckList.height)
    wait(0)
    var bellOption = findByProperty(timerSound, "text", "Bell")
    verify(bellOption !== null)
    clickItem(deck, bellOption)
    compare(timerFixture.selectedSoundId, "bell")
    clickItem(deck, previewTimerSound)
    compare(timerFixture.previewCalls, 1)

    omaDeckList.contentY = 0
    wait(0)
    clickItem(deck, editDashboard)
    wait(280)
    compare(layoutFixture.editMode, true)
    compare(layoutFixture.selectedPath, "")
    compare(deck.openOverlayName, "")
  }

  function test_preferencesShellPageUsesLiveOmarchyServices() {
    notificationFixture.doNotDisturb = false
    nightlightFixture.enabled = false
    nightlightFixture.applyCalls = 0
    idleFixture.idleEnabled = true
    idleFixture.applyCalls = 0

    var deck = createDeck()
    deck.openOverlay("preferences")
    wait(280)
    var overlay = findChild(deck, "preferencesOverlay")
    var preferences = findChild(overlay, "preferencesPresenter")
    verify(preferences !== null)
    preferences.selectedCategory = "shell"
    wait(0)

    var dnd = findChild(preferences, "preferencesDoNotDisturb")
    var nightlight = findChild(preferences, "preferencesNightlight")
    var keepAwake = findChild(preferences, "preferencesKeepAwake")
    verify(dnd !== null && nightlight !== null && keepAwake !== null)
    verify(dnd.visible && nightlight.visible && keepAwake.visible)

    clickItem(deck, dnd)
    compare(notificationFixture.doNotDisturb, true)
    clickItem(deck, nightlight)
    compare(nightlightFixture.enabled, true)
    compare(nightlightFixture.applyCalls, 1)
    clickItem(deck, keepAwake)
    compare(idleFixture.idleEnabled, false)
    compare(idleFixture.applyCalls, 1)
    grabImage(overlay).save("/tmp/omadeck-preferences-shell.png")
  }

  function test_preferencesNativeCategoriesUseHostSettingsAndPanels() {
    shellFixture.resetPreferencesState()
    var deck = createDeck()
    deck.openOverlay("preferences")
    wait(280)

    var overlay = findChild(deck, "preferencesOverlay")
    var preferences = findChild(overlay, "preferencesPresenter")
    verify(preferences !== null)
    preferences.selectedCategory = "appearance"
    wait(0)

    var barPosition = findChild(preferences, "preferencesBarPosition")
    var barTransparency = findChild(preferences, "preferencesBarTransparency")
    var theme = findChild(preferences, "preferencesTheme")
    verify(barPosition !== null && barTransparency !== null && theme !== null)
    verify(barPosition.visible && barTransparency.visible && theme.visible)

    barPosition.changed("bottom")
    compare(shellFixture.shellConfig.bar.position, "bottom")
    compare(barFixture.position, "bottom")
    compare(shellFixture.shellMutationCalls, 1)

    barTransparency.clicked()
    compare(shellFixture.shellConfig.bar.transparent, true)
    compare(barFixture.requestedTransparent, true)
    compare(shellFixture.shellMutationCalls, 2)

    theme.clicked()
    wait(280)
    compare(shellFixture.lastSummonedId, "omarchy.menu")
    compare(shellFixture.lastSummonedPayload, '{"menu":"style.theme"}')
    compare(deck.openOverlayName, "")
  }

  function test_preferencesDesktopTimeoutsPersistThroughHostConfig() {
    shellFixture.resetPreferencesState()
    var deck = createDeck()
    deck.openOverlay("preferences")
    wait(280)

    var preferences = findChild(deck, "preferencesPresenter")
    verify(preferences !== null)
    preferences.selectedCategory = "desktop"
    wait(0)

    var screensaver = findChild(preferences, "preferencesScreensaverTimeout")
    var lock = findChild(preferences, "preferencesLockTimeout")
    verify(screensaver !== null && lock !== null)
    screensaver.changed("300")
    compare(shellFixture.shellConfig.idle.screensaver, 300)
    compare(idleFixture.screensaverTimeoutSeconds, 300)
    lock.changed("1800")
    compare(shellFixture.shellConfig.idle.lock, 1800)
    compare(idleFixture.lockTimeoutSeconds, 1800)
    compare(shellFixture.shellMutationCalls, 2)
  }

  function test_preferencesHardwareSelectorsUseDetectedControllerChoices() {
    hardwareFixture.reset()
    var deck = createDeck()
    deck.openOverlay("preferences")
    wait(280)

    var preferences = findChild(deck, "preferencesPresenter")
    verify(preferences !== null)
    preferences.selectedCategory = "displays"
    wait(0)

    var target = findChild(preferences, "preferencesTargetScreen")
    var primary = findChild(preferences, "preferencesPrimaryMonitor")
    verify(target !== null && primary !== null)
    compare(target.value, "DP-3")
    compare(primary.value, "DP-1")
    grabImage(findChild(deck, "preferencesOverlay")).save("/tmp/omadeck-preferences-displays.png")
    primary.changed("DP-3")
    compare(hardwareFixture.primaryMonitor, "DP-3")
    compare(hardwareFixture.applyCalls, 1)

    preferences.selectedCategory = "input"
    wait(0)
    var touch = findChild(preferences, "preferencesTouchDevice")
    verify(touch !== null)
    compare(touch.value, "wch.cn TouchScreen")
    grabImage(findChild(deck, "preferencesOverlay")).save("/tmp/omadeck-preferences-input.png")
    touch.changed("XENEON Edge Touch")
    compare(hardwareFixture.touchDeviceNames.length, 1)
    compare(hardwareFixture.touchDeviceNames[0], "XENEON Edge Touch")
    compare(hardwareFixture.applyCalls, 2)
  }

  function test_preferencesCanScrollBackFromBottomAcrossInteractiveRows() {
    var deck = createDeck()
    deck.openOverlay("preferences")
    wait(280)

    var preferences = findChild(deck, "preferencesOverlay")
    var settingsList = findChild(preferences, "omaDeckPreferencesList")
    verify(settingsList !== null)
    var bottom = Math.max(0, settingsList.contentHeight - settingsList.height)
    verify(bottom > 0)
    settingsList.contentY = bottom
    wait(0)

    var timerSound = findChild(settingsList, "preferencesTimerSound")
    var completeLabel = findByProperty(timerSound, "text", "Complete")
    verify(completeLabel !== null)
    var completeOption = completeLabel.parent
    var pointer = completeOption.mapToItem(settingsList,
      completeOption.width / 2, completeOption.height / 2)
    var pointerX = pointer.x
    var pointerY = pointer.y
    var gesture = touchEvent(settingsList)
    gesture.press(0, settingsList, pointerX, pointerY).commit()
    gesture.move(0, settingsList, pointerX, pointerY + 36).commit()
    wait(30)
    gesture.move(0, settingsList, pointerX, pointerY + 128).commit()
    wait(80)
    gesture.release(0, settingsList, pointerX, pointerY + 128).commit()
    wait(120)

    verify(settingsList.contentY < bottom - 20,
      "a downward drag over a setting must scroll away from the bottom")
  }

  function test_commandCenterApplicationsPageEditsPersistentOrder() {
    launcherFixture.reset()
    var deck = createDeck()
    wait(100)
    var page = findChild(deck, "commandCenterApplicationsPage")
    var applicationsButton = findByProperty(deck, "label", "Applications")
    verify(page !== null && applicationsButton !== null)
    compare(page.visible, false)

    clickItem(deck, applicationsButton)
    wait(100)
    compare(page.visible, true)
    compare(page.entries.length, 3)
    verify(findChild(page, "launcherEntry-terminal") !== null)

    page.beginEditing("browser")
    page.moveSelected(-1)
    compare(JSON.stringify(launcherFixture.entryIds), JSON.stringify(["browser", "terminal", "files"]))
    page.removeSelected()
    compare(JSON.stringify(launcherFixture.entryIds), JSON.stringify(["terminal", "files"]))
    page.catalogOpen = true
    page.activate(launcherFixture.entryForId("browser"))
    compare(JSON.stringify(launcherFixture.entryIds), JSON.stringify(["terminal", "files", "browser"]))

    page.catalogOpen = false
    page.finishEditing()
    page.backRequested()
    wait(0)
    compare(page.visible, false)
    compare(deck.commandCenterPage, "home")
  }

  function test_volumeNowPlayingAndCenterUseOneTokenGaps() {
    var deck = createDeck()
    deck.setOpenDrawer("left", "test:geometry")
    wait(260)

    var left = findChild(deck, "leftVolumeDrawer")
    var center = findChild(deck, "deckCenterCanvas")
    var nowPlayingCard = findChild(deck, "nowPlayingPanelCard")
    var mixerCard = findChild(deck, "audioMixerPanelCard")
    var clockCard = findChild(deck, "clockPanelCard")
    var companionCard = findChild(deck, "companionPanelCard")
    var commandCard = findChild(deck, "moduleCard")
    verify(left !== null && center !== null)
    verify(nowPlayingCard !== null && mixerCard !== null)
    verify(clockCard !== null && companionCard !== null && commandCard !== null)

    var leftBounds = rectIn(left, deck)
    var nowPlayingBounds = rectIn(nowPlayingCard, deck)
    var mixerBounds = rectIn(mixerCard, deck)
    var clockBounds = rectIn(clockCard, deck)
    var companionBounds = rectIn(companionCard, deck)
    var commandBounds = rectIn(commandCard, deck)

    compare(leftBounds.width, deck.leftDrawerWidth + deck.innerGap, "carrier includes the reserved strip")
    compare(mixerBounds.x, leftBounds.x, "Mixer owns the far-left strip")
    compare(nowPlayingBounds.x - (mixerBounds.x + mixerBounds.width), deck.innerGap,
      "Mixer-to-Now Playing gap")
    compare(mixerBounds.width, deck.leftDrawerWidth, "Volume fills its drawer width")
    compare(nowPlayingBounds.width, deck.staticMediaWidth, "Now Playing retains its static width")
    compare(left.dismissInset, deck.innerGap, "the extra carrier strip owns dismissal")
    compare(leftBounds.x + leftBounds.width, nowPlayingBounds.x,
      "the dismissal strip must end where static Now Playing begins")
    verify(Math.abs(clockBounds.x - (nowPlayingBounds.x + nowPlayingBounds.width) - deck.innerGap) <= 0.5,
      "Now Playing-to-center gap must be exactly one innerGap")

    compare(mixerBounds.height, nowPlayingBounds.height, "Volume and Now Playing span the deck height")
    compare(companionBounds.y - (clockBounds.y + clockBounds.height), deck.innerGap,
      "Clock-to-Weather gap")
    compare(commandBounds.x - (clockBounds.x + clockBounds.width), deck.innerGap,
      "center-to-Command Center gap")
    compare(deck.width - (commandBounds.x + commandBounds.width), deck.outerGap,
      "Command Center right edge")
  }

  function test_scaledDeckKeepsStaticMediaAndFullSizeCenterControls() {
    var deck = createDeck(1600, 450)
    deck.setOpenDrawer("left", "test:scaled-balance")
    wait(260)

    var center = findChild(deck, "deckCenterCanvas")
    var nowPlayingCard = findChild(deck, "nowPlayingPanelCard")
    var mixerCard = findChild(deck, "audioMixerPanelCard")
    var clockCard = findChild(deck, "clockPanelCard")
    var commandCard = findChild(deck, "moduleCard")
    var command = findWhere(commandCard, function(item) {
      return item.useThreeColumns !== undefined && item.contentScale !== undefined
    })
    var weather = findWhere(deck, function(item) {
      return item.effectiveDetail !== undefined && item.showDetailedMetrics !== undefined
    })
    verify(center !== null && nowPlayingCard !== null && mixerCard !== null)
    verify(clockCard !== null && commandCard !== null && command !== null && weather !== null)

    compare(mixerCard.width, deck.leftDrawerWidth)
    compare(nowPlayingCard.width, deck.staticMediaWidth)
    verify(mixerCard.width < nowPlayingCard.width, "collapsed Volume stays a narrow strip")
    compare(mixerCard.height, deck.usableHeight)
    compare(nowPlayingCard.height, deck.usableHeight)
    verify(Math.abs(clockCard.width - commandCard.width) <= 1,
      "Clock/Weather and Command Center should share the remaining width evenly")
    compare(command.contentScale, 1, "Command Center controls must remain full-size")
    verify(weather.width >= 350)
    compare(weather.showDetailedMetrics, true,
      "Weather should regain metrics after borrowing unused Command Center width")
    grabImage(deck).save("/tmp/omadeck-media-vertical-collapsed.png")
  }

  function test_rightmostMixerSliderDragStaysWithSlider() {
    var deck = createDeck()
    deck.setOpenDrawer("left", "test:slider")
    wait(260)
    var mixer = findChild(deck, "audioMixerPresenter")
    var slider = findChild(mixer, "verticalVolumeTrack:output")
    verify(slider !== null && slider.height > 0)
    var before = Pw.Pipewire.defaultAudioSink.audio.volume

    mousePress(slider, slider.width / 2, slider.height * 0.8)
    mouseMove(slider, slider.width / 2, slider.height * 0.1, 80)
    mouseRelease(slider, slider.width / 2, slider.height * 0.1)
    wait(0)

    verify(Pw.Pipewire.defaultAudioSink.audio.volume > before)
    compare(deck.openDrawer, "left", "slider drag must not trigger reverse dismissal")
  }

  function test_reverseSwipeFromDedicatedStripDismissesLeftDrawer() {
    var deck = createDeck()
    deck.setOpenDrawer("left", "test:strip")
    wait(260)
    var left = findChild(deck, "leftVolumeDrawer")
    var reverseSwipe = findByProperty(left, "reverse", true)
    verify(reverseSwipe !== null)
    compare(reverseSwipe.width, left.dismissInset)

    mousePress(reverseSwipe, reverseSwipe.width / 2, reverseSwipe.height / 2)
    mouseMove(reverseSwipe, reverseSwipe.width / 2 - 20, reverseSwipe.height / 2, 40)
    mouseMove(reverseSwipe, reverseSwipe.width / 2 - 80, reverseSwipe.height / 2, 80)
    mouseRelease(reverseSwipe, reverseSwipe.width / 2 - 80, reverseSwipe.height / 2)
    wait(260)

    compare(deck.openDrawer, "")
    compare(deck.reservedLeft, 0)
  }

  function test_pointerCloseAffordanceStaysInsideDedicatedStrip() {
    var deck = createDeck()
    deck.setOpenDrawer("left", "test:pointer-close")
    wait(260)
    var left = findChild(deck, "leftVolumeDrawer")
    var mixerCard = findChild(deck, "audioMixerPanelCard")
    var closeButton = findByProperty(left, "tooltipText", "Close drawer")
    verify(left !== null && mixerCard !== null && closeButton !== null)
    left.pointerRevealed = true
    wait(0)

    var cardBounds = rectIn(mixerCard, deck)
    var buttonBounds = rectIn(closeButton, deck)
    var carrierBounds = rectIn(left, deck)
    verify(buttonBounds.x >= cardBounds.x + cardBounds.width,
      "pointer close target must not cross into Media card controls")
    verify(buttonBounds.x + buttonBounds.width <= carrierBounds.x + carrierBounds.width,
      "pointer close target must remain in the carrier")

    mouseClick(closeButton, closeButton.width / 2, closeButton.height / 2)
    wait(260)
    compare(deck.openDrawer, "")
  }

  function test_pointerTransportTargetsTheMediaService() {
    mediaFixture.actions = []
    playerFixture.seeks = []
    var deck = createDeck()
    wait(100)
    var presenter = findChild(deck, "nowPlayingPresenter")
    verify(presenter !== null)

    compare(presenter.hasPlayer, true)
    clickItem(presenter, findByProperty(presenter, "iconText", "󰏤"))
    clickItem(presenter, findByProperty(presenter, "iconText", "󰒮"))
    clickItem(presenter, findChild(presenter, "seekBackwardControl"))
    clickItem(presenter, findChild(presenter, "seekForwardControl"))
    clickItem(presenter, findByProperty(presenter, "iconText", "󰒭"))
    compare(JSON.stringify(mediaFixture.actions), JSON.stringify(["playPause", "previous", "next"]))
    compare(JSON.stringify(playerFixture.seeks), JSON.stringify([-10, 10]))
    presenter.seekTo(95)
    compare(playerFixture.position, 95)
  }

  function test_mixerWrappersRevealOnlyUsefulVerticalControlsInsideCard() {
    var deck = createDeck()
    deck.setMediaCompact(true)
    wait(260)
    var mixer = findChild(deck, "audioMixerPresenter")
    var mixerCard = findChild(deck, "audioMixerPanelCard")
    verify(mixer !== null)
    verify(mixerCard !== null)
    compare(mixer.compact, true)
    var collapsedDrawerWidth = deck.leftDrawerWidth
    var expandButton = findChild(mixer, "mixerExpandButton")
    verify(expandButton !== null)

    clickItem(deck, expandButton)
    wait(300)
    compare(mixer.compact, false)
    compare(mixer.displayStreams.length, 4)
    verify(deck.leftDrawerWidth > collapsedDrawerWidth,
      "expanding Volume must reserve room for its revealed controls")
    verify(deck.leftDrawerWidth <= Math.round(deck.usableWidth * 0.46))
    var output = findChild(mixer, "verticalVolume:output")
    var microphone = findChild(mixer, "verticalVolume:mic")
    var media = findChild(mixer, "verticalVolume:media")
    var games = findChild(mixer, "verticalVolume:games")
    verify(output !== null && output.width >= 48)
    verify(microphone !== null && microphone.width >= 48)
    verify(media !== null && media.width >= 48)
    verify(games !== null && games.width === 0,
      "inactive categories must not consume mixer width")
    compare(expandButton.width, 32,
      "expanded toggle should be a narrow physical-touch chevron at 1.6x scale")
    verify(expandButton.height >= 48)

    for (var control of [output, microphone, media, expandButton]) {
      var origin = control.mapToItem(mixerCard, 0, 0)
      verify(origin.x >= 0 && origin.y >= 0)
      verify(origin.x + control.width <= mixerCard.width)
      verify(origin.y + control.height <= mixerCard.height)
    }

    clickItem(deck, expandButton)
    wait(300)
    compare(mixer.compact, true)
    compare(deck.leftDrawerWidth, collapsedDrawerWidth,
      "a second tap contracts Volume back to its narrow strip")
  }

  function test_scaledDeckMixerCategoryControlAdjustsEverySource() {
    var deck = createDeck(1600, 450)
    deck.setOpenDrawer("left", "test:expanded-mixer")
    deck.setMediaCategory("media")
    wait(300)

    var mixer = findChild(deck, "audioMixerPresenter")
    var mediaControl = findChild(mixer, "verticalVolume:media")
    var mediaTrack = findChild(mixer, "verticalVolumeTrack:media")
    verify(mixer !== null && mediaControl !== null && mediaTrack !== null)
    verify(mediaControl.width >= 48 && mediaTrack.height > 0)
    var before = fixtureStreams.map(function(stream) { return stream.audio.volume })

    mousePress(mediaTrack, mediaTrack.width / 2, mediaTrack.height * 0.8)
    mouseMove(mediaTrack, mediaTrack.width / 2, mediaTrack.height * 0.1, 80)
    mouseRelease(mediaTrack, mediaTrack.width / 2, mediaTrack.height * 0.1)
    wait(0)

    for (var index = 0; index < fixtureStreams.length; index++)
      verify(fixtureStreams[index].audio.volume > before[index], "source " + index)
    wait(300)
    grabImage(deck).save("/tmp/omadeck-media-vertical-expanded.png")
  }

  function test_allExpandedCategoryControlsFitTheFullHeightVolumePanel() {
    var deck = createDeck(1600, 450)
    var categoryNames = ["Firefox", "Steam Game", "Discord", "System Audio"]
    var categoryStreams = []
    for (var index = 0; index < categoryNames.length; index++) {
      var streamAudio = createTemporaryObject(audioComponent, testCase, {
        volume: 0.35 + index * 0.1
      })
      categoryStreams.push(createTemporaryObject(nodeComponent, testCase, {
        name: "category-stream-" + index,
        description: categoryNames[index],
        isStream: true,
        isSink: true,
        type: "Stream/Output/Audio",
        audio: streamAudio,
        properties: ({ "application.name": categoryNames[index] })
      }))
    }
    Pw.Pipewire.nodes.values = categoryStreams
    deck.setMediaCategory("media")
    wait(600)

    var mixer = findChild(deck, "audioMixerPresenter")
    var mixerCard = findChild(deck, "audioMixerPanelCard")
    var nowPlayingCard = findChild(deck, "nowPlayingPanelCard")
    verify(mixer !== null && mixerCard !== null && nowPlayingCard !== null)
    compare(mixer.activeCategoryCount, 4)
    compare(mixer.expandedSliderCount, 6)
    verify(deck.leftDrawerWidth <= Math.round(deck.usableWidth * 0.46))
    compare(nowPlayingCard.width, deck.staticMediaWidth,
      "expanded Volume must not resize static Now Playing")

    for (var controlId of ["output", "mic", "media", "games", "voice", "other"]) {
      var control = findChild(mixer, "verticalVolume:" + controlId)
      var track = findChild(mixer, "verticalVolumeTrack:" + controlId)
      verify(control !== null && track !== null, controlId)
      verify(control.width >= 48, controlId + " width")
      verify(track.width >= 48 && track.height >= 250, controlId + " full-height track")
      var origin = control.mapToItem(mixerCard, 0, 0)
      verify(origin.x >= 0 && origin.y >= 0, controlId + " top-left")
      verify(origin.x + control.width <= mixerCard.width, controlId + " right")
      verify(origin.y + control.height <= mixerCard.height, controlId + " bottom")
    }
    grabImage(deck).save("/tmp/omadeck-media-all-categories.png")
  }

  function test_narrowNowPlayingHandlesNoPlayerAndLongMetadata() {
    mediaFixture.activePlayer = null
    var deck = createDeck(1600, 450)
    wait(100)

    var presenter = findChild(deck, "nowPlayingPresenter")
    var nowPlayingCard = findChild(deck, "nowPlayingPanelCard")
    var artwork = findChild(deck, "nowPlayingArtwork")
    var overlay = findChild(deck, "nowPlayingMetadataOverlay")
    var controlBand = findChild(deck, "nowPlayingControlBand")
    var controls = findChild(deck, "nowPlayingControls")
    var timeline = findChild(deck, "nowPlayingTimeline")
    verify(presenter !== null && nowPlayingCard !== null)
    verify(artwork !== null && overlay !== null && controlBand !== null)
    verify(controls !== null && timeline !== null)
    compare(presenter.hasPlayer, false)
    compare(findChild(presenter, "seekBackwardControl").visible, true)
    compare(findChild(presenter, "seekForwardControl").visible, true)
    compare(findChild(presenter, "seekBackwardControl").enabled, false)
    compare(findChild(presenter, "seekForwardControl").enabled, false)
    for (var item of [artwork, overlay, controlBand, controls, timeline]) {
      var origin = item.mapToItem(nowPlayingCard, 0, 0)
      verify(origin.x >= 0 && origin.y >= 0)
      verify(origin.x + item.width <= nowPlayingCard.width)
      verify(origin.y + item.height <= nowPlayingCard.height)
    }

    var longTitle = "A deliberately long fixture title that must elide inside the narrow Now Playing card"
    playerFixture.trackTitle = longTitle
    mediaFixture.activePlayer = playerFixture
    wait(1)
    var title = findByProperty(presenter, "text", longTitle)
    verify(title !== null)
    compare(title.maximumLineCount, 1)
    compare(title.elide, Text.ElideRight)
    verify(title.width <= overlay.width)
    playerFixture.trackTitle = "Fixture Song"
  }

  function test_twentyLifecycleAndDrawerCyclesKeepOnePresenterPerPanel() {
    var deck = createDeck()
    deck.layoutController = layoutFixture
    var host = findChild(deck, "staticMediaPanel")
    var presenter = findChild(deck, "nowPlayingPresenter")
    var mixer = findChild(deck, "audioMixerPresenter")
    var positionTimers = []
    var snapshotTimers = []
    collectByObjectName(deck, "nowPlayingPositionTimer", positionTimers)
    collectByObjectName(deck, "audioSnapshotTimer", snapshotTimers)
    verify(host !== null)
    verify(presenter !== null)
    verify(mixer !== null)
    compare(positionTimers.length, 1)
    compare(snapshotTimers.length, 1)
    var stateBefore = JSON.stringify({
      bytes: layoutFixture.layoutBytes,
      topology: layoutFixture.topology,
      schema: layoutFixture.schemaVersion,
      mutations: layoutFixture.mutationCalls
    })

    for (var cycle = 0; cycle < 20; cycle++) {
      if (cycle % 3 === 0) deck.setMediaCompact(true)
      else deck.setMediaCategory(cycle % 2 === 0 ? "media" : "")
      deck.setOpenDrawer(cycle % 2 === 0 ? "left" : "", "test:cycle:" + cycle)
      mediaFixture.activePlayer = cycle % 2 === 0 ? playerFixture : null
      Pw.Pipewire.nodes.values = cycle % 2 === 0 ? fixtureStreams : []
      wait(120)
      compare(findChild(deck, "staticMediaPanel"), host)
      compare(findChild(deck, "nowPlayingPresenter"), presenter)
      compare(findChild(deck, "audioMixerPresenter"), mixer)
      compare(mixer.displayStreams.length, cycle % 2 === 0 ? 4 : 0)
    }

    deck.setOpenDrawer("left", "test:dismiss")
    wait(230)
    var left = findChild(deck, "leftVolumeDrawer")
    verify(left !== null)
    left.dismissRequested()
    wait(260)
    compare(deck.openDrawer, "")
    compare(deck.reservedLeft, 0)
    compare(JSON.stringify({
      bytes: layoutFixture.layoutBytes,
      topology: layoutFixture.topology,
      schema: layoutFixture.schemaVersion,
      mutations: layoutFixture.mutationCalls
    }), stateBefore)
  }

  Component {
    id: deckSurfaceComponent
    Components.DeckSurface {}
  }

  Component {
    id: audioComponent
    QtObject {
      property real volume: 0
      property bool muted: false
    }
  }

  Component {
    id: nodeComponent
    QtObject {
      property string name: ""
      property string description: ""
      property string type: ""
      property bool ready: true
      property bool isStream: false
      property bool isSink: false
      property var audio: null
      property var properties: ({})
    }
  }

  QtObject {
    id: shellFixture
    property var shellConfig: ({
      bar: { position: "top", transparent: false },
      idle: { screensaver: 150, lock: 300 }
    })
    property var bar: barFixture
    property int shellMutationCalls: 0
    property string lastSummonedId: ""
    property string lastSummonedPayload: ""

    function serviceFor(serviceId) { return serviceId === "omarchy.media" ? mediaFixture : null }
    function firstPartyServiceFor(serviceId) {
      if (serviceId === "omarchy.notifications") return notificationFixture
      if (serviceId === "omarchy.nightlight") return nightlightFixture
      if (serviceId === "omarchy.idle") return idleFixture
      return null
    }
    function mutateShellConfig(mutator) {
      var copy = JSON.parse(JSON.stringify(shellConfig))
      mutator(copy)
      shellConfig = copy
      barFixture.position = copy.bar.position
      barFixture.requestedTransparent = copy.bar.transparent
      idleFixture.screensaverTimeoutSeconds = copy.idle.screensaver
      idleFixture.lockTimeoutSeconds = copy.idle.lock
      shellMutationCalls++
    }
    function summon(pluginId, payload) {
      lastSummonedId = pluginId
      lastSummonedPayload = payload
      return true
    }
    function resetPreferencesState() {
      shellConfig = {
        bar: { position: "top", transparent: false },
        idle: { screensaver: 150, lock: 300 }
      }
      barFixture.position = "top"
      barFixture.requestedTransparent = false
      idleFixture.screensaverTimeoutSeconds = 150
      idleFixture.lockTimeoutSeconds = 300
      shellMutationCalls = 0
      lastSummonedId = ""
      lastSummonedPayload = ""
    }
  }

  QtObject {
    id: barFixture
    property string position: "top"
    property bool requestedTransparent: false
  }

  QtObject {
    id: notificationFixture
    property bool doNotDisturb: false
    function setDoNotDisturb(value) { doNotDisturb = value }
  }

  QtObject {
    id: nightlightFixture
    property bool stateLoaded: true
    property bool enabled: false
    property int applyCalls: 0
    function setNightlight(value) { enabled = value; applyCalls++ }
  }

  QtObject {
    id: idleFixture
    property bool stayAwakeStateLoaded: true
    property bool idleEnabled: true
    property int screensaverTimeoutSeconds: 150
    property int lockTimeoutSeconds: 300
    property int applyCalls: 0
    function setIdleEnabled(value) { idleEnabled = value; applyCalls++ }
  }

  QtObject {
    id: hardwareFixture
    property bool loaded: true
    property string targetScreen: "DP-3"
    property string primaryMonitor: "DP-1"
    property var touchDeviceNames: ["WCH.CN", "XENEON"]
    property var availableScreenNames: ["DP-1", "DP-3"]
    property var availableTouchDeviceNames: ["wch.cn TouchScreen", "XENEON Edge Touch"]
    property string selectedTouchDeviceName: "wch.cn TouchScreen"
    property int applyCalls: 0
    function setTargetScreen(value) { targetScreen = value; applyCalls++; return true }
    function setPrimaryMonitor(value) { primaryMonitor = value; applyCalls++; return true }
    function setTouchDevice(value) {
      touchDeviceNames = [value]
      selectedTouchDeviceName = value
      applyCalls++
      return true
    }
    function reset() {
      targetScreen = "DP-3"
      primaryMonitor = "DP-1"
      touchDeviceNames = ["WCH.CN", "XENEON"]
      selectedTouchDeviceName = "wch.cn TouchScreen"
      applyCalls = 0
    }
  }

  QtObject {
    id: mediaFixture
    property var activePlayer: playerFixture
    property var actions: []
    function runAction(action, argument) { actions.push(action) }
  }

  QtObject {
    id: playerFixture
    property string trackTitle: "Fixture Song"
    property string trackArtist: "Fixture Artist"
    property string trackAlbum: "Fixture Album"
    property string identity: "Fixture Player"
    property string trackArtUrl: ""
    property var metadata: ({})
    property bool isPlaying: true
    property bool canSeek: true
    property bool positionSupported: true
    property bool lengthSupported: true
    property bool canGoPrevious: true
    property bool canGoNext: true
    property real position: 42
    property real length: 180
    property var seeks: []
    function seek(seconds) { seeks.push(seconds) }
  }

  QtObject {
    id: layoutFixture
    property int revision: 0
    property bool editMode: false
    property string selectedPath: ""
    property string layoutBytes: "fixture-layout-v1"
    property string topology: "split(module:clock,module:command-center)"
    property int schemaVersion: 1
    property int mutationCalls: 0
    function nodeAt(path) {
      var clock = { type: "module", moduleId: "clock" }
      var command = { type: "module", moduleId: "command-center" }
      if (path === "") return {
        type: "split", orientation: "horizontal", ratio: 0.36,
        first: clock, second: command
      }
      if (path === "first") return clock
      if (path === "second") return command
      return null
    }
    function beginEdit(path) { selectedPath = path; editMode = true }
    function selectOrSwap(path) { selectedPath = path; mutationCalls++ }
    function swap(first, second) { mutationCalls++ }
    function setRatio(path, ratio) { mutationCalls++ }
  }

  QtObject {
    id: appearanceFixture
    property string clockStyle: "hero"
    property bool use24Hour: false
    property bool showSeconds: false
    property bool showWeather: true
    property string weatherStyle: "scene"
    property string weatherDetail: "standard"
    property string temperatureUnit: "fahrenheit"
    property string lastKey: ""
    property var lastValue: null
    function reset() {
      clockStyle = "hero"
      use24Hour = false
      showSeconds = false
      showWeather = true
      weatherStyle = "scene"
      weatherDetail = "standard"
      temperatureUnit = "fahrenheit"
      lastKey = ""
      lastValue = null
    }
    function setOption(key, value) {
      lastKey = key
      lastValue = value
      appearanceFixture[key] = value
      return true
    }
  }

  QtObject {
    id: launcherFixture
    property int revision: 0
    property var entryIds: ["terminal", "browser", "files"]
    property var catalog: [
      { id: "terminal", kind: "application", desktopId: "terminal", name: "Terminal", iconText: "T", classes: ["terminal"] },
      { id: "browser", kind: "application", desktopId: "browser", name: "Browser", iconText: "B", classes: ["browser"] },
      { id: "files", kind: "application", desktopId: "files", name: "Files", iconText: "F", classes: ["files"] },
      { id: "lock", kind: "shortcut", action: "lock", name: "Lock", iconText: "L" }
    ]
    function reset() { entryIds = ["terminal", "browser", "files"]; revision++ }
    function entryForId(id) {
      for (var index = 0; index < catalog.length; index++) if (catalog[index].id === id) return catalog[index]
      return null
    }
    function entries() { return entryIds.map(function(id) { return entryForId(id) }) }
    function availableEntries() { return catalog.filter(function(entry) { return entryIds.indexOf(entry.id) === -1 }) }
    function add(id) { if (entryIds.indexOf(id) === -1) entryIds = entryIds.concat([id]); revision++ }
    function remove(id) { entryIds = entryIds.filter(function(value) { return value !== id }); revision++ }
    function move(id, delta) {
      var from = entryIds.indexOf(id)
      var to = from + delta
      if (from < 0 || to < 0 || to >= entryIds.length) return
      var next = entryIds.slice()
      var temporary = next[from]
      next[from] = next[to]
      next[to] = temporary
      entryIds = next
      revision++
    }
  }

  QtObject {
    id: weatherFixture
    property int refreshCount: 0
    property bool loading: false
    property string error: ""
    property var current: ({ ok: true, condition: "clear", conditionLabel: "Clear", isDay: true,
      temperatureC: 18, feelsLikeC: 18, windKph: 5, humidity: 40, highC: 20, lowC: 12,
      location: "Portland", forecast: [] })
    function refresh(trigger) { refreshCount++ }
  }

  QtObject {
    id: timerFixture
    property bool loaded: true
    property string status: "idle"
    property string remainingText: "5:00"
    property real progress: 0
    property string selectedSoundName: "Complete"
    property bool soundSettingsLoaded: true
    property string selectedSoundId: "complete"
    property int previewCalls: 0
    function resetPreferences() { selectedSoundId = "complete"; previewCalls = 0 }
    function selectSoundId(value) { selectedSoundId = value; return true }
    function start(hours, minutes) { status = "active"; return { ok: true } }
    function stopPreview() {}
    function selectPreviousSound() {}
    function selectNextSound() {}
    function previewSelectedSound() { previewCalls++; return true }
    function pause() { status = "paused" }
    function resume() { status = "active" }
    function add(minutes) {}
    function restart() { status = "active" }
    function cancel() { status = "idle" }
    function dismiss() { status = "idle" }
  }
}
