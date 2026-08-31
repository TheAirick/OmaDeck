import QtQuick
import qs.Commons
import "../components"

Item {
  id: root
  objectName: "mediaPanelHost"

  property var shell: null
  readonly property var media: shell ? shell.serviceFor("omarchy.media") : null
  readonly property int panelGap: Style.spacing.panelGap
  readonly property real splitHeight: Math.max(0, height - panelGap)
  readonly property real nowPlayingHeight: Math.round(splitHeight * 0.573)
  readonly property real mixerHeight: Math.max(0, splitHeight - nowPlayingHeight)

  clip: true

  function setMixerCompact(compact) { mixer.compact = compact }
  function setMixerCategory(category) {
    mixer.compact = false
    mixer.expandedCategory = ["media", "games", "voice", "other"].indexOf(category) !== -1 ? category : ""
  }

  DeckCard {
    id: nowPlayingCard
    objectName: "nowPlayingPanelCard"
    width: parent.width
    height: root.nowPlayingHeight
    title: "Now Playing"

    NowPlayingModule {
      id: playerSurface
      anchors.fill: parent
      clip: true
      media: root.media
    }
  }

  DeckCard {
    id: mixerCard
    objectName: "audioMixerPanelCard"
    y: root.nowPlayingHeight + root.panelGap
    width: parent.width
    height: root.mixerHeight
    title: "Audio Mixer"

    AudioMixerModule {
      id: mixer
      anchors.fill: parent
    }
  }
}
