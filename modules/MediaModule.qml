import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  readonly property var media: shell ? shell.serviceFor("omarchy.media") : null
  readonly property var player: media ? media.activePlayer : null
  readonly property bool hasPlayer: !!player
  readonly property bool canSkip: hasPlayer && player.canSeek && player.positionSupported
  readonly property string trackKey: player ? [player.trackTitle || "", player.trackArtist || ""].join("|") : ""
  readonly property real effectiveLength: player && player.lengthSupported && player.length > 0 ? player.length : cachedLength
  readonly property bool canSeek: canSkip && effectiveLength > 0
  property real displayedPosition: 0
  property real cachedLength: 0
  property bool seeking: false

  function clampPosition(value) { return Math.max(0, Math.min(player ? player.length : 0, value)) }
  function refreshPosition() { if (!seeking) displayedPosition = player && player.positionSupported ? player.position : 0 }
  function captureDuration() {
    if (player && player.lengthSupported && player.length > 0) cachedLength = player.length
  }
  function seekTo(value) {
    if (!canSeek) return
    player.position = clampPosition(value)
    displayedPosition = clampPosition(value)
  }
  function skip(seconds) {
    if (!canSkip) return
    player.position = Math.max(0, (player.positionSupported ? player.position : displayedPosition) + seconds)
    refreshPosition()
  }
  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0) return "0:00"
    var whole = Math.floor(seconds)
    var hours = Math.floor(whole / 3600)
    var minutes = Math.floor((whole % 3600) / 60)
    var secs = whole % 60
    if (hours > 0) return hours + ":" + String(minutes).padStart(2, "0") + ":" + String(secs).padStart(2, "0")
    return minutes + ":" + String(secs).padStart(2, "0")
  }

  onPlayerChanged: { refreshPosition(); captureDuration() }
  onTrackKeyChanged: { cachedLength = 0; captureDuration(); refreshPosition() }
  Timer {
    interval: 500
    running: root.hasPlayer
    repeat: true
    onTriggered: { root.captureDuration(); root.refreshPosition() }
  }
  Connections {
    target: root.player
    function onLengthChanged() { root.captureDuration() }
    function onLengthSupportedChanged() { root.captureDuration() }
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

  Item {
    id: playerSurface
    anchors.top: heading.bottom
    anchors.topMargin: Style.spacing.controlGap
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: mixer.contentHeight + Style.spacing.controlGap
    clip: true

    Column {
      anchors.fill: parent
      spacing: Style.spacing.controlGap

      Item {
        id: hero
        width: parent.width
        height: Math.max(0, parent.height - timeline.height - parent.spacing)

        BorderSurface {
          id: artwork
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: Math.min(height, Style.space(150))
          radius: Style.cornerRadius
          color: Style.normalFill
          borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)
          clip: true

          Image {
            anchors.fill: parent
            anchors.margins: artwork.borderLeft
            source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: status === Image.Ready
          }
          Text {
            anchors.centerIn: parent
            visible: !root.player || !root.player.trackArtUrl
            text: "󰝚"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          anchors.left: artwork.right
          anchors.leftMargin: Style.spacing.panelGap
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          spacing: Style.spacing.labelGap

          Text {
            width: parent.width
            text: root.player ? (root.player.trackTitle || "Ready to play") : "Nothing playing"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            maximumLineCount: 2
            wrapMode: Text.Wrap
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
          Text {
            width: parent.width
            visible: text !== ""
            text: root.player && root.player.trackAlbum ? root.player.trackAlbum : ""
            color: Color.muted
            opacity: 0.7
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
          Item { width: 1; height: Math.max(0, parent.height - controls.height - y) }

          Row {
            id: controls
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.spacing.controlGap

            Button {
              iconText: "󰒮"; iconSize: Style.font.iconLarge; foreground: Color.accent
              width: Style.space(42); height: Style.space(42)
              enabled: root.player && root.player.canGoPrevious; opacity: enabled ? 1 : 0.35
              onClicked: root.media.runAction("previous", false)
            }
            Button {
              text: "−10"; fontSize: Style.font.body; foreground: Color.accent
              width: Style.space(42); height: Style.space(42)
              enabled: root.canSkip; opacity: enabled ? 1 : 0.35; onClicked: root.skip(-10)
            }
            Button {
              iconText: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
              iconSize: Style.font.displayLarge; horizontalPadding: Style.spacing.panelGap
              verticalPadding: Style.spacing.controlPaddingY; foreground: Color.accent
              width: Style.space(50); height: Style.space(46)
              enabled: root.hasPlayer; opacity: enabled ? 1 : 0.35
              onClicked: root.media.runAction("playPause", false)
            }
            Button {
              text: "+10"; fontSize: Style.font.body; foreground: Color.accent
              width: Style.space(42); height: Style.space(42)
              enabled: root.canSkip; opacity: enabled ? 1 : 0.35; onClicked: root.skip(10)
            }
            Button {
              iconText: "󰒭"; iconSize: Style.font.iconLarge; foreground: Color.accent
              width: Style.space(42); height: Style.space(42)
              enabled: root.player && root.player.canGoNext; opacity: enabled ? 1 : 0.35
              onClicked: root.media.runAction("next", false)
            }
          }
        }
      }

      Row {
        id: timeline
        width: parent.width
        height: Style.space(30)
        spacing: Style.spacing.controlGap

        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(44)
          text: root.formatTime(root.displayedPosition)
          color: Color.muted
          horizontalAlignment: Text.AlignRight
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        PanelSlider {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(88) - parent.spacing * 2
          minimum: 0
          maximum: Math.max(1, root.effectiveLength)
          value: root.canSeek ? root.displayedPosition : 0
          enabled: root.canSeek
          fillColor: Color.accent
          knobColor: Color.accent
          onMoved: value => { root.seeking = true; root.displayedPosition = value }
          onReleased: value => { root.seekTo(value); root.seeking = false }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(44)
          text: root.effectiveLength > 0 ? root.formatTime(root.effectiveLength) : "—:—"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
