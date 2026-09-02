import QtQuick
import qs.Commons
import "../components"

Item {
  id: root
  objectName: "volumePanelHost"

  readonly property bool mixerExpanded: !mixer.compact
  readonly property real preferredDrawerWidth: mixer.preferredWidth
    + Style.spacing.panelPadding * 2

  function setMixerCompact(compact) { mixer.compact = compact }
  function setMixerCategory(category) {
    mixer.compact = false
    mixer.expandedCategory = ["media", "games", "voice", "other"].indexOf(category) !== -1 ? category : ""
  }

  DeckCard {
    id: mixerCard
    objectName: "audioMixerPanelCard"
    anchors.fill: parent
    title: "Volume"

    AudioMixerModule {
      id: mixer
      anchors.fill: parent
    }
  }
}
