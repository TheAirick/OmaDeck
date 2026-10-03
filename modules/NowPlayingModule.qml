import QtQuick
import "../components" as Components
import qs.Commons
import "../theme"
import qs.Ui
import "MediaArtwork.js" as MediaArtwork
import "../services/WatchSource.js" as WatchSource

Item {
  id: root
  objectName: "nowPlayingPresenter"

  property var media: null
  property var deck: null
  readonly property var player: media ? media.activePlayer : null
  readonly property bool hasPlayer: !!player
  // WebKit publishes one MPRIS player for all of Chi and it can stay on an
  // older video (X after muting itself). For Chi, show and control the Chi
  // tab the source carousel selected, else the one Chi reports as now playing.
  readonly property var chiBridge: deck && deck.browserWatchBridge ? deck.browserWatchBridge.chiBridge : null
  readonly property int chiTab: media && typeof media.selectedChiTab === "number" && media.selectedChiTab >= 0
    ? media.selectedChiTab : (chiBridge ? chiBridge.nowPlaying : -1)
  readonly property var chiMedia: player && String(player.identity) === "Chi" && chiBridge && chiBridge.ready
    && chiTab >= 0 && chiBridge.tabs[chiTab] ? chiBridge.tabs[chiTab] : null
  // Sources to swipe between (players and Chi's recent videos).
  readonly property int sourceCount: media && typeof media.count === "number" ? media.count : (hasPlayer ? 1 : 0)
  readonly property int sourceIndex: media && typeof media.index === "number" ? media.index : 0
  // WebKit's player can keep reporting "Playing" for a video Chi has paused.
  readonly property bool isPlaying: chiMedia ? !!chiMedia.playing : !!(player && player.isPlaying)
  readonly property string displayTitle: chiMedia ? (chiMedia.title || playbackStatus)
    : player ? (player.trackTitle || playbackStatus) : playbackStatus
  readonly property string displayArtist: chiMedia ? (chiMedia.artist || "Chi")
    : player ? (player.trackArtist || player.identity || "") : ""
  readonly property string playerKey: player && media && typeof media.playerKey === "function"
    ? media.playerKey(player) : ""
  readonly property var watchCandidate: (deck && deck.browserWatchBridge
      ? deck.browserWatchBridge.candidateForPlayer(playerKey, player, chiTab) : null)
    || WatchSource.candidate(player, playerKey)
  readonly property bool canPlayPause: !!chiMedia || hasPlayer && !!(player.canTogglePlaying
    || (player.isPlaying ? player.canPause : player.canPlay))
  readonly property string playbackStatus: !media ? "Media service unavailable"
    : !hasPlayer ? "No media player detected"
    : chiMedia ? (chiMedia.playing ? "Playing" : "Paused")
    : player.isPlaying ? (canPlayPause ? "Playing" : "Playing · controls unavailable")
    : player.playbackState === 0 ? "Stopped"
    : canPlayPause ? "Paused" : "Playback controls unavailable"

  function runTransport(action) {
    // Omarchy's untargeted action policy can select a different playing source.
    // Refuse stale identities: its targeted API otherwise falls back globally.
    if (chiMedia) return action === "playPause" && chiBridge.controlNowPlaying({ action: "toggle" }, chiTab)
    var target = player
    var key = playerKey
    if (!target || !key || !media || typeof media.playerForKey !== "function"
        || media.playerForKey(key) !== target || typeof media.runAction !== "function") return false
    if (action === "playPause" && !canPlayPause) return false
    if (action === "previous" && !target.canGoPrevious) return false
    if (action === "next" && !target.canGoNext) return false
    return media.runAction(action, false, key)
  }
  readonly property bool canSkip: chiMedia ? chiMedia.duration_ms > 0 : hasPlayer && player.canSeek && player.positionSupported
  readonly property string trackKey: chiMedia ? "chi|" + chiMedia.media_id
    : player ? [player.uniqueId, player.trackTitle || "", player.trackArtist || ""].join("|") : ""
  readonly property real effectiveLength: chiMedia ? (chiMedia.duration_ms || 0) / 1000
    : player && player.lengthSupported && player.length > 0 ? player.length : cachedLength
  readonly property bool canSeek: canSkip && effectiveLength > 0
  readonly property bool showSecondarySeek: true
  property string cachedArtworkKey: ""
  property string cachedArtworkUrl: ""
  readonly property string publishedArtworkUrl: chiMedia
    ? String(chiMedia.artwork || MediaArtwork.youtubeThumbnail(String(chiMedia.page_url || "")) || "")
    : player && player.trackArtUrl ? String(player.trackArtUrl) : ""
  readonly property string artworkTrackUrl: MediaArtwork.trackUrl(player)
  readonly property string artworkKey: chiMedia ? [displayTitle, displayArtist, String(chiMedia.page_url || "")].join("|")
    : player ? [player.trackTitle || "", player.trackArtist || "", artworkTrackUrl].join("|") : ""
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
  function refreshPosition() {
    if (seeking) return
    displayedPosition = chiMedia ? (chiMedia.position_ms || 0) / 1000 : player && player.positionSupported ? player.position : 0
  }
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
    if (chiMedia) {
      var target = clampPosition(value)
      if (!chiBridge.controlNowPlaying({ action: "seek", position_ms: Math.round(target * 1000) }, chiTab)) return
      displayedPosition = target
      optimisticPosition = true
      optimisticUntil = Date.now() + 1000
      return
    }
    // 0.3.1's position setter caches even rejected requests. Seek leaves the
    // getter intact until the player reports Seeked, including without duration.
    player.seek(clampPosition(value) - player.position)
    displayedPosition = clampPosition(value)
    optimisticPosition = true
    optimisticUntil = Date.now() + 1000
  }
  function skip(seconds) {
    if (!canSkip) return
    if (chiMedia) { seekTo(displayedPosition + seconds); return }
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
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(44)
        text: root.formatTime(root.displayedPosition)
        color: DeckColors.secondaryText
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
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(44)
        text: root.effectiveLength > 0 ? root.formatTime(root.effectiveLength) : "—:—"
        color: DeckColors.secondaryText
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
      height: Math.max(0, Math.min(width * 9 / 16,
        parent.height - timeline.height - metadataOverlay.height - Style.space(72)
          - Style.spacing.controlGap * 3))
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
      // Swipe the artwork to switch sources; the dots show where you are.
      DragHandler {
        objectName: "nowPlayingSourceSwipe"
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        enabled: root.sourceCount > 1
        property real swipe: 0
        onActiveTranslationChanged: if (active) swipe = activeTranslation.x
        onActiveChanged: {
          if (active) { swipe = 0; return }
          if (Math.abs(swipe) < Style.space(48)) return
          if (swipe < 0) root.media.next()
          else root.media.previous()
        }
      }
      Row {
        objectName: "nowPlayingSourceDots"
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Style.space(6)
        spacing: Style.space(6)
        visible: root.sourceCount > 1
        Repeater {
          model: root.sourceCount
          Rectangle {
            required property int index
            width: Style.space(7)
            height: width
            radius: width / 2
            color: index === root.sourceIndex ? Color.accent : Qt.rgba(1, 1, 1, 0.45)
            TapHandler { onTapped: root.media.select(index) }
          }
        }
      }
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        visible: artworkImage.status !== Image.Ready
        text: "󰝚"
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.displayLarge
      }

    }

    Rectangle {
      id: metadataOverlay
      objectName: "nowPlayingMetadataOverlay"
      anchors.left: artwork.left
      anchors.right: artwork.right
      anchors.top: artwork.bottom
      height: Math.max(metadataColumn.implicitHeight, watchHere.visible ? watchHere.height : 0)
        + Style.spacing.controlGap * 2
      color: DeckColors.surface
      z: 2

      Button {
        id: watchHere
        objectName: "watchHereButton"
        Accessible.name: "Watch this video on the Edge"
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.margins: Style.spacing.controlGap
        width: Style.space(104)
        height: Style.space(44)
        text: root.deck && root.deck.watchController.active ? "Opening…"
          : root.deck && root.deck.watchController.shuttingDown ? "Closing…" : "Watch here"
        fontSize: Style.font.caption
        tooltipText: root.watchCandidate && root.watchCandidate.sourceKind === "extension"
          ? "Watch this video on the Edge" : "Load or reload the OmaDeck Watch browser add-on"
        background: "transparent"
        foreground: Color.accent
        bordered: false
        borderSpec: Border.none()
        visible: !!root.watchCandidate && !!root.deck
        enabled: visible && !root.deck.watchController.active && !root.deck.watchController.shuttingDown
        z: 4
        onClicked: root.deck.startWatch(root.watchCandidate)
      }

      Column {
        id: metadataColumn
        anchors.fill: parent
        anchors.rightMargin: watchHere.visible ? watchHere.width + Style.spacing.controlGap * 2 : Style.spacing.controlGap
        anchors.margins: Style.spacing.controlGap
        spacing: Style.spacing.labelGap

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.displayTitle
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
          maximumLineCount: 1
          elide: Text.ElideRight
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.deck && root.deck.watchController.notice && !root.deck.watchController.active
              ? root.deck.watchController.notice
              : root.player ? [root.displayArtist, root.playbackStatus].filter(Boolean).join(" · ")
            : root.media ? "Compatible players appear here." : "Waiting for Omarchy media."
          color: DeckColors.secondaryText
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          maximumLineCount: 1
          elide: Text.ElideRight
        }
      }
    }

    Item {
      id: controlBand
      objectName: "nowPlayingControlBand"
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: metadataOverlay.bottom
      anchors.topMargin: Style.spacing.controlGap
      anchors.bottom: timeline.top
      anchors.bottomMargin: Style.spacing.controlGap

      Row {
        id: controls
        objectName: "nowPlayingControls"
        anchors.centerIn: parent
        spacing: Style.spacing.labelGap

        Button {
          Accessible.name: "Previous track"
          iconText: "󰒮"; iconSize: Style.font.iconLarge * 2.2; foreground: Color.accent
          width: Style.space(52); height: Style.space(72)
          horizontalPadding: 0; verticalPadding: 0
          color: "transparent"; borderSpec: Border.none()
          enabled: root.player && root.player.canGoPrevious; opacity: enabled ? 1 : 0.35
          onClicked: root.runTransport("previous")
        }
        Button {
          objectName: "seekBackwardControl"
          foreground: Color.accent
          Accessible.name: "Seek backward 10 seconds"
          width: Style.space(52); height: Style.space(72)
          horizontalPadding: 0; verticalPadding: 0
          color: "transparent"; borderSpec: Border.none()
          visible: root.showSecondarySeek
          enabled: root.canSkip; opacity: enabled ? 1 : 0.35; onClicked: root.skip(-10)

          Components.CircularSeekIcon {
            objectName: "seekBackwardIcon"
            anchors.centerIn: parent
            forward: false
            strokeColor: parent.foreground
          }
        }
        Button {
          id: playPauseControl
          objectName: "playPauseControl"
          // Status already lives on the artwork. Native touch is delivered as
          // mouse events, so hover tooltips can outlive the finger contact.
          Accessible.name: root.isPlaying ? "Pause" : "Play"
          iconText: root.isPlaying ? "󰏤" : "󰐊"
          iconSize: Style.font.displayLarge * 2; foreground: Color.accent
          width: Style.space(72); height: Style.space(72)
          horizontalPadding: 0; verticalPadding: 0
          color: "transparent"; borderSpec: Border.none()
          enabled: root.canPlayPause && root.playerKey !== ""; opacity: enabled ? 1 : 0.35
          onClicked: root.runTransport("playPause")
        }
        Button {
          objectName: "seekForwardControl"
          foreground: Color.accent
          Accessible.name: "Seek forward 10 seconds"
          width: Style.space(52); height: Style.space(72)
          horizontalPadding: 0; verticalPadding: 0
          color: "transparent"; borderSpec: Border.none()
          visible: root.showSecondarySeek
          enabled: root.canSkip; opacity: enabled ? 1 : 0.35; onClicked: root.skip(10)

          Components.CircularSeekIcon {
            objectName: "seekForwardIcon"
            anchors.centerIn: parent
            forward: true
            strokeColor: parent.foreground
          }
        }
        Button {
          Accessible.name: "Next track"
          iconText: "󰒭"; iconSize: Style.font.iconLarge * 2.2; foreground: Color.accent
          width: Style.space(52); height: Style.space(72)
          horizontalPadding: 0; verticalPadding: 0
          color: "transparent"; borderSpec: Border.none()
          enabled: root.player && root.player.canGoNext; opacity: enabled ? 1 : 0.35
          onClicked: root.runTransport("next")
        }
      }
    }
  }
}
