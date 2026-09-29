import QtQuick
import "../components"
import "../services"

Item {
  id: root
  objectName: "staticMediaPanel"

  property var shell: null
  property var deck: null
  property var providedMedia: null
  readonly property var hostMedia: shell && typeof shell.serviceFor === "function"
    ? shell.serviceFor("omarchy.media") : null
  readonly property var media: providedMedia || hostMedia || nativeMedia

  MprisMediaAdapter {
    id: nativeMedia
    enabled: !root.providedMedia && !root.hostMedia
  }

  // The card shows one source at a time and swipes between all of them;
  // Watch and other consumers keep the service itself.
  MediaCarousel {
    id: carousel
    source: root.media
    chi: root.deck && root.deck.browserWatchBridge ? root.deck.browserWatchBridge.chiBridge : null
  }

  DeckCard {
    id: nowPlayingCard
    objectName: "nowPlayingPanelCard"
    anchors.fill: parent
    title: "Now Playing"

    NowPlayingModule {
      id: playerSurface
      anchors.fill: parent
      clip: true
      media: carousel
      deck: root.deck
    }
  }
}
