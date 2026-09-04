import QtQuick
import qs.Commons
import qs.Ui
import "MediaArtwork.js" as MediaArtwork

Item {
  id: root
  objectName: "nowPlayingPresenter"

  property var media: null
  readonly property var player: media ? media.activePlayer : null
  readonly property bool hasPlayer: !!player
  readonly property bool canSkip: hasPlayer && player.canSeek && player.positionSupported
  readonly property string trackKey: player ? [player.uniqueId, player.trackTitle || "", player.trackArtist || ""].join("|") : ""
  readonly property real effectiveLength: player && player.lengthSupported && player.length > 0 ? player.length : cachedLength
  readonly property bool canSeek: canSkip && effectiveLength > 0
  readonly property bool showSecondarySeek: true
  property string cachedArtworkKey: ""
  property string cachedArtworkUrl: ""
  readonly property string publishedArtworkUrl: player && player.trackArtUrl ? String(player.trackArtUrl) : ""
  readonly property string artworkTrackUrl: MediaArtwork.trackUrl(player)
  readonly property string artworkKey: player
    ? [player.trackTitle || "", player.trackArtist || "", artworkTrackUrl].join("|") : ""
  readonly property string derivedArtworkUrl: MediaArtwork.youtubeThumbnail(artworkTrackUrl)
  readonly property string artworkUrl: publishedArtworkUrl
    || (cachedArtworkKey === artworkKey ? cachedArtworkUrl : "")
    || derivedArtworkUrl
  property real displayedPosition: 0
  property real cachedLength: 0
  property bool seeking: false
  property bool optimisticPosition: false
  property real optimisticUntil: 0

  // Quickshell deliberately returns the current position from `length` when
  // MPRIS duration metadata disappears. Always clamp against our last real
  // duration instead, or a late seek gets capped to the old playhead.
  function clampPosition(value) { return Math.max(0, Math.min(effectiveLength > 0 ? effectiveLength : value, value)) }
  function refreshPosition() { if (!seeking) displayedPosition = player && player.positionSupported ? player.position : 0 }
  function tickPosition() {
    if (seeking) return
    // Hold for at most one second plus the 500ms sampling interval. Never
    // integrate a second clock: Quickshell's getter accounts for pause/rate.
    if (optimisticPosition && Date.now() < optimisticUntil) return
    optimisticPosition = false
    refreshPosition()
  }
  function captureDuration() {
    if (player && player.lengthSupported && player.length > 0) cachedLength = player.length
  }
  function captureArtwork() {
    if (!publishedArtworkUrl) return
    cachedArtworkKey = artworkKey
    cachedArtworkUrl = publishedArtworkUrl
  }
  function seekTo(value) {
    if (!canSeek) return
    // 0.3.1's position setter caches even rejected requests. Seek leaves the
    // getter intact until the player reports Seeked, including without duration.
    player.seek(clampPosition(value) - player.position)
    displayedPosition = clampPosition(value)
    optimisticPosition = true
    optimisticUntil = Date.now() + 1000
  }
  function skip(seconds) {
    if (!canSkip) return
    player.seek(seconds)
    displayedPosition = clampPosition(displayedPosition + seconds)
    optimisticPosition = true
    optimisticUntil = Date.now() + 1000
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

  onPlayerChanged: { seeking = false; cachedLength = 0; optimisticPosition = false; refreshPosition(); captureDuration(); captureArtwork() }
  onTrackKeyChanged: { cachedLength = 0; optimisticPosition = false; captureDuration(); refreshPosition() }
  onArtworkKeyChanged: captureArtwork()
  onPublishedArtworkUrlChanged: captureArtwork()
  Component.onCompleted: captureArtwork()
  Timer {
    id: positionTimer
    objectName: "nowPlayingPositionTimer"
    interval: 500
    running: root.hasPlayer
    repeat: true
    onTriggered: { root.captureDuration(); root.tickPosition() }
  }
  Connections {
    target: root.player
    function onPositionChanged() { root.optimisticPosition = false; root.refreshPosition() }
    function onLengthChanged() { root.captureDuration() }
    function onLengthSupportedChanged() { root.captureDuration() }
  }

  component CircularSeekIcon: Canvas {
    id: seekIcon

    required property bool forward
    property color strokeColor: Color.accent

    width: Style.space(34)
    height: Style.space(34)
    antialiasing: true
    transform: Scale {
      origin.x: seekIcon.width / 2
      origin.y: seekIcon.height / 2
      xScale: seekIcon.forward ? 1 : -1
    }

    onPaint: {
      var context = getContext("2d")
      var centerX = width / 2
      var centerY = height / 2
      var radius = Math.min(width, height) * 0.34
      context.clearRect(0, 0, width, height)
      context.save()
      context.strokeStyle = strokeColor
      context.fillStyle = strokeColor
      context.lineWidth = Style.space(3)
      context.lineCap = "round"
      context.lineJoin = "round"
      context.beginPath()
      context.arc(centerX, centerY, radius, 0, Math.PI * 1.5, false)
      context.stroke()
      context.beginPath()
      context.moveTo(centerX + Style.space(6), centerY - radius)
      context.lineTo(centerX - Style.space(1), centerY - radius - Style.space(4.5))
      context.lineTo(centerX - Style.space(1), centerY - radius + Style.space(4.5))
      context.closePath()
      context.fill()
      context.restore()
    }

    onStrokeColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()
  }

  Item {
    anchors.fill: parent

    Row {
      id: timeline
      objectName: "nowPlayingTimeline"
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
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

    BorderSurface {
      id: artwork
      objectName: "nowPlayingArtwork"
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(parent.width, Style.space(360))
      height: Math.max(0, Math.min(width * 0.6,
        parent.height - timeline.height - Style.space(88)))
      radius: Style.cornerRadius
      color: Style.normalFill
      borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent, Color.urgent)
      clip: true

      Image {
        id: artworkImage
        anchors.fill: parent
        anchors.margins: artwork.borderLeft
        source: root.artworkUrl
        fillMode: Image.PreserveAspectCrop
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        asynchronous: true
        cache: true
        visible: status === Image.Ready
      }
      Text {
        anchors.centerIn: parent
        visible: artworkImage.status !== Image.Ready
        text: "󰝚"
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.displayLarge
      }

      Rectangle {
        id: metadataOverlay
        objectName: "nowPlayingMetadataOverlay"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: artwork.borderLeft
        height: Math.min(parent.height,
          metadataColumn.implicitHeight + Style.spacing.controlGap * 2)
        color: Qt.rgba(Color.popups.background.r, Color.popups.background.g,
          Color.popups.background.b, 0.86)
        z: 2

        Column {
          id: metadataColumn
          anchors.fill: parent
          anchors.margins: Style.spacing.controlGap
          spacing: Style.spacing.labelGap

          Text {
            width: parent.width
            text: root.player ? (root.player.trackTitle || "Ready to play") : "Nothing playing"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            maximumLineCount: 1
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: root.player ? (root.player.trackArtist || root.player.identity || "") : "Start a player and it will appear here."
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            maximumLineCount: 1
            elide: Text.ElideRight
          }
        }
      }
    }

    Item {
      id: controlBand
      objectName: "nowPlayingControlBand"
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: artwork.bottom
      anchors.topMargin: Style.spacing.controlGap
      anchors.bottom: timeline.top
      anchors.bottomMargin: Style.spacing.controlGap

      Row {
        id: controls
        objectName: "nowPlayingControls"
        anchors.centerIn: parent
        spacing: Style.spacing.labelGap

        Button {
          iconText: "󰒮"; iconSize: Style.font.iconLarge * 2.2; foreground: Color.accent
          width: Style.space(52); height: Style.space(72)
          horizontalPadding: 0; verticalPadding: 0
          color: "transparent"; borderSpec: Border.none()
          enabled: root.player && root.player.canGoPrevious; opacity: enabled ? 1 : 0.35
          onClicked: root.media.runAction("previous", false)
        }
        Button {
          objectName: "seekBackwardControl"
          foreground: Color.accent
          tooltipText: "Seek backward"
          width: Style.space(52); height: Style.space(72)
          horizontalPadding: 0; verticalPadding: 0
          color: "transparent"; borderSpec: Border.none()
          visible: root.showSecondarySeek
          enabled: root.canSkip; opacity: enabled ? 1 : 0.35; onClicked: root.skip(-10)

          CircularSeekIcon {
            objectName: "seekBackwardIcon"
            anchors.centerIn: parent
            forward: false
            strokeColor: parent.foreground
          }
        }
        Button {
          id: playPauseControl
          iconText: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
          iconSize: Style.font.displayLarge * 2; foreground: Color.accent
          width: Style.space(72); height: Style.space(72)
          horizontalPadding: 0; verticalPadding: 0
          color: "transparent"; borderSpec: Border.none()
          enabled: root.hasPlayer; opacity: enabled ? 1 : 0.35
          onClicked: root.media.runAction("playPause", false)
        }
        Button {
          objectName: "seekForwardControl"
          foreground: Color.accent
          tooltipText: "Seek forward"
          width: Style.space(52); height: Style.space(72)
          horizontalPadding: 0; verticalPadding: 0
          color: "transparent"; borderSpec: Border.none()
          visible: root.showSecondarySeek
          enabled: root.canSkip; opacity: enabled ? 1 : 0.35; onClicked: root.skip(10)

          CircularSeekIcon {
            objectName: "seekForwardIcon"
            anchors.centerIn: parent
            forward: true
            strokeColor: parent.foreground
          }
        }
        Button {
          iconText: "󰒭"; iconSize: Style.font.iconLarge * 2.2; foreground: Color.accent
          width: Style.space(52); height: Style.space(72)
          horizontalPadding: 0; verticalPadding: 0
          color: "transparent"; borderSpec: Border.none()
          enabled: root.player && root.player.canGoNext; opacity: enabled ? 1 : 0.35
          onClicked: root.media.runAction("next", false)
        }
      }
    }
  }
}
