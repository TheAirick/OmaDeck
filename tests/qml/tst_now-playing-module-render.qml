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
      function runAction(action, argument) { actions.push(action) }
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
    verify(overlayOrigin.y >= artwork.y)
    verify(overlayOrigin.y + overlay.height <= artwork.y + artwork.height + 0.5)
    verify(bandOrigin.y >= artwork.y + artwork.height)
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
