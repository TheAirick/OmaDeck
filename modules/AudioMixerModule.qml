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
  property bool compact: false
  readonly property int streamRowCapacity: 16
  readonly property int streamRowHeight: Style.space(46)
  readonly property real contentHeight: masterColumn.implicitHeight + streamViewport.contentHeight
  readonly property bool streamOverflow: streamViewport.contentHeight > streamViewport.height + 0.5

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
  function scrollStreams(direction) {
    var maximum = Math.max(0, streamViewport.contentHeight - streamViewport.height)
    streamViewport.contentY = Math.max(0, Math.min(maximum,
      streamViewport.contentY + direction * root.streamRowHeight))
  }

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

  component VolumeRow: Item {
    id: volumeRow
    required property string label
    required property string glyph
    required property real level
    required property bool muted
    property bool available: true
    property bool revealed: true
    property bool labelActionEnabled: false
    signal changed(real value)
    signal muteRequested()
    signal labelRequested()

    implicitHeight: Style.space(46)
    height: revealed ? implicitHeight : 0
    opacity: revealed ? (available ? 1 : 0.38) : 0
    clip: true
    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Item {
      id: volumeIconTarget
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(30)
      height: parent.height

      Text {
        anchors.centerIn: parent
        text: volumeRow.muted ? "󰝟" : volumeRow.glyph
        color: volumeRow.muted ? Color.muted : Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.displayLarge
      }
      TapHandler {
        enabled: volumeRow.available
        onTapped: volumeRow.muteRequested()
      }
    }
    Text {
      id: volumeLabel
      anchors.left: volumeIconTarget.right
      anchors.leftMargin: Style.spacing.controlGap
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(74)
      height: parent.height
      verticalAlignment: Text.AlignVCenter
      text: volumeRow.label
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
      TapHandler { enabled: volumeRow.labelActionEnabled; onTapped: volumeRow.labelRequested() }
    }
    PanelSlider {
      anchors.left: volumeLabel.right
      anchors.right: percent.left
      anchors.leftMargin: Style.spacing.controlGap
      anchors.rightMargin: Style.spacing.controlGap
      anchors.verticalCenter: parent.verticalCenter
      value: volumeRow.level
      enabled: volumeRow.available
      fillColor: Color.accent
      knobColor: Color.accent
      onMoved: value => volumeRow.changed(value)
      onRightClicked: volumeRow.muteRequested()
    }
    Text {
      id: percent
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(38)
      horizontalAlignment: Text.AlignRight
      text: Math.round(volumeRow.level * 100) + "%"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  component Category: Item {
    id: category
    required property string categoryId
    required property string label
    required property string glyph
    readonly property var streams: root.streamsFor(categoryId)
    readonly property bool expanded: root.expandedCategory === categoryId
    readonly property bool anotherExpanded: root.expandedCategory !== "" && !expanded
    readonly property real headerHeight: anotherExpanded ? Style.space(45) : Style.space(58)
    readonly property real childrenHeight: expanded ? childrenColumn.implicitHeight : 0

    readonly property bool hasStreams: streams.length > 0
    visible: height > 0 || opacity > 0
    width: parent ? parent.width : 0
    height: hasStreams && !root.compact ? headerHeight + childrenHeight : 0
    opacity: hasStreams && !root.compact ? 1 : 0
    clip: true
    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150 } }


    Item {
      id: categoryHeader
      width: parent.width
      height: category.headerHeight

      Item {
        id: categoryIconTarget
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(30)
        height: parent.height

        Text {
          anchors.centerIn: parent
          text: root.categoryMuted(category.categoryId) ? "󰝟" : category.glyph
          color: root.categoryMuted(category.categoryId) ? Color.muted : Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.displayLarge
        }
        TapHandler { onTapped: root.toggleCategoryMute(category.categoryId) }
      }
      Item {
        id: categoryLabel
        anchors.left: categoryIconTarget.right
        anchors.leftMargin: Style.spacing.controlGap
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(74)
        height: Style.space(38)

        Text {
          anchors.left: parent.left
          anchors.top: parent.top
          text: category.label
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Text {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          text: category.streams.length + (category.streams.length === 1 ? " source" : " sources")
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        TapHandler { onTapped: root.expandedCategory = category.expanded ? "" : category.categoryId }
      }
      PanelSlider {
        anchors.left: categoryLabel.right
        anchors.right: categoryPercent.left
        anchors.leftMargin: Style.spacing.controlGap
        anchors.rightMargin: Style.spacing.controlGap
        anchors.verticalCenter: parent.verticalCenter
        value: root.categoryVolume(category.categoryId)
        fillColor: Color.accent
        knobColor: Color.accent
        onMoved: value => root.setCategoryVolume(category.categoryId, value)
        onRightClicked: root.toggleCategoryMute(category.categoryId)
      }
      Text {
        id: categoryPercent
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(38)
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.categoryVolume(category.categoryId) * 100) + "%"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    Column {
      id: childrenColumn
      y: category.headerHeight
      width: parent.width
      opacity: category.expanded ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }

      Repeater {
        // Keep the QQuickRepeater model stable while PipeWire destroys and
        // recreates PwNode objects. Rebinding a Repeater directly to the
        // shrinking QObject array can crash inside QQmlObjectModel while
        // PwNode::unbindHooks is notifying QML.
        model: root.streamRowCapacity
        delegate: VolumeRow {
          required property int index
          readonly property var streamNode: index < category.streams.length
            ? category.streams[index] : null
          width: childrenColumn.width
          label: AudioModel.streamLabel(streamNode)
          glyph: "󰎆"
          level: streamNode && streamNode.audio ? streamNode.audio.volume : 0
          muted: streamNode && streamNode.audio ? streamNode.audio.muted : false
          available: !!(streamNode && streamNode.audio)
          revealed: available
          onChanged: value => { if (streamNode && streamNode.audio) streamNode.audio.volume = root.clamp(value) }
          onMuteRequested: if (streamNode && streamNode.audio) streamNode.audio.muted = !streamNode.audio.muted
        }
      }
    }
  }

  Column {
    id: masterColumn
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 0

    Row {
      width: parent.width
      height: Style.space(46)
      spacing: root.compact ? 0 : Style.spacing.panelGap

      VolumeRow {
        width: root.compact ? parent.width : (parent.width - parent.spacing) / 2
        label: "Output"
        glyph: "󰕾"
        level: root.volumeSink && root.volumeSink.audio ? root.volumeSink.audio.volume : 0
        muted: root.volumeSink && root.volumeSink.audio ? root.volumeSink.audio.muted : false
        available: !!(root.volumeSink && root.volumeSink.audio)
        labelActionEnabled: true
        onChanged: value => root.volumeSink.audio.volume = root.clamp(value)
        onMuteRequested: root.volumeSink.audio.muted = !root.volumeSink.audio.muted
        onLabelRequested: root.compact = !root.compact
      }
      VolumeRow {
        width: root.compact ? 0 : (parent.width - parent.spacing) / 2
        label: "Mic"
        glyph: "󰍬"
        level: root.source && root.source.audio ? root.source.audio.volume : 0
        muted: root.source && root.source.audio ? root.source.audio.muted : false
        available: !!(root.source && root.source.audio)
        revealed: !root.compact
        onChanged: value => root.source.audio.volume = root.clamp(value)
        onMuteRequested: root.source.audio.muted = !root.source.audio.muted
      }
    }

    Rectangle {
      width: parent.width
      height: root.compact ? 0 : 1
      color: Color.muted
      opacity: root.compact ? 0 : 0.25
      Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 150 } }
    }
  }

  Flickable {
    id: streamViewport
    objectName: "mediaSourceViewport"
    anchors.top: masterColumn.bottom
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    contentHeight: streamColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: !root.compact && contentHeight > height
    opacity: root.compact ? 0 : 1
    onContentHeightChanged: contentY = Math.min(contentY, Math.max(0, contentHeight - height))
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Column {
      id: streamColumn
      width: streamViewport.width - (root.streamOverflow ? Style.space(28) : 0)
      Category { categoryId: "media"; label: "Media"; glyph: "󰎆" }
      Category { categoryId: "games"; label: "Games"; glyph: "󰊴" }
      Category { categoryId: "voice"; label: "Voice"; glyph: "󰍬" }
      Category { categoryId: "other"; label: "Other"; glyph: "󰘔" }

      Text {
        width: parent.width
        visible: !root.compact && root.displayStreams.length === 0
        topPadding: Style.spacing.lg
        text: "Audio streams appear here when they start playing."
        color: Color.muted
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  Item {
    id: streamScrollUp
    objectName: "mixerScrollUp"
    visible: !root.compact && root.streamOverflow && !streamViewport.atYBeginning
    anchors.top: streamViewport.top
    anchors.right: parent.right
    width: Style.space(28)
    height: Style.space(28)
    z: 2
    Text {
      anchors.centerIn: parent
      text: "󰅀"
      rotation: 180
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.iconLarge
    }
    TapHandler { onTapped: root.scrollStreams(-1) }
  }

  Item {
    id: streamScrollDown
    objectName: "mixerScrollDown"
    visible: !root.compact && root.streamOverflow && !streamViewport.atYEnd
    anchors.right: parent.right
    anchors.bottom: streamViewport.bottom
    width: Style.space(28)
    height: Style.space(28)
    z: 2
    Text {
      anchors.centerIn: parent
      text: "󰅀"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.iconLarge
    }
    TapHandler { onTapped: root.scrollStreams(+1) }
  }
}
