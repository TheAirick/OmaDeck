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

  function test_leftDrawerUsesTwoPersistentCards() {
    var deck = createDeck()
    deck.setOpenDrawer("left", "test")
    wait(260)

    var left = findChild(deck, "leftMediaDrawer")
    var right = findChild(deck, "rightSystemDrawer")
    var top = findChild(deck, "topWorkspaceDrawer")
    var bottom = findChild(deck, "bottomLauncherDrawer")
    var center = findChild(deck, "deckCenterCanvas")
    var nowPlayingCard = findChild(deck, "nowPlayingPanelCard")
    var mixerCard = findChild(deck, "audioMixerPanelCard")
    verify(left !== null)
    verify(right !== null)
    verify(top !== null)
    verify(bottom !== null)
    verify(center !== null)
    verify(nowPlayingCard !== null)
    verify(mixerCard !== null)

    compare(left.framed, false)
    compare(left.color.a, 0)
    compare(left.border.width, 0)
    verify(left.dismissInset > 0)
    compare(right.framed, true)
    verify(right.border.width > 0)
    compare(top.framed, true)
    compare(bottom.framed, true)
    verify(top.border.width > 0)
    verify(bottom.border.width > 0)

    compare(nowPlayingCard.parent, mixerCard.parent)
    verify(nowPlayingCard.parent !== left)
    verify(nowPlayingCard.visible)
    verify(mixerCard.visible)
    compare(nowPlayingCard.y, mixerCard.y)
    compare(nowPlayingCard.height, mixerCard.height)
    verify(mixerCard.x + mixerCard.width < nowPlayingCard.x)
    compare(nowPlayingCard.x - mixerCard.x - mixerCard.width, left.content[0].panelGap)
    verify(nowPlayingCard.x + nowPlayingCard.width <= left.width - left.dismissInset)
    verify(mixerCard.y + mixerCard.height <= left.height)

    compare(deck.reservedLeft, deck.leftDrawerWidth + deck.innerGap)
    compare(center.x, deck.outerGap + deck.reservedLeft)
    compare(center.width, deck.usableWidth - deck.reservedLeft)
  }

  function test_mediaCardsUseOneTokenGapBeforeCenterWithoutChangingOtherGaps() {
    var deck = createDeck()
    deck.setOpenDrawer("left", "test:geometry")
    wait(260)

    var left = findChild(deck, "leftMediaDrawer")
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
    compare(mixerBounds.width + deck.innerGap + nowPlayingBounds.width,
      deck.leftDrawerWidth, "sibling cards fill the Media width")
    compare(left.dismissInset, deck.innerGap, "the extra carrier strip owns dismissal")
    verify(leftBounds.x + leftBounds.width - (nowPlayingBounds.x + nowPlayingBounds.width) > 0,
      "dismissal strip must be outside card controls")
    verify(Math.abs(clockBounds.x - (nowPlayingBounds.x + nowPlayingBounds.width) - deck.innerGap) <= 0.5,
      "Media-to-center gap must be exactly one innerGap")

    compare(mixerBounds.height, nowPlayingBounds.height, "both Media cards span the deck height")
    compare(companionBounds.y - (clockBounds.y + clockBounds.height), deck.innerGap,
      "Clock-to-Weather gap")
    compare(commandBounds.x - (clockBounds.x + clockBounds.width), deck.innerGap,
      "center-to-Command Center gap")
    compare(deck.width - (commandBounds.x + commandBounds.width), deck.outerGap,
      "Command Center right edge")
  }

  function test_scaledDeckRedistributesCommandSpaceToMediaAndWeather() {
    var deck = createDeck(1600, 450)
    deck.setOpenDrawer("left", "test:scaled-balance")
    wait(260)

    var center = findChild(deck, "deckCenterCanvas")
    var nowPlayingCard = findChild(deck, "nowPlayingPanelCard")
    var mixerCard = findChild(deck, "audioMixerPanelCard")
    var clockCard = findChild(deck, "clockPanelCard")
    var commandCard = findChild(deck, "moduleCard")
    var command = findWhere(commandCard, function(item) {
      return item.useWideLayout !== undefined && item.contentScale !== undefined
    })
    var weather = findWhere(deck, function(item) {
      return item.effectiveDetail !== undefined && item.showDetailedMetrics !== undefined
    })
    verify(center !== null && nowPlayingCard !== null && mixerCard !== null)
    verify(clockCard !== null && commandCard !== null && command !== null && weather !== null)

    compare(deck.leftDrawerWidth, Math.round(deck.usableWidth * 0.34))
    compare(mixerCard.width + deck.innerGap + nowPlayingCard.width, deck.leftDrawerWidth)
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
    var left = findChild(deck, "leftMediaDrawer")
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
    var left = findChild(deck, "leftMediaDrawer")
    var nowPlayingCard = findChild(deck, "nowPlayingPanelCard")
    var closeButton = findByProperty(left, "tooltipText", "Close drawer")
    verify(left !== null && nowPlayingCard !== null && closeButton !== null)
    left.pointerRevealed = true
    wait(0)

    var cardBounds = rectIn(nowPlayingCard, deck)
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
    deck.setOpenDrawer("left", "test:pointer")
    wait(260)
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
    verify(deck.leftDrawerWidth >= Math.round(deck.usableWidth * 0.48),
      "expanding Volume must reserve horizontal room for its revealed controls")
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
    verify(deck.leftDrawerWidth <= Math.round(deck.usableWidth * 0.62))
    verify(nowPlayingCard.width >= 360,
      "expanded Volume must leave a usable Now Playing card")

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
    deck.setOpenDrawer("left", "test:no-player")
    wait(300)

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
    var host = findChild(deck, "mediaPanelHost")
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
      compare(findChild(deck, "mediaPanelHost"), host)
      compare(findChild(deck, "nowPlayingPresenter"), presenter)
      compare(findChild(deck, "audioMixerPresenter"), mixer)
      compare(mixer.displayStreams.length, cycle % 2 === 0 ? 4 : 0)
    }

    deck.setOpenDrawer("left", "test:dismiss")
    wait(230)
    var left = findChild(deck, "leftMediaDrawer")
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
    function serviceFor(serviceId) { return serviceId === "omarchy.media" ? mediaFixture : null }
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
    property bool use24Hour: false
    property bool showSeconds: false
    property bool showWeather: true
    property string weatherStyle: "scene"
    property string weatherDetail: "standard"
    property string temperatureUnit: "fahrenheit"
  }

  QtObject {
    id: weatherFixture
    property bool loading: false
    property string error: ""
    property var current: ({ ok: true, condition: "clear", conditionLabel: "Clear", isDay: true,
      temperatureC: 18, feelsLikeC: 18, windKph: 5, humidity: 40, highC: 20, lowC: 12,
      location: "Portland", forecast: [] })
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
    function start(hours, minutes) { status = "active"; return { ok: true } }
    function stopPreview() {}
    function selectPreviousSound() {}
    function selectNextSound() {}
    function previewSelectedSound() {}
    function pause() { status = "paused" }
    function resume() { status = "active" }
    function add(minutes) {}
    function restart() { status = "active" }
    function cancel() { status = "idle" }
    function dismiss() { status = "idle" }
  }
}
