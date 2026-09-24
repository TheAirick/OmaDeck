import QtQuick
import QtTest
import Quickshell.Services.Pipewire as Pw
import Quickshell.Services.Mpris as Mp
import Quickshell.Hyprland as Hl
import "../../components" as Components
import "../../services" as Stores

TestCase {
  id: testCase
  name: "DeckSurfaceMediaPanels"
  when: windowShown

  width: 2700
  height: 800
  visible: true
  property var fixtureStreams: []

  function init() {
    monitorFixture.requests = []
    monitorFixture.showControls = true
    Hl.Hyprland.toplevels.values = []
    Hl.Hyprland.workspaces.values = []
    Hl.Hyprland.monitors.values = []
    Hl.Hyprland.focusedWorkspace = null
    Hl.Hyprland.activeToplevel = null
    Hl.Hyprland.requests = []
    lockRegistryFixture.enabledLockId = "omarchy.lock"
    lockFixture.locked = false
    lockFixture.strandedLockResolved = true
    lockFixture.strandedLock = false
    layoutFixture.layout = layoutFixture.defaultLayout()
    layoutFixture.revision++
    layoutFixture.editMode = false
    layoutFixture.editSnapshot = null
    layoutFixture.selectedPath = ""
    layoutFixture.saveError = ""
    launcherFixture.saveError = ""
    layoutFixture.retryCalls = 0
    launcherFixture.retryCalls = 0
    mediaFixture.activePlayer = playerFixture
    shellFixture.mediaOverride = null
    Mp.Mpris.players.values = []
    var sinkAudio = createTemporaryObject(audioComponent, testCase, { volume: 0.7 })
    var sourceAudio = createTemporaryObject(audioComponent, testCase, { volume: 0.5 })
    var sink = createTemporaryObject(nodeComponent, testCase, {
      id: 31, name: "fixture-sink", description: "QR65 speakers", isSink: true, audio: sinkAudio
    })
    var source = createTemporaryObject(nodeComponent, testCase, {
      id: 32, name: "fixture-source", description: "Alias Pro mic", audio: sourceAudio
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
    Pw.Pipewire.nodes.values = streams.concat([sink, source])
  }

  function createDeck(width, height, mediaShell) {
    var deck = createTemporaryObject(deckSurfaceComponent, testCase, {
      width: width || 2560,
      height: height || 720,
      targetScreen: "DP-3",
      shell: mediaShell || shellFixture,
      layoutController: layoutFixture,
      appearanceController: appearanceFixture,
      launcherController: launcherFixture,
      hardwareController: hardwareFixture,
      monitorInputController: monitorFixture,
      weatherController: weatherFixture,
      timerController: timerFixture
    })
    verify(deck !== null)
    return deck
  }

  function test_customizeMovesEveryPanelAndCancelRestores() {
    var deck = createDeck()
    var original = JSON.stringify(layoutFixture.layout)
    deck.showPreferences("omadeck")
    wait(300)
    var edit = findChild(deck, "preferencesEditDashboard")
    verify(edit !== null)
    mouseClick(edit, edit.width / 2, edit.height / 2)
    wait(300)
    verify(deck.customizing)
    compare(deck.openOverlayName, "")
    for (var id of ["media", "clock", "weather", "command-center"]) {
      var tile = findChild(deck, "dashboardTile-" + id)
      verify(tile !== null && tile.width > 0 && tile.height > 0, id)
    }
    // Content is inert while editing, even the monitor-switching row.
    var inputs = findChild(deck, "monitorInputModule")
    verify(!inputs.enabled)
    mouseClick(inputs, inputs.width * 0.75, inputs.height / 2)
    compare(monitorFixture.requests.length, 0)
    layoutFixture.selectedPath = ""
    var media = findChild(deck, "dashboardTile-media")
    var clock = findChild(deck, "dashboardTile-clock")
    var oldMediaPath = media.path, oldClockPath = clock.path
    mouseClick(media, media.width / 2, media.height / 2)
    mouseClick(clock, clock.width / 2, clock.height / 2)
    wait(100)
    compare(layoutFixture.nodeAt(oldMediaPath).moduleId, "clock")
    compare(layoutFixture.nodeAt(oldClockPath).moduleId, "media")
    // Changing topology recreates panels but retains the single service owner.
    layoutFixture.moveModule("weather", "command-center", "bottom")
    wait(100)
    verify(findChild(deck, "dashboardTile-weather") !== null)
    verify(findChild(deck, "staticMediaPanel").media === deck.dashboardMedia)
    verify(deck.timerCompanion !== null)
    verify(JSON.stringify(layoutFixture.layout) !== original)
    var cancel = findChild(deck, "cancelCustomize")
    mouseClick(cancel, cancel.width / 2, cancel.height / 2)
    wait(100)
    compare(JSON.stringify(layoutFixture.layout), original)
    verify(!deck.customizing)
    verify(findChild(deck, "monitorInputModule").enabled)
    deck.openTimerPanel()
    verify(deck.timerPanelOpen, "Clock can still reach the Weather/Timer panel after moving")
  }

  function test_customizeDragPlacesPanelAndResizesWithTouch() {
    var deck = createDeck()
    deck.beginCustomize()
    wait(300)
    var original = JSON.stringify(layoutFixture.layout)
    var media = findChild(deck, "dashboardTile-media")
    var command = findChild(deck, "dashboardTile-command-center")
    var start = media.mapToItem(deck, media.width / 2, media.height / 2)
    var end = command.mapToItem(deck, command.width / 2, command.height - 35)
    var gesture = touchEvent(deck)
    gesture.press(0, deck, start.x, start.y).commit()
    for (var i = 1; i <= 12; i++) {
      gesture.move(0, deck, start.x + (end.x - start.x) * i / 12,
        start.y + (end.y - start.y) * i / 12).commit()
      wait(20)
    }
    verify(media.dragging, "touch motion engages the module drag")
    grabImage(deck).save("/tmp/omadeck-customize-drag.png")
    verify(command.dropEdge !== "", "destination receives the drag: " + command.dropEdge)
    gesture.release(0, deck, end.x, end.y).commit()
    wait(200)
    verify(JSON.stringify(layoutFixture.layout) !== original, "touch drop changes topology")
    media = findChild(deck, "dashboardTile-media")
    command = findChild(deck, "dashboardTile-command-center")
    var mediaRect = rectIn(media, deck), commandRect = rectIn(command, deck)
    verify(mediaRect.y > commandRect.y, "Now Playing moves below Command Center")
    compare(mediaRect.x, commandRect.x)
    var divider = findChild(deck, "layoutDivider-")
    verify(divider.width >= 48)
    var oldRatio = layoutFixture.layout.root.ratio
    var point = divider.mapToItem(deck, divider.width / 2, divider.height / 2)
    gesture.press(0, deck, point.x, point.y).commit()
    for (var step = 1; step <= 6; step++) {
      gesture.move(0, deck, point.x + step * 20, point.y).commit()
      wait(20)
    }
    gesture.release(0, deck, point.x + 120, point.y).commit()
    wait(100)
    verify(layoutFixture.layout.root.ratio > oldRatio, "touch divider increases left share")
    verify(Math.abs((layoutFixture.layout.root.ratio - oldRatio)
      * (deck.usableWidth - deck.innerGap) - 120) < 3, "divider follows the finger without drift")
    var horizontalDivider = findChild(deck, "layoutDivider-second")
    verify(horizontalDivider !== null && horizontalDivider.height >= 48)
    var priorHeight = findChild(deck, "dashboardTile-command-center").height
    point = horizontalDivider.mapToItem(deck, horizontalDivider.width / 2, horizontalDivider.height / 2)
    gesture.press(0, deck, point.x, point.y).commit()
    for (var row = 1; row <= 5; row++) {
      gesture.move(0, deck, point.x, point.y + row * 10).commit()
      wait(20)
    }
    gesture.release(0, deck, point.x, point.y + 50).commit()
    wait(100)
    verify(Math.abs(findChild(deck, "dashboardTile-command-center").height - priorHeight - 50) < 3,
      "horizontal divider resizes panel height without drift")
    var edited = JSON.stringify(layoutFixture.layout)
    var done = findChild(deck, "finishCustomize")
    mouseClick(done, done.width / 2, done.height / 2)
    compare(JSON.stringify(layoutFixture.layout), edited)
    verify(!deck.customizing)
    grabImage(deck).save("/tmp/omadeck-customized-layout.png")
  }

  function test_overlayCloseFitsHeader() {
    var deck = createDeck(1600, 450)
    deck.openOverlay("overview")
    wait(300)
    var overlay = findChild(deck, "omadeckOverviewOverlay")
    var button = findChild(overlay, "closeOverviewOverlay")
    var content = findChild(overlay, "deckCardContent")
    verify(button !== null && content !== null)
    verify(button.width >= 48 && button.height >= 48)
    var buttonPos = button.mapToItem(overlay, 0, 0)
    var contentPos = content.mapToItem(overlay, 0, 0)
    verify(buttonPos.y + button.height <= contentPos.y, "close control fits above content")
    verify(buttonPos.y >= 0, "close touch target remains inside the overlay")
    verify(contentPos.y <= 64, "compact header leaves room for workspace cards")
    compare(button.bordered, false)
    mouseClick(button, button.width / 2, button.height / 2)
    compare(deck.openOverlayName, "")
  }

  function test_monitorPreferencesRoute() {
    var deck = createDeck(1600, 450)
    deck.showPreferences("monitors")
    compare(deck.openOverlayName, "preferences")
    compare(findChild(deck, "preferencesPresenter").selectedCategory, "monitors")
    deck.showPreferences("unknown")
    compare(findChild(deck, "preferencesPresenter").selectedCategory, "monitors")
  }

  function test_monitorSetupRouteOpensReadOnlyGuide() {
    var deck = createDeck(1600, 450)
    deck.showPreferences("monitor-setup")
    wait(300)
    compare(deck.openOverlayName, "preferences")
    var preferences = findChild(deck, "monitorInputPreferences")
    compare(preferences.setupStep, "computer")
    compare(findChild(preferences, "monitorSetupPrimary").text, "Continue")
    verify(!deck.dashboardInputAllowed)
    grabImage(findChild(deck, "preferencesOverlay")).save("/tmp/omadeck-monitor-setup-ready.png")
  }

  function test_overlaysBlockMonitorInputBehindThem_data() {
    var rows = []
    for (var overlay of ["overview", "notifications", "preferences"])
      for (var touch of [false, true]) rows.push({ tag: overlay + (touch ? "-touch" : "-mouse"), overlay: overlay, touch: touch })
    return rows
  }

  function test_overlaysBlockMonitorInputBehindThem(data) {
    Hl.Hyprland.toplevels.values = [{ address: "abc", title: "Fixture", lastIpcObject: { "class": "Fixture" },
      workspace: { id: -98, name: "special:scratchpad" }, monitor: { name: "DP-1" } }]
    var deck = createDeck(1600, 450)
    wait(100)
    var input = findChild(deck, "monitorInputModule")
    verify(input !== null)
    // Monitor switching is recorded by a controller double; no hardware command runs.
    var position = input.mapToItem(deck, input.width * 0.75, input.height / 2)
    function tap() {
      if (data.touch) {
        var gesture = touchEvent(deck)
        gesture.press(0, deck, position.x, position.y).commit()
        gesture.release(0, deck, position.x, position.y).commit()
      } else mouseClick(deck, position.x, position.y)
    }
    deck.openOverlay(data.overlay)
    tap()
    compare(monitorFixture.requests.length, 0, "dashboard blocked immediately on opening")
    wait(300)
    if (data.overlay === "overview") {
      var panel = findChild(deck, "scratchpadPanel")
      var local = panel.mapFromItem(deck, position.x, position.y)
      verify(local.x > 0 && local.x < panel.width && local.y > 0 && local.y < panel.height,
        "reproduce scratchpad directly above the monitor input button")
    }
    var requestsBefore = Hl.Hyprland.requests.length
    tap()
    compare(monitorFixture.requests.length, 0, "overlay taps cannot reach monitor input")
    compare(deck.commandCenterPage, "home")
    if (data.overlay === "overview") {
      compare(Hl.Hyprland.requests.length, requestsBefore + 1)
      compare(Hl.Hyprland.requests[requestsBefore], 'hl.dsp.workspace.toggle_special("scratchpad")')
    }
    deck.closeOverlay()
    wait(60)
    tap()
    compare(monitorFixture.requests.length, 0, "closing animation still blocks dashboard taps")
    wait(300)
    verify(deck.dashboardInputAllowed)
    tap()
    compare(monitorFixture.requests[0].code, "13", "dashboard input works again after dismissal")
  }

  function test_openingOverlayCancelsDashboardPress() {
    var deck = createDeck(1600, 450)
    wait(100)
    var input = findChild(deck, "monitorInputModule")
    var position = input.mapToItem(deck, input.width * 0.75, input.height / 2)
    mousePress(deck, position.x, position.y)
    deck.openOverlay("overview")
    verify(!input.enabled)
    mouseRelease(deck, position.x, position.y)
    compare(monitorFixture.requests.length, 0)
    deck.openOverlay("preferences")
    wait(300)
    compare(input.enabled, false)
    verify(!findChild(deck, "omadeckOverviewOverlay").enabled)
  }

  function test_overlayCancelsCommandCenterPressAndBlocksCoveredMedia() {
    var deck = createDeck(1600, 450)
    wait(100)
    var applications = findByProperty(deck, "label", "Applications")
    var position = applications.mapToItem(deck, applications.width / 2, applications.height / 2)
    mousePress(deck, position.x, position.y)
    deck.openOverlay("overview")
    mouseRelease(deck, position.x, position.y)
    compare(deck.commandCenterPage, "home")
    wait(300)
    var play = findChild(deck, "playPauseControl")
    verify(play !== null)
    var before = mediaFixture.actions.length
    position = play.mapToItem(deck, play.width / 2, play.height / 2)
    mouseClick(deck, position.x, position.y)
    compare(mediaFixture.actions.length, before)
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

  function test_lockDisablesDeckAndUnknownRecoveryFailsClosed() {
    var deck = createDeck()
    verify(deck.interactionAllowed)
    verify(deck.contentItem.enabled)
    deck.toggleDrawer("right")
    var system = findChild(deck, "systemStatsRefreshTimer")
    verify(system.running)
    lockFixture.locked = true
    compare(deck.contentItem.enabled, false)
    compare(system.running, false)
    lockFixture.locked = false
    verify(deck.contentItem.enabled)
    lockFixture.strandedLockResolved = false
    compare(deck.contentItem.enabled, false)
    lockFixture.strandedLockResolved = true
    lockFixture.strandedLock = true
    compare(deck.contentItem.enabled, false)
    lockFixture.strandedLock = false
    verify(deck.contentItem.enabled)
    lockRegistryFixture.enabledLockId = "fixture.lock"
    compare(deck.lockServiceId, "fixture.lock")
    verify(deck.contentItem.enabled)
    lockFixture.locked = true
    compare(deck.contentItem.enabled, false)
    lockFixture.locked = false
    deck.shell = null
    compare(deck.contentItem.enabled, false)
  }

  function test_systemSnapshotsOnlyRefreshInOpenDrawer() {
    var deck = createDeck()
    var timer = findChild(deck, "systemStatsRefreshTimer")
    var process = findChild(deck, "systemStatsProcess")
    verify(!timer.running)
    verify(!process.running)
    deck.toggleDrawer("right")
    verify(timer.running)
    verify(process.running)
    deck.closeDrawer()
    verify(!timer.running)
  }

  function test_privateHostLockServiceUsesCompositorInput() {
    var deck = createDeck()
    var bridge = findChild(deck, "deckTouchBridge")
    verify(bridge.directRoutingAllowed)
    // This is the installed host's restricted PluginShellApi: no registry,
    // and serviceFor never returns authentication services.
    deck.shell = scopedShellFixture
    compare(deck.lockService, null)
    compare(bridge.directRoutingAllowed, false)
    compare(bridge.active, false)
    compare(bridge.mode, "compositor")
    verify(deck.contentItem.enabled)
    var media = findChild(deck, "staticMediaPanel")
    compare(media.hostMedia, null)
    verify(media.media !== null)
    compare(findChild(deck, "nowPlayingPresenter").playbackStatus, "No media player detected")
    wait(100)
    var preferences = findByProperty(deck, "label", "Preferences")
    clickItem(deck, preferences)
    compare(deck.openOverlayName, "preferences")
    deck.shell = shellFixture
    verify(bridge.directRoutingAllowed)
    lockFixture.locked = true
    compare(deck.contentItem.enabled, false)
  }

  function test_privateHostInputGuardControlsNativeTouchAndDeckInteraction() {
    var deck = createDeck()
    deck.shell = scopedShellFixture
    var wrapper = findChild(deck, "deckTouchBridge")
    wrapper.nativeSource = Qt.resolvedUrl("TouchBridgeFixture.qml")
    wrapper.nativeArtifactPresent = true
    tryCompare(wrapper, "nativeAvailable", true)
    wrapper.bridge.hostGuardAvailable = true
    compare(wrapper.mode, "native")
    verify(wrapper.active)
    verify(!deck.contentItem.enabled)
    wrapper.bridge.hostInputAllowed = true
    verify(deck.contentItem.enabled)
    deck.openOverlay("overview")
    verify(!findChild(deck, "deckCenterCanvas").enabled)
    compare(wrapper.window, deck.contentItem)
    verify(wrapper.window.enabled, "modal content must retain native touch input")
    verify(wrapper.active)
    wrapper.bridge.hostInputAllowed = false
    verify(!deck.contentItem.enabled)
    verify(wrapper.active)
    wrapper.bridge.hostGuardAvailable = false
    verify(!wrapper.active)
    compare(wrapper.mode, "compositor")
    verify(deck.contentItem.enabled) // compositor now owns session-lock routing
  }

  function test_saveFailuresRemainVisibleAfterEditingAndRetryTheirOwner() {
    var deck = createDeck()
    var layoutRetry = findChild(deck, "layoutSaveRetry")
    var launcherRetry = findChild(deck, "launcherSaveRetry")
    verify(layoutRetry !== null && launcherRetry !== null)
    compare(layoutRetry.visible, false)
    compare(launcherRetry.visible, false)
    layoutFixture.editMode = false
    layoutFixture.saveError = "ENOSPC"
    launcherFixture.saveError = "permission denied"
    compare(layoutRetry.visible, true)
    compare(launcherRetry.visible, true)
    verify(layoutRetry.height >= 48)
    wait(50) // allow Column's geometry polish before pointer hit testing
    clickItem(deck, layoutRetry)
    compare(layoutFixture.retryCalls, 1)
    compare(layoutRetry.visible, false)
    compare(launcherRetry.visible, true)
    wait(50)
    clickItem(deck, launcherRetry)
    compare(launcherFixture.retryCalls, 1)
    compare(launcherRetry.visible, false)
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
    compare(nowPlayingCard.width, Math.round((deck.usableWidth - deck.reservedLeft - deck.reservedRight - deck.innerGap) * 0.27))
    verify(mixerCard.y + mixerCard.height <= left.height)

    compare(deck.reservedLeft, deck.leftDrawerWidth + deck.innerGap)
    compare(center.x, deck.outerGap + deck.reservedLeft)
    compare(center.width, deck.usableWidth - deck.reservedLeft)
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
    clickItem(deck, findChild(preferences, "preferenceCategory:timer"))
    compare(findChild(preferences, "preferencesPresenter").selectedCategory, "timer")
    wait(30)
    var bellOption = findByProperty(timerSound, "text", "Bell")
    verify(bellOption !== null)
    clickItem(deck, bellOption)
    compare(timerFixture.selectedSoundId, "bell")
    var oceanOption = findByProperty(timerSound, "text", "Ocean")
    clickItem(deck, oceanOption)
    compare(timerFixture.selectedSoundId, "ocean")
    grabImage(preferences).save("/tmp/omadeck-preferences-timer.png")
    clickItem(deck, previewTimerSound)
    compare(timerFixture.previewCalls, 1)

    clickItem(deck, findChild(preferences, "preferenceCategory:omadeck"))
    wait(30)
    clickItem(deck, editDashboard)
    wait(280)
    compare(layoutFixture.editMode, true)
    compare(layoutFixture.selectedPath, "")
    compare(deck.openOverlayName, "")
  }

  function test_launcherTypingOwnsKeysOnlyInActiveUnlockedEditor() {
    var deck = createDeck()
    deck.editLauncher(true)
    wait(300)
    var preferences = findChild(deck, "preferencesPresenter")
    var editor = findChild(preferences, "launcherPreferences")
    compare(deck.launcherKeyboardRequested, false)
    editor.editField("query")
    compare(deck.launcherKeyboardRequested, true)
    lockFixture.locked = true
    compare(deck.launcherKeyboardRequested, false)
    lockFixture.locked = false
    compare(deck.launcherKeyboardRequested, true)
    preferences.selectedCategory = "timer"
    compare(deck.launcherKeyboardRequested, false)
    compare(editor.inputField, "")
    preferences.selectedCategory = "launcher"
    editor.editField("query")
    compare(deck.launcherKeyboardRequested, true)
    deck.closeOverlay()
    compare(deck.launcherKeyboardRequested, false)
    compare(editor.inputField, "")
  }

  function test_preferencesLauncherOpensAppEditorWithoutHostSettings() {
    shellFixture.resetPreferencesState()
    var deck = createDeck()
    deck.openOverlay("preferences")
    wait(280)
    var preferences = findChild(deck, "preferencesPresenter")
    clickItem(deck, findChild(preferences, "preferenceCategory:launcher"))
    compare(preferences.selectedCategory, "launcher")
    wait(30)
    verify(findChild(preferences, "launcherPreferences").visible)
    clickItem(deck, findChild(preferences, "launcherBrowseApps"))
    compare(findChild(preferences, "launcherPreferences").page, "apps")
    compare(deck.openOverlayName, "preferences")
    compare(shellFixture.shellMutationCalls, 0)
  }

  function test_preferencesHardwareSelectorsUseDetectedControllerChoices() {
    hardwareFixture.reset()
    var deck = createDeck()
    deck.openOverlay("preferences")
    wait(280)

    var preferences = findChild(deck, "preferencesPresenter")
    verify(preferences !== null)
    preferences.selectedCategory = "hardware"
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

    var unitChoice = findChild(settingsList, "preferencesTemperatureUnit")
    var completeLabel = findByProperty(unitChoice, "text", "°F")
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
    compare(nowPlayingBounds.width, Math.round((deck.usableWidth - deck.reservedLeft - deck.reservedRight - deck.innerGap) * 0.27), "Now Playing retains its configured share")
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
    compare(nowPlayingCard.width, Math.round((deck.usableWidth - deck.reservedLeft - deck.reservedRight - deck.innerGap) * 0.27))
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
    compare(playerFixture.position, 42)
    compare(JSON.stringify(playerFixture.seeks), JSON.stringify([-10, 10, 53]))
    compare(presenter.displayedPosition, 95)
  }

  function test_watchModeKeepsFullHeightVideoAndRightCompanionsWithoutSavingLayout() {
    var deck = createDeck(1600, 450)
    var before = JSON.stringify(layoutFixture.layout)
    var split = findChild(deck, "deckRootSplit")
    verify(split !== null)
    deck.watchController.videoRect = deck.watchVideoRect()
    deck.watchController.state = "playing"
    wait(100)

    var video = findChild(deck, "watchVideoRegion")
    var controls = findChild(deck, "watchControls")
    var clock = findChild(deck, "watchClockCard")
    var weather = findChild(deck, "watchWeatherCard")
    verify(video !== null && controls !== null && clock !== null && weather !== null)
    verify(video.height >= 400 && video.width >= 700)
    compare(video.x, 0)
    verify(Math.abs(video.width / video.height - 16 / 9) < 0.01)
    var commandCenter = findChild(deck, "watchCommandCenterCard")
    verify(commandCenter !== null)
    verify(commandCenter.x >= clock.mapToItem(video.parent, 0, 0).x + clock.width)
    compare(commandCenter.x + commandCenter.width, video.parent.width)
    var bar = findChild(deck, "watchControlBar")
    verify(bar.height <= 60 && bar.height < video.height * 0.15)
    compare(controls.parent, video)
    compare(controls.width, video.width)
    verify(clock.mapToItem(video.parent, 0, 0).x >= video.x + video.width)
    verify(weather.mapToItem(video.parent, 0, 0).y
      >= clock.mapToItem(video.parent, 0, 0).y + clock.height)
    compare(split.visible, false)
    compare(JSON.stringify(layoutFixture.layout), before)

    deck.watchController.returnToSource()
    wait(100)
    compare(split.visible, true)
    compare(JSON.stringify(layoutFixture.layout), before)
  }

  function test_watchFocusCentersVideoAndRestoresCompanionsWithoutReloading() {
    var deck = createDeck(1600, 450)
    var watch = deck.watchController
    var socket = findChild(watch, "watchHostSocket")
    socket.connected = true
    var original = deck.watchVideoRect()
    var layoutBefore = JSON.stringify(layoutFixture.layout)
    watch.videoRect = original
    watch.videoPosition = 123
    watch.videoDuration = 600
    watch.videoPlaying = true
    watch.state = "playing"
    wait(20)
    var focus = findChild(deck, "watchFocus")
    var video = findChild(deck, "watchVideoRegion")
    var clock = findChild(deck, "watchClockCard")
    var commandCenter = findChild(deck, "watchCommandCenterCard")
    mouseClick(focus, focus.width / 2, focus.height / 2)
    verify(watch.focused)
    verify(!clock.visible && !commandCenter.visible)
    compare(video.x, Math.floor((video.parent.width - video.width) / 2))
    compare(watch.videoRect.left, original.left + video.x)
    compare(watch.videoRect.width, original.width)
    compare(watch.videoPosition, 123)
    verify(watch.videoPlaying)
    compare(watch.state, "playing")
    compare(JSON.parse(socket.sent[socket.sent.length - 1]).action, "geometry")
    grabImage(deck).save("/tmp/omadeck-watch-focus-layout.png")
    var point = focus.mapToItem(testCase, focus.width / 2, focus.height / 2)
    touchEvent(testCase).press(0, testCase, point.x, point.y).commit()
    touchEvent(testCase).release(0, testCase, point.x, point.y).commit()
    tryCompare(watch, "focused", false)
    verify(clock.visible && commandCenter.visible)
    compare(video.x, 0)
    compare(watch.videoRect.left, original.left)
    compare(JSON.stringify(layoutFixture.layout), layoutBefore)
    compare(socket.sent.filter(line => JSON.parse(line).action === "load").length, 0)
    watch.abort()
  }

  function test_watchDrawersResizeVideoAndOverlaysPreservePlayback() {
    var deck = createDeck(1600, 450)
    var watch = deck.watchController
    var socket = findChild(watch, "watchHostSocket")
    socket.connected = true
    watch.videoRect = deck.watchVideoRect()
    watch.videoPosition = 123
    watch.videoDuration = 600
    watch.videoPlaying = true
    watch.state = "playing"
    var original = watch.videoRect
    wait(30)
    var video = findChild(deck, "watchVideoRegion")
    var layoutBefore = JSON.stringify(layoutFixture.layout)
    for (var edge of ["left", "right"]) {
      deck.setOpenDrawer(edge, "test:video-drawer")
      wait(300)
      compare(watch.state, "playing")
      compare(watch.videoPosition, 123)
      verify(watch.videoPlaying)
      verify(watch.videoRect.width < original.width)
      verify(watch.videoRect.height < original.height)
      verify(Math.abs(watch.videoRect.width / watch.videoRect.height - 16 / 9) < 0.01)
      compare(video.mapToItem(deck, 0, 0).x, watch.videoRect.left)
      compare(video.mapToItem(deck, 0, 0).y, watch.videoRect.top)
      verify(video.x >= 0 && video.x + video.width <= video.parent.width)
      for (var controlName of ["watchSeekBack", "watchTogglePlayback", "watchCaptions", "watchFocus", "watchReturn"]) {
        var control = findChild(video, controlName)
        var controlBounds = control.mapToItem(video, 0, 0)
        verify(control.width >= 44 && control.height >= 44)
        verify(controlBounds.x >= 0 && controlBounds.x + control.width <= video.width)
      }
      grabImage(deck).save(edge === "left" ? "/tmp/omadeck-watch-volume-layout.png" : "/tmp/omadeck-watch-system-layout.png")
      deck.closeDrawer()
      wait(300)
      compare(watch.videoRect.width, original.width)
      compare(watch.videoRect.left, original.left)
    }
    for (var overlay of ["notifications", "overview", "preferences"]) {
      deck.openOverlay(overlay)
      wait(300)
      compare(watch.state, "playing")
      verify(!deck.dashboardInputAllowed)
      compare(watch.videoRect.width, original.width)
      verify(watch.videoPlaying)
      deck.closeOverlay()
      wait(300)
      verify(deck.dashboardInputAllowed)
    }
    compare(socket.sent.filter(line => ["load", "close", "returnSnapshot", "pause"].indexOf(JSON.parse(line).action) >= 0).length, 0)
    compare(JSON.stringify(layoutFixture.layout), layoutBefore)
    watch.abort()
  }

  function test_watchHandoffWaitsForSourcePauseAndReturnsToTheSamePlayer() {
    var deck = createDeck(1600, 450)
    var watch = deck.watchController
    var before = JSON.stringify(layoutFixture.layout)
    mediaFixture.actions = []
    playerFixture.seeks = []
    playerFixture.isPlaying = true
    playerFixture.position = 42
    playerFixture.metadata = ({ "xesam:url": "https://www.youtube.com/watch?v=M7lc1UVf-VE" })
    try {
      var candidate = findChild(deck, "nowPlayingPresenter").watchCandidate
      verify(candidate !== null)
      watch.hostAvailable = true
      verify(watch.begin(candidate, deck.watchVideoRect()))
      compare(watch.state, "launching")

      var socket = findChild(watch, "watchHostSocket")
      verify(socket !== null)
      socket.connected = true
      watch.handleMessage('{"event":"connected"}')
      compare(watch.state, "loading")
      watch.handleMessage('{"event":"primed","seconds":42.3}')
      compare(watch.state, "pausing")
      compare(JSON.stringify(mediaFixture.actions), JSON.stringify(["playPause"]))
      playerFixture.isPlaying = false
      tryCompare(watch, "state", "playing")

      watch.videoPosition = 50
      watch.returnToSource()
      compare(watch.state, "returning")
      compare(JSON.parse(socket.sent[socket.sent.length - 1]).action, "returnSnapshot")
      watch.handleMessage('{"event":"returnSnapshot","seconds":65}')
      compare(watch.videoPosition, 65, "Return uses a fresh renderer timestamp")
      compare(JSON.stringify(playerFixture.seeks), JSON.stringify([23]))
      playerFixture.position = 0
      watch.checkBrowserReturn()
      compare(watch.state, "returning", "transient browser zero cannot finish a seek")
      playerFixture.position = 65
      watch.checkBrowserReturn()
      watch.checkBrowserReturn()
      compare(watch.state, "returning", "resume still needs playback confirmation")
      playerFixture.isPlaying = true
      watch.checkBrowserReturn()
      watch.checkBrowserReturn()
      compare(watch.state, "idle")
      compare(JSON.stringify(mediaFixture.actions), JSON.stringify(["playPause", "playPause"]))
      compare(JSON.stringify(layoutFixture.layout), before)
    } finally {
      playerFixture.metadata = ({})
      playerFixture.isPlaying = true
      playerFixture.position = 42
    }
  }

  function test_watchControlsRespondToTouchAtEdgeGeometry() {
    var deck = createDeck(1600, 450)
    var watch = deck.watchController
    var socket = findChild(watch, "watchHostSocket")
    socket.connected = true
    watch.videoRect = deck.watchVideoRect()
    watch.videoPosition = 42
    watch.videoDuration = 180
    watch.videoPlaying = true
    watch.state = "playing"
    wait(100)
    var names = ["watchSeekBack", "watchTogglePlayback", "watchSeekForward"]
    for (var name of names) {
      var button = findChild(deck, name)
      verify(button !== null && button.enabled)
      var point = button.mapToItem(deck, button.width / 2, button.height / 2)
      touchEvent(deck).press(0, deck, point.x, point.y).commit()
      wait(20)
      touchEvent(deck).release(0, deck, point.x, point.y).commit()
      wait(20)
    }
    compare(JSON.parse(socket.sent[0]).seconds, 32)
    compare(JSON.parse(socket.sent[1]).action, "pause")
    compare(JSON.parse(socket.sent[2]).seconds, 52)
    grabImage(deck).save("/tmp/omadeck-watch-layout.png")
    var returnButton = findChild(deck, "watchReturn")
    var returnPoint = returnButton.mapToItem(deck, returnButton.width / 2, returnButton.height / 2)
    touchEvent(deck).press(0, deck, returnPoint.x, returnPoint.y).commit()
    wait(20)
    touchEvent(deck).release(0, deck, returnPoint.x, returnPoint.y).commit()
    tryCompare(watch, "state", "idle")
  }

  function test_watchHereExplainsMissingBrowserSelectionOnClickAndTouch() {
    var deck = createDeck(1600, 450)
    playerFixture.metadata = ({ "xesam:url": "https://www.youtube.com/watch?v=M7lc1UVf-VE" })
    try {
      wait(20)
      var button = findChild(deck, "watchHereButton")
      verify(button !== null && button.visible && button.enabled)
      mouseClick(button, button.width / 2, button.height / 2)
      compare(deck.watchController.notice, "Open the YouTube tab, then try again.")
      compare(deck.watchController.state, "idle")
      deck.watchController.notice = ""
      var point = button.mapToItem(testCase, button.width / 2, button.height / 2)
      touchEvent(testCase).press(0, testCase, point.x, point.y).commit()
      touchEvent(testCase).release(0, testCase, point.x, point.y).commit()
      tryCompare(deck.watchController, "notice", "Open the YouTube tab, then try again.")
    } finally { playerFixture.metadata = ({}) }
  }

  function test_browserBridgeRetainsConnectedSelectionAndTargetsExactCommands() {
    var deck = createDeck(1600, 450)
    var bridge = deck.browserWatchBridge
    var socket = createTemporaryObject(browserSocketComponent, testCase)
    verify(socket !== null)
    bridge.register(socket)
    bridge.receive(socket, '{"type":"hello","browser":"chromium"}')
    bridge.receive(socket,
      '{"type":"candidate","videoId":"M7lc1UVf-VE","seconds":41.5,"tabId":17,"playing":true}')

    compare(bridge.candidateForPlayer("org.mpris.MediaPlayer2.firefox.instance"), null)
    var candidate = bridge.candidateForPlayer("org.mpris.MediaPlayer2.chromium.instance")
    verify(candidate !== null)
    compare(candidate.videoId, "M7lc1UVf-VE")
    compare(candidate.tabId, 17)
    bridge.connections[0].seenMs = Date.now() - 120000
    verify(bridge.candidateForPlayer("org.mpris.MediaPlayer2.chromium.instance") !== null,
      "covered browser timers must not disable Watch here")
    verify(bridge.matches(candidate))
    var requestId = bridge.command(candidate, "pause", 42, false)
    verify(requestId > 0)
    compare(JSON.parse(socket.sent[0]).tabId, 17)
    compare(JSON.parse(socket.sent[0]).videoId, "M7lc1UVf-VE")
    var acknowledged = 0
    bridge.pauseResult.connect(function(id, ok) {
      if (id === requestId && ok) acknowledged++
    })
    var other = createTemporaryObject(browserSocketComponent, testCase)
    bridge.register(other)
    bridge.receive(other, '{"type":"ack","requestId":' + requestId + ',"ok":true}')
    compare(acknowledged, 0)
    bridge.receive(socket, '{"type":"ack","requestId":' + requestId + ',"ok":true}')
    compare(acknowledged, 1)
    bridge.receive(socket,
      '{"type":"candidate","videoId":"bad","seconds":42,"tabId":17,"playing":true}')
    compare(bridge.candidateForPlayer("org.mpris.MediaPlayer2.chromium.instance").videoId,
      "M7lc1UVf-VE")
    bridge.drop(socket)
    compare(bridge.candidateForPlayer("org.mpris.MediaPlayer2.chromium.instance"), null)
  }

  function test_chromiumExtensionHandoffPausesAndRestoresTheExactTab() {
    var deck = createDeck(1600, 450)
    var bridge = deck.browserWatchBridge
    var watch = deck.watchController
    var socket = createTemporaryObject(browserSocketComponent, testCase)
    var oldKey = playerFixture.dbusName
    playerFixture.dbusName = "org.mpris.MediaPlayer2.chromium.instance"
    playerFixture.metadata = ({})
    mediaFixture.actions = []
    try {
      bridge.register(socket)
      bridge.receive(socket, '{"type":"hello","browser":"chromium"}')
      bridge.receive(socket,
        '{"type":"candidate","videoId":"M7lc1UVf-VE","seconds":43,"tabId":17,"playing":true}')
      wait(20)
      var candidate = findChild(deck, "nowPlayingPresenter").watchCandidate
      verify(candidate !== null && candidate.sourceKind === "extension")
      watch.hostAvailable = true
      verify(watch.begin(candidate, deck.watchVideoRect()))
      findChild(watch, "watchHostSocket").connected = true
      watch.handleMessage('{"event":"connected"}')
      watch.handleMessage('{"event":"primed","seconds":43.2}')
      compare(watch.state, "pausing")
      var pause = JSON.parse(socket.sent[0])
      compare(pause.action, "pause")
      compare(pause.tabId, 17)
      playerFixture.isPlaying = false
      compare(watch.state, "pausing", "extension acknowledgement owns pause completion")
      bridge.receive(socket,
        '{"type":"ack","requestId":' + pause.requestId + ',"ok":true,"seconds":43.5}')
      compare(watch.state, "playing")
      compare(watch.videoPosition, 43.5)
      watch.videoPosition = 55
      bridge.receive(socket, '{"type":"clear"}')
      verify(!bridge.matches(candidate), "switching tabs clears the current offer")
      verify(bridge.connectedSource(candidate), "existing session retains the exact source")
      watch.returnToSource()
      watch.handleMessage('{"event":"returnSnapshot","seconds":61.75}')
      var resume = JSON.parse(socket.sent[1])
      compare(resume.action, "resume")
      compare(resume.tabId, 17)
      compare(resume.videoId, "M7lc1UVf-VE")
      compare(resume.seconds, 61)
      compare(watch.state, "returning")
      bridge.receive(socket,
        '{"type":"ack","requestId":' + resume.requestId + ',"ok":true,"seconds":62}')
      compare(watch.state, "idle")
      compare(JSON.stringify(mediaFixture.actions), JSON.stringify([]))
    } finally {
      playerFixture.dbusName = oldKey
      playerFixture.metadata = ({})
      playerFixture.isPlaying = true
    }
  }

  function test_embedRejectionExplainsFailureWithoutSeekingTheBrowser() {
    var deck = createDeck(1600, 450)
    var watch = deck.watchController
    var bridge = deck.browserWatchBridge
    var socket = createTemporaryObject(browserSocketComponent, testCase)
    bridge.register(socket)
    bridge.receive(socket, '{"type":"hello","browser":"firefox"}')
    watch.source = ({ sourceKind: "extension", sourceWasPlaying: true,
      connectionId: socket.connectionId, tabId: 17,
      videoId: "M7lc1UVf-VE", browser: "firefox" })
    watch.state = "loading"
    watch.handleMessage('{"event":"error","code":150}')
    compare(watch.state, "idle")
    verify(watch.notice.indexOf("cannot play inside OmaDeck") >= 0)
    compare(socket.sent.length, 0, "startup failure must leave browser playback untouched")
  }

  function test_closedSourceAfterEndCanExitWithoutTouchingNewBrowserVideo() {
    var deck = createDeck(1600, 450)
    var watch = deck.watchController
    var bridge = deck.browserWatchBridge
    var socket = createTemporaryObject(browserSocketComponent, testCase)
    bridge.register(socket)
    bridge.receive(socket, '{"type":"hello","browser":"firefox"}')
    watch.source = ({ sourceKind: "extension", connectionId: socket.connectionId,
      tabId: 1000000, videoId: "M7lc1UVf-VE", browser: "firefox" })
    watch.videoRect = deck.watchVideoRect()
    watch.state = "playing"
    findChild(watch, "watchHostSocket").connected = true
    watch.handleMessage('{"event":"state","state":0}')
    bridge.receive(socket, '{"type":"candidate","tabId":1000001,"videoId":"jNQXAC9IVRw","seconds":14,"playing":true}')
    bridge.receive(socket, '{"type":"sourceClosed","tabId":1000002}')
    verify(!watch.sourceClosed, "another tab closing must not affect this video")
    bridge.receive(socket, '{"type":"sourceClosed","tabId":1000000}')
    compare(watch.state, "playing")
    verify(watch.sourceClosed)
    wait(20)
    var exit = findChild(deck, "watchReturn")
    compare(exit.text, "Close")
    clickItem(deck, exit)
    compare(watch.state, "idle")
    compare(socket.sent.length, 0, "never seek or pause the new browser video")
    verify(!watch.sourceClosed)
  }

  function test_closeVideoAlwaysExitsIncludingFailedReturnAndStartup() {
    var deck = createDeck(1600, 450)
    var watch = deck.watchController
    watch.videoRect = deck.watchVideoRect()
    for (var state of ["launching", "playing", "returning"]) {
      watch.state = state
      watch.focused = true
      watch.videoPlaying = false
      wait(20)
      var exit = findChild(deck, "watchClose")
      verify(exit.visible && exit.enabled)
      verify(exit.width >= 44 && exit.height >= 44)
      clickItem(deck, exit)
      compare(watch.state, "idle")
    }
  }

  function test_watchReturnRejectsSuccessWithWrongOrMissingTimestamp() {
    var deck = createDeck(1600, 450)
    var watch = deck.watchController
    for (var confirmed of [-1, 40]) {
      watch.state = "returning"
      watch.videoPosition = 120
      watch.pendingReturnRequest = 9
      deck.browserWatchBridge.pauseResult(9, true, confirmed)
      compare(watch.state, "playing")
      verify(watch.notice !== "")
      compare(watch.videoPlaying, false)
      compare(watch.lastReturnConfirmed, confirmed)
    }
    watch.abort()
  }

  function test_watchUsesSharedMprisWhenOmarchyMediaProxyLacksExactLookup() {
    shellFixture.mediaOverride = scopedMediaFixture
    Mp.Mpris.players.values = [playerFixture]
    playerFixture.metadata = ({ "xesam:url": "https://www.youtube.com/watch?v=M7lc1UVf-VE" })
    playerFixture.isPlaying = true
    try {
      var deck = createDeck(1600, 450)
      var watch = deck.watchController
      verify(watch.media !== scopedMediaFixture)
      verify(watch.media.enabled, "shared MPRIS adapter should be active")
      var candidate = findChild(deck, "nowPlayingPresenter").watchCandidate
      verify(candidate !== null)
      verify(watch.media.playerForKey(candidate.sourceKey) !== null,
        "exact MPRIS player should be available: " + candidate.sourceKey)
      watch.hostAvailable = true
      verify(watch.begin(candidate, deck.watchVideoRect()))
      findChild(watch, "watchHostSocket").connected = true
      watch.handleMessage('{"event":"connected"}')
      watch.handleMessage('{"event":"primed","seconds":42}')
      tryCompare(watch, "state", "playing")
      compare(playerFixture.isPlaying, false)
      watch.returnToSource()
      watch.handleMessage('{"event":"returnSnapshot","seconds":42}')
      tryCompare(watch, "state", "idle")
      compare(playerFixture.isPlaying, true)
    } finally {
      shellFixture.mediaOverride = null
      Mp.Mpris.players.values = []
      playerFixture.metadata = ({})
      playerFixture.isPlaying = true
    }
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

  function test_devicePickerKeepsScaledControlsInsideDrawerAndReturnsToMixer() {
    var deck = createDeck(1600, 450)
    deck.setMediaCompact(false)
    wait(300)
    var mixer = findChild(deck, "audioMixerPresenter")
    var route = findChild(deck, "outputDeviceSelector")
    var inputRoute = findChild(deck, "inputDeviceSelector")
    verify(route.visible && inputRoute.visible)
    compare(route.deviceLabel, "QR65 speakers")
    compare(inputRoute.deviceLabel, "Alias Pro mic")
    verify(route.height >= 44 && inputRoute.height >= 44)
    clickItem(deck, route)
    wait(100)
    var picker = findChild(deck, "audioDevicePicker")
    compare(picker.kind, "output")
    verify(picker.visible)
    var selected = findChild(picker, "audioDevice:fixture-sink")
    verify(selected !== null && selected.selected)
    var bounds = rectIn(selected, mixer)
    verify(bounds.x >= 0 && bounds.y >= 0)
    verify(bounds.x + bounds.width <= mixer.width)
    verify(bounds.y + bounds.height <= mixer.height)
    var outputTab = findChild(picker, "audioOutputTab")
    var inputTab = findChild(picker, "audioInputTab")
    var inputRow = findChild(picker, "audioDevice:fixture-source")
    verify(inputRow !== null && !inputRow.visible)
    for (var switchIndex = 0; switchIndex < 10; switchIndex++) {
      var input = switchIndex % 2 === 0
      clickItem(deck, input ? inputTab : outputTab)
      // No wait: selection and list visibility change in the tap's event turn.
      compare(picker.kind, input ? "input" : "output")
      compare(inputTab.selected, input)
      compare(outputTab.selected, !input)
      compare(inputRow.visible, input)
      compare(selected.visible, !input)
      compare(findChild(picker, "audioDevice:fixture-sink"), selected,
        "tab changes must retain the existing output row")
      compare(findChild(picker, "audioDevice:fixture-source"), inputRow,
        "tab changes must retain the existing input row")
    }
    clickItem(deck, findChild(picker, "audioInputTab"))
    compare(picker.kind, "input")
    verify(findChild(picker, "audioDevice:fixture-source").selected)
    clickItem(deck, findChild(picker, "audioDeviceBack"))
    verify(!picker.visible)
    clickItem(deck, route)
    compare(picker.kind, "output", "reopening must reset a previously changed tab")
    clickItem(deck, findChild(picker, "audioDevice:fixture-sink"))
    verify(!picker.visible, "selecting the current device returns without spawning a switch")
    compare(findChild(mixer, "audioDeviceSwitchProcess").running, false)
    verify(route.visible)
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
    compare(nowPlayingCard.width, Math.round((deck.usableWidth - deck.reservedLeft - deck.reservedRight - deck.innerGap) * 0.27),
      "expanded Volume preserves the configured dashboard proportions")

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
    id: browserSocketComponent
    QtObject {
      property bool connected: true
      property int connectionId: 0
      property var sent: []
      function write(data) { sent = sent.concat([data]) }
      function flush() {}
    }
  }

  Component {
    id: nodeComponent
    QtObject {
      property int id: 0
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
    id: lockFixture
    property bool locked: false
    property bool strandedLockResolved: true
    property bool strandedLock: false
  }

  QtObject {
    id: scopedShellFixture
    function serviceFor(serviceId) { return null }
    function firstPartyServiceFor(serviceId) { return null }
  }

  QtObject {
    id: lockRegistryFixture
    property string enabledLockId: "omarchy.lock"
    function resolveEnabledId(id) { return id === "omarchy.lock" ? enabledLockId : id }
  }

  QtObject {
    id: shellFixture
    property var pluginRegistry: lockRegistryFixture
    property var shellConfig: ({
      bar: { position: "top", transparent: false },
      idle: { screensaver: 150, lock: 300 }
    })
    property var bar: barFixture
    property var mediaOverride: null
    property int shellMutationCalls: 0
    property string lastSummonedId: ""
    property string lastSummonedPayload: ""

    function serviceFor(serviceId) { return serviceId === lockRegistryFixture.enabledLockId ? lockFixture : serviceId === "omarchy.media" ? (mediaOverride || mediaFixture) : null }
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
    id: monitorFixture
    property bool showControls: true
    property bool loaded: true
    property bool busy: false
    property string switchStatus: ""
    property string notice: ""
    property var settings: ({ enabled: true })
    property var setupStatus: null
    property bool setupWindowOpened: false
    property bool scanned: false
    property var requests: []
    property var detectedMonitors: []
    property var monitors: [{ id: "a".repeat(64), label: "Fixture monitor", sources: [{ code: "0f", label: "Desktop" }, { code: "13", label: "Laptop" }] }]
    readonly property var selectedMonitor: monitors[0]
    function switchInput(id, code) { requests = requests.concat([{ id: id, code: code }]); return true }
    function cycleMonitor(delta) {}
    function checkSetup() { setupStatus = { state: "ready", canPrepare: true }; return true }
  }

  QtObject {
    id: mediaFixture
    property var activePlayer: playerFixture
    property var actions: []
    function playerKey(player) { return player.dbusName }
    function playerForKey(key) { return activePlayer && activePlayer.dbusName === key ? activePlayer : null }
    function runAction(action, argument, targetKey) { actions.push(action); return true }
  }

  QtObject {
    id: scopedMediaFixture
    property var activePlayer: playerFixture
    function playerKey(player) { return player.dbusName }
    function runAction(action, argument, targetKey) {}
  }

  QtObject {
    id: playerFixture
    property string trackTitle: "Fixture Song"
    property string trackArtist: "Fixture Artist"
    property string trackAlbum: "Fixture Album"
    property string identity: "Fixture Player"
    property string trackArtUrl: ""
    property var metadata: ({})
    property string dbusName: "org.mpris.MediaPlayer2.fixture"
    property bool canPlay: true
    property bool canPause: true
    property bool canControl: true
      property bool canTogglePlaying: true
      property int playbackState: 1
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
    function pause() { isPlaying = false }
    function play() { isPlaying = true }
  }

  Stores.LayoutController {
    id: layoutFixture
    property int retryCalls: 0
    function persist() { retryCalls++; saveError = "" }
    readonly property string layoutBytes: JSON.stringify(layout)
    readonly property string topology: JSON.stringify(layout.root)
    readonly property int schemaVersion: layout.version
    readonly property int mutationCalls: revision
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
    property string saveError: ""
    property int retryCalls: 0
    function persist() { retryCalls++; saveError = "" }
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
    property string selectedSoundName: "Ocean"
    property bool soundSettingsLoaded: true
    property var soundOptions: [
      { eventId: "ocean", label: "Ocean" }, { eventId: "", label: "Silent" },
      { eventId: "alarm-clock-elapsed", label: "Alarm" }, { eventId: "complete", label: "Complete" },
      { eventId: "bell", label: "Bell" }, { eventId: "phone-incoming-call", label: "Ring" },
      { eventId: "dialog-warning", label: "Warning" }
    ]
    property string selectedSoundId: "ocean"
    property int previewCalls: 0
    function resetPreferences() { selectedSoundId = "ocean"; previewCalls = 0 }
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
