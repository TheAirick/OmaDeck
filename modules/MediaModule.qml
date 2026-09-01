import QtQuick
import qs.Commons
import "../components"

Item {
  id: root
  objectName: "mediaPanelHost"

  property var shell: null
  readonly property var media: shell ? shell.serviceFor("omarchy.media") : null
  readonly property int panelGap: Style.spacing.panelGap
  readonly property bool mixerExpanded: !mixer.compact
  readonly property real mixerCardWidth: Math.min(width,
    mixer.preferredWidth + Style.spacing.panelPadding * 2)
  readonly property real nowPlayingWidth: Math.max(0, width - mixerCardWidth - panelGap)
  readonly property real preferredDrawerWidth: mixer.preferredWidth
    + Style.spacing.panelPadding * 2 + panelGap + Style.space(360)

  clip: true

  function setMixerCompact(compact) { mixer.compact = compact }
  function setMixerCategory(category) {
    mixer.compact = false
    mixer.expandedCategory = ["media", "games", "voice", "other"].indexOf(category) !== -1 ? category : ""
  }

  DeckCard {
    id: mixerCard
    objectName: "audioMixerPanelCard"
    width: root.mixerCardWidth
    height: parent.height
    title: "Volume"

    AudioMixerModule {
      id: mixer
      anchors.fill: parent
    }
  }

  DeckCard {
    id: nowPlayingCard
    objectName: "nowPlayingPanelCard"
    x: root.mixerCardWidth + root.panelGap
    width: root.nowPlayingWidth
    height: parent.height
    title: "Now Playing"

    NowPlayingModule {
      id: playerSurface
      anchors.fill: parent
      clip: true
      media: root.media
    }
  }
}
