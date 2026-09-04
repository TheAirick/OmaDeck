import QtQuick
import QtTest
import "../../modules" as Modules

TestCase {
  id: suite
  name: "MediaTimeline"
  when: windowShown
  width: 780
  height: 520

  // Isolated MPRIS boundary: seek() sends a request without changing position,
  // as in Quickshell 0.3.1. Only simulated player reports change position.
  Component {
    id: playerComponent
    QtObject {
      property string trackTitle: "Same title"
      property string trackArtist: "Same artist"
      property string identity: "Player"
      property string trackArtUrl: ""
      property int uniqueId: 1
      property var metadata: ({})
      property bool canSeek: true
      property bool positionSupported: true
      property bool lengthSupported: true
      property bool canGoPrevious: true
      property bool canGoNext: true
      property bool isPlaying: false
      property real position: 42
      property real length: 180
      property var requests: []
      function seek(offset) { requests.push(offset) }
    }
  }
  Component { id: mediaComponent; QtObject { property var activePlayer: null } }
  Component { id: presenterComponent; Modules.NowPlayingModule { width: 780; height: 520 } }

  function fixture() {
    var player = createTemporaryObject(playerComponent, suite)
    var media = createTemporaryObject(mediaComponent, suite, { activePlayer: player })
    var presenter = createTemporaryObject(presenterComponent, suite, { media: media })
    verify(presenter !== null)
    return { player: player, media: media, presenter: presenter }
  }

  function test_rejectedSkipReturnsToPlayerWithinBound() {
    var f = fixture()
    f.presenter.skip(10)
    compare(f.presenter.displayedPosition, 52)
    compare(f.player.position, 42)
    tryCompare(f.presenter, "optimisticPosition", false, 2000)
    compare(f.presenter.displayedPosition, 42)
  }

  function test_absoluteSeekDoesNotPoisonAuthoritativePosition() {
    var f = fixture()
    f.presenter.seekTo(95)
    compare(f.presenter.displayedPosition, 95)
    // Quickshell's position setter eagerly caches the request even on rejection.
    // Use Seek instead so the getter remains authoritative until Seeked arrives.
    compare(f.player.position, 42)
    compare(JSON.stringify(f.player.requests), JSON.stringify([53]))
    tryCompare(f.presenter, "displayedPosition", 42, 2000)
  }

  function test_playerReportWinsDuringHoldWithoutInterruptingDrag() {
    var f = fixture()
    f.presenter.skip(10)
    f.player.position = 17 // external seek or corrected/rejected request
    compare(f.presenter.displayedPosition, 17)
    compare(f.presenter.optimisticPosition, false)
    f.presenter.seeking = true
    f.presenter.displayedPosition = 80
    f.player.position = 20
    compare(f.presenter.displayedPosition, 80)
    f.presenter.seeking = false
    f.presenter.tickPosition()
    compare(f.presenter.displayedPosition, 20)
  }

  function test_playerReplacementWithIdenticalMetadataResetsTimeline() {
    var f = fixture()
    f.presenter.skip(10)
    f.presenter.seeking = true
    var replacement = createTemporaryObject(playerComponent, suite, {
      position: 7, lengthSupported: false, length: 7
    })
    f.media.activePlayer = replacement
    compare(f.presenter.optimisticPosition, false)
    compare(f.presenter.seeking, false)
    compare(f.presenter.cachedLength, 0)
    compare(f.presenter.displayedPosition, 7)
    f.player.position = 90 // old Connections target must be disconnected
    compare(f.presenter.displayedPosition, 7)
    f.media.activePlayer = null
    compare(f.presenter.displayedPosition, 0)
  }

  function test_sameTitleTrackIdentityResetsButMissingDurationDoesNot() {
    var f = fixture()
    f.player.lengthSupported = false
    f.player.length = 42 // Quickshell fallback, not the actual duration
    compare(f.presenter.effectiveLength, 180)
    f.presenter.seekTo(150)
    compare(f.presenter.displayedPosition, 150)
    compare(JSON.stringify(f.player.requests), JSON.stringify([108]))
    f.player.uniqueId++
    compare(f.presenter.cachedLength, 0)
    compare(f.presenter.optimisticPosition, false)
    compare(f.presenter.displayedPosition, 42)
  }

  function test_acceptedSeekFollowsPlayingAndPausedReports() {
    var f = fixture()
    f.player.isPlaying = true
    f.presenter.seekTo(95)
    f.player.position = 95
    compare(f.presenter.displayedPosition, 95)
    compare(f.presenter.optimisticPosition, false)
    f.player.position = 97.5 // getter owns rate-adjusted progression
    f.presenter.tickPosition()
    compare(f.presenter.displayedPosition, 97.5)
    f.player.isPlaying = false
    wait(600)
    compare(f.presenter.displayedPosition, 97.5)
  }
}
