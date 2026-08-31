import QtQuick
import QtTest
import "." as Baseline
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

  function renderRows() {
    return [
      { tag: "no-player", state: "no-player" },
      { tag: "playing", state: "playing" },
      { tag: "paused", state: "paused" },
      { tag: "missing-artwork", state: "missing-artwork" },
      { tag: "published-artwork", state: "published-artwork" },
      { tag: "derived-artwork", state: "derived-artwork" },
      { tag: "missing-length", state: "missing-length" },
      { tag: "disabled-capabilities", state: "disabled-capabilities" }
    ]
  }

  function test_fullCompositionParity_data() {
    return renderRows()
  }

  function test_fullCompositionParity(data) {
    var beforeFixture = fixtureFor(data.state, testCase)
    var afterFixture = fixtureFor(data.state, testCase)
    var properties = { width: 780, height: 720 }
    var before = createTemporaryObject(acceptedMediaComponent, testCase, {
      width: properties.width,
      height: properties.height,
      shell: beforeFixture.shell
    })
    var after = createTemporaryObject(mediaModuleComponent, testCase, {
      width: properties.width,
      height: properties.height,
      shell: afterFixture.shell
    })
    verify(before !== null)
    verify(after !== null)

    wait(data.state === "published-artwork" ? 250 : 20)
    compare(after.width, before.width)
    compare(after.height, before.height)
    verify(grabImage(after).equals(grabImage(before)), data.tag)
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
    clickItem(module, findByProperty(module, "iconText", "󰒭"))
    compare(JSON.stringify(fixture.media.actions), JSON.stringify(["playPause", "previous", "next"]))

    module.skip(-10)
    module.skip(10)
    compare(JSON.stringify(fixture.player.seeks), JSON.stringify([-10, 10]))
    module.seekTo(95)
    compare(fixture.player.position, 95)
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

    compare(findByProperty(module, "text", "−10").enabled, false)
    compare(findByProperty(module, "text", "+10").enabled, false)
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

  Component {
    id: acceptedMediaComponent
    Baseline.AcceptedMediaModule {}
  }

  Component {
    id: mediaModuleComponent
    Modules.MediaModule {}
  }

  Component {
    id: nowPlayingComponent
    Modules.NowPlayingModule {}
  }
}
