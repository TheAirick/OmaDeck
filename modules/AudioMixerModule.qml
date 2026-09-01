import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui
import "AudioModel.js" as AudioModel

Item {
  id: root
  objectName: "audioMixerPresenter"
  clip: true

  property string expandedCategory: ""
  property var displayStreams: []
  property string volumeSinkName: ""
  property bool compact: true
  readonly property int activeCategoryCount:
    Number(streamsFor("media").length > 0)
    + Number(streamsFor("games").length > 0)
    + Number(streamsFor("voice").length > 0)
    + Number(streamsFor("other").length > 0)
  readonly property int expandedSliderCount: 2 + activeCategoryCount
  readonly property real toggleReserve: root.compact ? 0
    : Style.spacing.labelGap + Style.space(32)
  readonly property real preferredWidth: root.compact ? Style.space(70)
    : expandedSliderCount * Style.space(70)
      + Math.max(0, expandedSliderCount - 1) * Style.spacing.controlGap
      + toggleReserve

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var defaultSink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var volumeSink: {
    if (!volumeSinkName || !defaultSink || volumeSinkName === String(defaultSink.name)) return defaultSink
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i]
      if (node && node.isSink && !node.isStream && String(node.name) === volumeSinkName && node.audio) return node
    }
    return defaultSink
  }
  readonly property var liveStreams: {
    var result = []
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i]
      if (!node || !node.audio || !AudioModel.isPlaybackStream(node)) continue
      if (String(node.name || "").indexOf("omarchy_speaker_tuning") === 0) continue
      result.push(node)
    }
    return result
  }

  function clamp(value) { return Math.max(0, Math.min(1, value)) }
  function streamAudio(stream) { return stream && stream.audio ? stream.audio : null }
  function streamsFor(category) {
    var result = []
    for (var i = 0; i < displayStreams.length; i++)
      if (AudioModel.categoryFor(displayStreams[i]) === category) result.push(displayStreams[i])
    return result
  }
  function categoryVolume(category) {
    var streams = streamsFor(category)
    var maximum = 0
    for (var i = 0; i < streams.length; i++) {
      var audio = streamAudio(streams[i])
      if (audio) maximum = Math.max(maximum, audio.volume)
    }
    return maximum
  }
  function categoryMuted(category) {
    var streams = streamsFor(category)
    var hasAudio = false
    for (var i = 0; i < streams.length; i++) {
      var audio = streamAudio(streams[i])
      if (!audio) continue
      hasAudio = true
      if (!audio.muted) return false
    }
    return hasAudio
  }
  function setCategoryVolume(category, target) {
    var streams = streamsFor(category)
    var current = categoryVolume(category)
    for (var i = 0; i < streams.length; i++) {
      var audio = streamAudio(streams[i])
      if (audio) audio.volume = current > 0 ? clamp(audio.volume * target / current) : clamp(target)
    }
  }
  function toggleCategoryMute(category) {
    var streams = streamsFor(category)
    var next = !categoryMuted(category)
    for (var i = 0; i < streams.length; i++) {
      var audio = streamAudio(streams[i])
      if (audio) audio.muted = next
    }
  }
  function refreshStreams() { displayStreams = liveStreams.slice() }
  function resolveVolumeSink() { if (!sinkResolver.running) sinkResolver.running = true }
  onLiveStreamsChanged: snapshotTimer.restart()
  onDefaultSinkChanged: resolveVolumeSink()
  Component.onCompleted: { refreshStreams(); resolveVolumeSink() }

  PwObjectTracker { objects: root.liveStreams }

  Timer {
    id: snapshotTimer
    objectName: "audioSnapshotTimer"
    interval: 75
    onTriggered: root.refreshStreams()
  }
  Timer { interval: 5000; running: true; repeat: true; onTriggered: root.resolveVolumeSink() }
  Process {
    id: sinkResolver
    command: ["omarchy-audio-output-sink"]
    stdout: StdioCollector { onStreamFinished: root.volumeSinkName = text.trim() }
  }

  component VerticalVolume: Item {
    id: volumeControl
    required property string controlId
    required property string label
    required property string glyph
    required property real level
    required property bool muted
    property bool available: true
    property bool revealed: true
    property real bottomInset: 0
    signal changed(real value)
    signal muteRequested()

    objectName: "verticalVolume:" + controlId
    implicitWidth: Style.space(70)
    width: revealed ? implicitWidth : 0
    height: parent ? parent.height : 0
    opacity: revealed ? (available ? 1 : 0.38) : 0
    clip: true
    visible: width > 0 || opacity > 0
    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Item {
      id: volumeIconTarget
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      width: Style.space(32)
      height: Style.space(32)

      Text {
        anchors.centerIn: parent
        text: volumeControl.muted ? "󰝟" : volumeControl.glyph
        color: volumeControl.muted ? Color.muted : Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.iconLarge
      }
      TapHandler {
        enabled: volumeControl.available
        onTapped: volumeControl.muteRequested()
      }
    }
    Column {
      anchors.bottom: parent.bottom
      anchors.bottomMargin: volumeControl.bottomInset
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      spacing: 0

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: volumeControl.label
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: Math.round(volumeControl.level * 100) + "%"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    Item {
      id: verticalTrackTarget
      objectName: "verticalVolumeTrack:" + volumeControl.controlId
      anchors.top: volumeIconTarget.bottom
      anchors.topMargin: Style.spacing.labelGap
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(36) + volumeControl.bottomInset
      anchors.horizontalCenter: parent.horizontalCenter
      width: Style.space(48)

      Rectangle {
        id: verticalTrack
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(8)
        radius: width / 2
        color: Color.muted
        opacity: 0.35

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: parent.height * root.clamp(volumeControl.level)
          radius: parent.radius
          color: volumeControl.muted ? Color.muted : Color.accent
          opacity: volumeControl.muted ? 0.55 : 1
        }
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(0, Math.min(parent.height - height,
          (1 - root.clamp(volumeControl.level)) * parent.height - height / 2))
        width: Style.space(24)
        height: Style.space(8)
        radius: height / 2
        color: volumeControl.muted ? Color.muted : Color.accent
      }

      MouseArea {
        anchors.fill: parent
        enabled: volumeControl.available
        function volumeAt(pointerY) {
          return root.clamp(1 - pointerY / Math.max(1, height))
        }
        onPressed: mouse => volumeControl.changed(volumeAt(mouse.y))
        onPositionChanged: mouse => { if (pressed) volumeControl.changed(volumeAt(mouse.y)) }
      }
    }
  }

  Row {
    id: verticalControlRow
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    spacing: Style.spacing.controlGap

    VerticalVolume {
      controlId: "output"
      label: "Output"
      glyph: "󰕾"
      level: root.volumeSink && root.volumeSink.audio ? root.volumeSink.audio.volume : 0
      muted: root.volumeSink && root.volumeSink.audio ? root.volumeSink.audio.muted : false
      available: !!(root.volumeSink && root.volumeSink.audio)
      bottomInset: root.compact ? Style.space(56) : 0
      onChanged: value => { if (root.volumeSink && root.volumeSink.audio) root.volumeSink.audio.volume = root.clamp(value) }
      onMuteRequested: if (root.volumeSink && root.volumeSink.audio) root.volumeSink.audio.muted = !root.volumeSink.audio.muted
    }

    VerticalVolume {
      controlId: "mic"
      label: "Mic"
      glyph: "󰍬"
      level: root.source && root.source.audio ? root.source.audio.volume : 0
      muted: root.source && root.source.audio ? root.source.audio.muted : false
      available: !!(root.source && root.source.audio)
      revealed: !root.compact
      onChanged: value => { if (root.source && root.source.audio) root.source.audio.volume = root.clamp(value) }
      onMuteRequested: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted
    }

    VerticalVolume {
      readonly property var streams: root.streamsFor("media")
      controlId: "media"
      label: "Media"
      glyph: "󰎆"
      level: root.categoryVolume("media")
      muted: root.categoryMuted("media")
      available: streams.length > 0
      revealed: !root.compact && streams.length > 0
      onChanged: value => root.setCategoryVolume("media", value)
      onMuteRequested: root.toggleCategoryMute("media")
    }

    VerticalVolume {
      readonly property var streams: root.streamsFor("games")
      controlId: "games"
      label: "Games"
      glyph: "󰊴"
      level: root.categoryVolume("games")
      muted: root.categoryMuted("games")
      available: streams.length > 0
      revealed: !root.compact && streams.length > 0
      onChanged: value => root.setCategoryVolume("games", value)
      onMuteRequested: root.toggleCategoryMute("games")
    }

    VerticalVolume {
      readonly property var streams: root.streamsFor("voice")
      controlId: "voice"
      label: "Voice"
      glyph: "󰍬"
      level: root.categoryVolume("voice")
      muted: root.categoryMuted("voice")
      available: streams.length > 0
      revealed: !root.compact && streams.length > 0
      onChanged: value => root.setCategoryVolume("voice", value)
      onMuteRequested: root.toggleCategoryMute("voice")
    }

    VerticalVolume {
      readonly property var streams: root.streamsFor("other")
      controlId: "other"
      label: "Other"
      glyph: "󰘔"
      level: root.categoryVolume("other")
      muted: root.categoryMuted("other")
      available: streams.length > 0
      revealed: !root.compact && streams.length > 0
      onChanged: value => root.setCategoryVolume("other", value)
      onMuteRequested: root.toggleCategoryMute("other")
    }
  }

  Button {
    objectName: "mixerExpandButton"
    x: root.compact ? (parent.width - width) / 2 : parent.width - width
    y: root.compact ? parent.height - height : (parent.height - height) / 2
    width: root.compact ? Style.space(48) : Style.space(32)
    height: root.compact ? Style.space(48) : Style.space(72)
    iconText: root.compact ? "󰅂" : "󰅁"
    iconSize: Style.font.icon
    horizontalPadding: 0
    verticalPadding: 0
    foreground: Color.muted
    color: "transparent"
    borderSpec: Border.none()
    z: 2
    onClicked: root.compact = !root.compact
  }
}
