import QtQuick
import qs.Commons

Item {
  id: root

  property var shell: null
  readonly property var media: shell ? shell.serviceFor("omarchy.media") : null

  function setMixerCompact(compact) { mixer.compact = compact }
  function setMixerCategory(category) {
    mixer.compact = false
    mixer.expandedCategory = ["media", "games", "voice", "other"].indexOf(category) !== -1 ? category : ""
  }

  Text {
    id: heading
    anchors.top: parent.top
    anchors.left: parent.left
    text: "Media"
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.title
    font.bold: true
  }

  AudioMixerModule {
    id: mixer
    anchors.top: heading.bottom
    anchors.topMargin: Style.spacing.controlGap
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
  }

  NowPlayingModule {
    id: playerSurface
    anchors.top: heading.bottom
    anchors.topMargin: Style.spacing.controlGap
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: mixer.contentHeight + Style.spacing.controlGap
    clip: true
    media: root.media
  }
}