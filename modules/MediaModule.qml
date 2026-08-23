import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  readonly property var media: shell ? shell.serviceFor("omarchy.media") : null
  readonly property var player: media ? media.activePlayer : null

  Column {
    anchors.fill: parent
    spacing: Style.spacing.controlGap

    Text {
      text: "Media"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.bold: true
    }

    Text {
      width: parent.width
      text: root.player ? (root.player.trackTitle || "Ready to play") : "No media player available"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: root.player ? (root.player.trackArtist || root.player.identity || "") : "Start a player and it will appear here."
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.spacing.controlGap

      Button { text: "󰒮"; foreground: Color.foreground; enabled: root.player && root.player.canGoPrevious; onClicked: root.media.runAction("previous", false) }
      Button { text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"; foreground: Color.foreground; enabled: !!root.player; onClicked: root.media.runAction("playPause", false) }
      Button { text: "󰒭"; foreground: Color.foreground; enabled: root.player && root.player.canGoNext; onClicked: root.media.runAction("next", false) }
    }

    Rectangle { width: parent.width; height: 1; color: Color.muted; opacity: 0.25 }

    AudioMixerModule {
      width: parent.width
      height: Math.max(0, parent.height - y)
    }
  }
}
