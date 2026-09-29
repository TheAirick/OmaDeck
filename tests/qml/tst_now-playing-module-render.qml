import QtQuick
import QtTest
import "../../modules" as Modules

TestCase {
  id: testCase
  name: "NowPlayingModuleRenderParity"
  when: windowShown

  width: 1800
  height: 900
  visible: true

  property url publishedArtwork: Qt.resolvedUrl("../../assets/screenshots/media.png")

  Component {
    id: playerComponent
    QtObject {
      property string trackTitle: "Fixture Song"
      property string trackArtist: "Fixture Artist"
      property string trackAlbum: "Fixture Album"
      property string identity: "Fixture Player"
      property string trackArtUrl: ""
      property var metadata: ({})
      property string dbusName: "org.mpris.MediaPlayer2.fixture"
      property bool canPlay: true
      property bool canPause: true
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
    }
  }

  Component {
    id: mediaComponent
    QtObject {
      property var activePlayer: null
      property var actions: []
      function playerKey(player) { return player.dbusName }
      function playerForKey(key) { return activePlayer && activePlayer.dbusName === key ? activePlayer : null }
      function runAction(action, argument, targetKey) { actions.push(action); return true }
    }
  }

  Component {
    id: shellComponent
    QtObject {
      property var mediaService: null
      function serviceFor(serviceId) { return serviceId === "omarchy.media" ? mediaService : null }
    }
  }

  function playerFor(state, owner) {
    if (state === "no-player") return null
    var properties = {}
    if (state === "paused") properties.isPlaying = false
    if (state === "published-artwork") properties.trackArtUrl = publishedArtwork
    if (state === "derived-artwork") {
      properties.metadata = { "xesam:url": "https://www.youtube.com/watch?v=lVpSU49cdQ0" }
    }
    if (state === "missing-length") {
      properties.lengthSupported = false
      properties.length = 0
    }
    if (state === "disabled-capabilities") {
      properties.canSeek = false
      properties.positionSupported = false
      properties.canGoPrevious = false
      properties.canGoNext = false
    }
    return createTemporaryObject(playerComponent, owner, properties)
  }

  function fixtureFor(state, owner) {
    var player = playerFor(state, owner)
    var media = createTemporaryObject(mediaComponent, owner, { activePlayer: player })
    var shell = createTemporaryObject(shellComponent, owner, { mediaService: media })
    verify(media !== null)
    verify(shell !== null)
    return { player: player, media: media, shell: shell }
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

  function clickItem(module, item) {
    verify(item !== null)
    var point = item.mapToItem(module, item.width / 2, item.height / 2)
    mouseClick(module, point.x, point.y)
  }

  Component {
    id: chiBridgeComponent
    QtObject {
      property bool ready: true
      property int nowPlaying: 107
      property var tabs: ({ 107: { media_id: "doc:yt", title: "YouTube video", artist: "Channel", artwork: "",
        page_url: "https://www.youtube.com/watch?v=lVpSU49cdQ0", playing: false, position_ms: 30000, duration_ms: 600000 } })
      property var controls: []
      signal mediaUpdated(int tabId, var media)
      function controlNowPlaying(action) { controls.push(JSON.stringify(action)); return true }
    }
  }
  Component {
    id: browserBridgeComponent
    QtObject { property var chiBridge: null; function candidateForPlayer() { return null } }
  }
  Component {
    id: deckComponent
    QtObject {
      property var browserWatchBridge: null
      property var watchController: ({ notice: "", active: false, shuttingDown: false })
      function startWatch() {}
    }
  }

  function test_chiCardFollowsChiNowPlayingNotTheStaleWebKitPlayer() {
    var fixture = fixtureFor("playing", testCase)
    // WebKit's single player is stuck on X, which muted itself.
    fixture.player.identity = "Chi"
    fixture.player.trackTitle = "Home / X"
    fixture.player.trackArtist = ""
    var chi = createTemporaryObject(chiBridgeComponent, testCase)
    var bridge = createTemporaryObject(browserBridgeComponent, testCase, { chiBridge: chi })
    var deck = createTemporaryObject(deckComponent, testCase, { browserWatchBridge: bridge })
    var module = createTemporaryObject(nowPlayingComponent, testCase, { width: 780, height: 520, media: fixture.media, deck: deck })
    verify(module !== null)
    wait(1)
    compare(module.displayTitle, "YouTube video")
    compare(module.displayArtist, "Channel")
    compare(module.playbackStatus, "Paused")
    // The stale WebKit player says "Playing"; the button follows Chi.
    compare(findChild(module, "playPauseControl").Accessible.name, "Play")
    chi.tabs = Object.assign({}, chi.tabs, { 107: Object.assign({}, chi.tabs[107], { playing: true }) })
    compare(findChild(module, "playPauseControl").Accessible.name, "Pause")
    chi.tabs = Object.assign({}, chi.tabs, { 107: Object.assign({}, chi.tabs[107], { playing: false }) })
    compare(module.effectiveLength, 600)
    compare(module.displayedPosition, 30)
    verify(module.artworkUrl.indexOf("lVpSU49cdQ0") >= 0, module.artworkUrl)
    verify(module.runTransport("playPause"))
    module.seekTo(95)
    compare(JSON.stringify(chi.controls), JSON.stringify([JSON.stringify({ action: "toggle" }), JSON.stringify({ action: "seek", position_ms: 95000 })]))
    compare(fixture.media.actions.length, 0, "the stale WebKit player is never driven")
    compare(fixture.player.seeks.length, 0)
    // Another browser's player keeps its own metadata and transport.
    fixture.player.identity = "Firefox"
    compare(module.displayTitle, "Home / X")
  }

  function test_transportAndSeekForwarding() {
    var fixture = fixtureFor("playing", testCase)
    var module = createTemporaryObject(nowPlayingComponent, testCase, {
      width: 780,
      height: 520,
      media: fixture.media
    })
    verify(module !== null)
    wait(1)

    clickItem(module, findByProperty(module, "iconText", "󰏤"))
    clickItem(module, findByProperty(module, "iconText", "󰒮"))
    clickItem(module, findChild(module, "seekBackwardControl"))
    clickItem(module, findChild(module, "seekForwardControl"))
    clickItem(module, findByProperty(module, "iconText", "󰒭"))
    compare(JSON.stringify(fixture.media.actions), JSON.stringify(["playPause", "previous", "next"]))

    compare(JSON.stringify(fixture.player.seeks), JSON.stringify([-10, 10]))
    // Native touch can leave a synthetic mouse hover behind after release.
    // These controls must remain tooltip-free in either playback state.
    for (var controlName of ["playPauseControl", "seekBackwardControl", "seekForwardControl"])
      compare(findChild(module, controlName).tooltipText, "")
    fixture.player.isPlaying = false
    compare(findChild(module, "playPauseControl").Accessible.name, "Play")
    compare(findChild(module, "playPauseControl").tooltipText, "")
    module.seekTo(95)
    compare(fixture.player.position, 42)
    compare(JSON.stringify(fixture.player.seeks), JSON.stringify([-10, 10, 53]))
    compare(module.displayedPosition, 95)
  }

  function test_disabledCapabilitiesAndLifecycleReset() {
    var fixture = fixtureFor("disabled-capabilities", testCase)
    var module = createTemporaryObject(nowPlayingComponent, testCase, {
      width: 780,
      height: 520,
      media: fixture.media
    })
    verify(module !== null)
    wait(1)

    compare(findChild(module, "seekBackwardControl").enabled, false)
    compare(findChild(module, "seekForwardControl").enabled, false)
    compare(findByProperty(module, "iconText", "󰒮").enabled, false)
    compare(findByProperty(module, "iconText", "󰒭").enabled, false)

    module.cachedLength = 180
    module.displayedPosition = 75
    module.optimisticPosition = true
    module.cachedArtworkKey = module.artworkKey
    module.cachedArtworkUrl = publishedArtwork
    fixture.media.activePlayer = null
    wait(1)
    compare(module.cachedLength, 0)
    compare(module.displayedPosition, 0)
    compare(module.optimisticPosition, false)
    compare(module.artworkUrl, "")
  }

  function test_centeredArtworkOverlayAndVerticalControlGeometry() {
    var fixture = fixtureFor("playing", testCase)
    var module = createTemporaryObject(nowPlayingComponent, testCase, {
      width: 420,
      height: 390,
      media: fixture.media
    })
    verify(module !== null)
    wait(1)

    var artwork = findChild(module, "nowPlayingArtwork")
    var overlay = findChild(module, "nowPlayingMetadataOverlay")
    var controlBand = findChild(module, "nowPlayingControlBand")
    var controls = findChild(module, "nowPlayingControls")
    var timeline = findChild(module, "nowPlayingTimeline")
    var previous = findByProperty(module, "iconText", "󰒮")
    var seekBack = findChild(module, "seekBackwardControl")
    var playPause = findByProperty(module, "iconText", "󰏤")
    var seekForward = findChild(module, "seekForwardControl")
    var next = findByProperty(module, "iconText", "󰒭")
    verify(artwork !== null && overlay !== null && controlBand !== null)
    verify(controls !== null && timeline !== null)
    verify(previous !== null && seekBack !== null && playPause !== null)
    verify(seekForward !== null && next !== null)
    compare(artwork.y, 0)
    verify(Math.abs(artwork.x + artwork.width / 2 - module.width / 2) <= 0.5)
    verify(artwork.height < module.height)
    var overlayOrigin = overlay.mapToItem(module, 0, 0)
    var bandOrigin = controlBand.mapToItem(module, 0, 0)
    var timelineOrigin = timeline.mapToItem(module, 0, 0)
    verify(overlayOrigin.y >= artwork.y + artwork.height)
    verify(bandOrigin.y >= overlayOrigin.y + overlay.height)
    verify(bandOrigin.y + controlBand.height <= timelineOrigin.y + 0.5)
    verify(controls.y >= 0 && controls.y + controls.height <= controlBand.height)
    verify(controls.width <= controlBand.width)
    compare(seekBack.visible, true)
    compare(seekForward.visible, true)
    verify(previous.iconSize >= 48)
    verify(next.iconSize >= 48)
    verify(playPause.iconSize >= 64)
    compare(findChild(module, "seekBackwardIcon").width, 34)
    compare(findChild(module, "seekBackwardIcon").height, 34)
    compare(findChild(module, "seekForwardIcon").width, 34)
    compare(findChild(module, "seekForwardIcon").height, 34)
    compare(timelineOrigin.y + timeline.height, module.height)
  }


  Component {
    id: nowPlayingComponent
    Modules.NowPlayingModule {}
  }
}
