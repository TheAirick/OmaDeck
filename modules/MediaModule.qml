import QtQuick
import "../components"

Item {
  id: root
  objectName: "staticMediaPanel"

  property var shell: null
  readonly property var media: shell ? shell.serviceFor("omarchy.media") : null

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
