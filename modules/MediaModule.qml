import QtQuick
import "../components"
import "../services"

Item {
  id: root
  objectName: "staticMediaPanel"

  property var shell: null
  readonly property var hostMedia: shell && typeof shell.serviceFor === "function"
    ? shell.serviceFor("omarchy.media") : null
  readonly property var media: hostMedia || nativeMedia

  MprisMediaAdapter {
    id: nativeMedia
    enabled: !root.hostMedia
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
      media: root.media
    }
  }
}
