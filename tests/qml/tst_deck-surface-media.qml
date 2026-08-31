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

  function createDeck() {
    var deck = createTemporaryObject(deckSurfaceComponent, testCase, {
      width: 2560,
      height: 720,
      targetScreen: "DP-3",
      shell: shellFixture
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
    compare(nowPlayingCard.x, mixerCard.x)
    verify(nowPlayingCard.y + nowPlayingCard.height < mixerCard.y)
    compare(mixerCard.y - nowPlayingCard.y - nowPlayingCard.height, left.content[0].panelGap)
    verify(nowPlayingCard.x + nowPlayingCard.width <= left.width - left.dismissInset)
    verify(mixerCard.y + mixerCard.height <= left.height)

    compare(deck.reservedLeft, deck.leftDrawerWidth + deck.innerGap)
    compare(center.x, deck.outerGap + deck.reservedLeft)
    compare(center.width, deck.usableWidth - deck.reservedLeft)
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
    clickItem(presenter, findByProperty(presenter, "text", "−10"))
    clickItem(presenter, findByProperty(presenter, "text", "+10"))
    clickItem(presenter, findByProperty(presenter, "iconText", "󰒭"))
    compare(JSON.stringify(mediaFixture.actions), JSON.stringify(["playPause", "previous", "next"]))
    compare(JSON.stringify(playerFixture.seeks), JSON.stringify([-10, 10]))
    presenter.seekTo(95)
    compare(playerFixture.position, 95)
  }

  function test_mixerWrappersAndFourStreamOverflowStayInsideCard() {
    var deck = createDeck()
    deck.setMediaCompact(true)
    wait(260)
    var mixer = findChild(deck, "audioMixerPresenter")
    var mixerCard = findChild(deck, "audioMixerPanelCard")
    verify(mixer !== null)
    verify(mixerCard !== null)
    compare(mixer.compact, true)

    deck.setMediaCategory("media")
    wait(300)
    compare(mixer.compact, false)
    compare(mixer.expandedCategory, "media")
    compare(mixer.displayStreams.length, 4)
    compare(mixer.visibleStreamRowLimit, 2)

    var output = findByProperty(mixer, "label", "Output")
    var microphone = findByProperty(mixer, "label", "Mic")
    var viewport = findChild(mixer, "mediaSourceViewport")
    verify(output !== null && output.height >= 46)
    verify(microphone !== null && microphone.height >= 46)
    verify(viewport !== null)
    verify(viewport.interactive)
    compare(viewport.height, 46 * mixer.visibleStreamRowLimit)
    verify(viewport.contentHeight >= 46 * 4)

    var origin = viewport.mapToItem(mixerCard, 0, 0)
    verify(origin.x >= 0 && origin.y >= 0)
    verify(origin.x + viewport.width <= mixerCard.width)
    verify(origin.y + viewport.height <= mixerCard.height)
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
    wait(230)
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
    property string layoutBytes: "fixture-layout-v1"
    property string topology: "split(module:clock,module:command-center)"
    property int schemaVersion: 1
    property int mutationCalls: 0
    function nodeAt(path) { return null }
    function setRatio(path, ratio) { mutationCalls++ }
  }
}
