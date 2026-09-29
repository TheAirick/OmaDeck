import QtQuick
import QtTest
import Quickshell
import "../../services" as Stores

TestCase {
  name: "MediaCarousel"
  when: windowShown

  Component { id: playerComponent; QtObject {
    property string identity: "Spotify"; property string dbusName: "org.mpris.MediaPlayer2.spotify"
    property string trackTitle: "Song"; property string trackArtist: "Artist"; property bool isPlaying: false
    property bool canControl: true } }
  Component { id: sourceComponent; QtObject {
    property var players: []; property var activePlayer: players.length ? players[0] : null
    function playerKey(p) { return p ? p.dbusName : "" }
    function playerForKey(k) { for (var p of players) if (p.dbusName === k) return p; return null }
    property var actions: []
    function runAction(action) { actions = actions.concat([action]); return true } } }
  Component { id: chiComponent; QtObject {
    property bool ready: true; property var recent: [107, 9]
    property var tabs: ({ 107: { media_id: "yt", title: "YouTube", playing: false }, 9: { media_id: "x", title: "X", playing: false } })
    signal mediaUpdated(int tabId, var media); signal dropped() } }
  Component { id: carouselComponent; Stores.MediaCarousel {} }

  function fixture() {
    var spotify = createTemporaryObject(playerComponent, this)
    var chiPlayer = createTemporaryObject(playerComponent, this, { identity: "Chi", dbusName: "org.mpris.MediaPlayer2.webkit", trackTitle: "Stale X", isPlaying: true })
    var source = createTemporaryObject(sourceComponent, this, { players: [chiPlayer, spotify] })
    var chi = createTemporaryObject(chiComponent, this)
    var carousel = createTemporaryObject(carouselComponent, this, { source: source, chi: chi })
    return { spotify: spotify, chiPlayer: chiPlayer, source: source, chi: chi, carousel: carousel }
  }
  function keys(c) { return c.entries.map(function(e) { return e.key }) }

  function test_chiExpandsIntoItsRecentVideosAlongsideOtherPlayers() {
    var f = fixture()
    compare(f.carousel.count, 3)
    // Chi's own order leads while nothing has started since OmaDeck came up.
    compare(JSON.stringify(keys(f.carousel)), JSON.stringify(["chi:107", "chi:9", "player:org.mpris.MediaPlayer2.spotify"]))
    compare(f.carousel.selectedChiTab, 107)
    verify(f.carousel.activePlayer === f.chiPlayer)
  }

  function test_startingFollowsButPausingNeverSwitches() {
    var f = fixture()
    f.spotify.isPlaying = true
    compare(f.carousel.selected.key, "player:org.mpris.MediaPlayer2.spotify")
    verify(f.carousel.activePlayer === f.spotify)
    compare(f.carousel.selectedChiTab, -1)
    f.spotify.isPlaying = false
    compare(f.carousel.selected.key, "player:org.mpris.MediaPlayer2.spotify", "a pause keeps the card on Spotify")
    // A Chi video starting with sound brings the card to it, and to the front.
    f.chi.mediaUpdated(9, { media_id: "x", playing: true, muted: false })
    compare(f.carousel.selectedChiTab, 9)
    compare(f.carousel.index, 0)
    f.chi.mediaUpdated(9, { media_id: "x", playing: false, muted: false })
    compare(f.carousel.selectedChiTab, 9)
    // A muted autoplay never takes the card.
    f.chi.mediaUpdated(107, { media_id: "yt", playing: true, muted: true })
    compare(f.carousel.selectedChiTab, 9)
  }

  function test_swipeCyclesAndAVanishedSourceFallsBackToTheNewest() {
    var f = fixture()
    f.carousel.next()
    compare(f.carousel.selectedChiTab, 9)
    f.carousel.next()
    verify(f.carousel.activePlayer === f.spotify)
    f.carousel.next()
    compare(f.carousel.selectedChiTab, 107)
    f.carousel.previous()
    verify(f.carousel.activePlayer === f.spotify)
    f.source.players = [f.chiPlayer]
    compare(f.carousel.count, 2)
    compare(f.carousel.selectedChiTab, 107)
    // Chi disconnected: its WebKit player remains as one plain source.
    f.chi.ready = false
    compare(f.carousel.count, 1)
    verify(f.carousel.activePlayer === f.chiPlayer)
    compare(f.carousel.selectedChiTab, -1)
  }

  function test_playPauseSendsMprisPlayPauseToTheSelectedPlayer() {
    var f = fixture()
    Quickshell.detached = []
    verify(f.carousel.runAction("playPause", false, "org.mpris.MediaPlayer2.spotify"))
    compare(JSON.stringify(Quickshell.detached), JSON.stringify([["/usr/bin/busctl", "--user", "call",
      "org.mpris.MediaPlayer2.spotify", "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "PlayPause"]]))
    compare(f.source.actions.length, 0)
    // Other actions, and players that refuse control, keep the media service's path.
    verify(f.carousel.runAction("next", false, "org.mpris.MediaPlayer2.spotify"))
    f.spotify.canControl = false
    verify(f.carousel.runAction("playPause", false, "org.mpris.MediaPlayer2.spotify"))
    compare(JSON.stringify(f.source.actions), JSON.stringify(["next", "playPause"]))
    compare(Quickshell.detached.length, 1)
  }
}
