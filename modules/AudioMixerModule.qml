import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui
import "AudioModel.js" as AudioModel

Item {
  id: root

  property string expandedCategory: ""
  property var displayStreams: []
  property string volumeSinkName: ""

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
  function streamsFor(category) {
    var result = []
    for (var i = 0; i < displayStreams.length; i++)
      if (AudioModel.categoryFor(displayStreams[i]) === category) result.push(displayStreams[i])
    return result
  }
  function categoryVolume(category) {
    var streams = streamsFor(category)
    var maximum = 0
    for (var i = 0; i < streams.length; i++) maximum = Math.max(maximum, streams[i].audio.volume)
    return maximum
  }
  function categoryMuted(category) {
    var streams = streamsFor(category)
    if (!streams.length) return false
    for (var i = 0; i < streams.length; i++) if (!streams[i].audio.muted) return false
    return true
  }
  function setCategoryVolume(category, target) {
    var streams = streamsFor(category)
    var current = categoryVolume(category)
    for (var i = 0; i < streams.length; i++)
      streams[i].audio.volume = current > 0 ? clamp(streams[i].audio.volume * target / current) : clamp(target)
  }
  function toggleCategoryMute(category) {
    var streams = streamsFor(category)
    var next = !categoryMuted(category)
    for (var i = 0; i < streams.length; i++) streams[i].audio.muted = next
  }
  function refreshStreams() { displayStreams = liveStreams.slice() }
  function resolveVolumeSink() { if (!sinkResolver.running) sinkResolver.running = true }

  onLiveStreamsChanged: snapshotTimer.restart()
  onDefaultSinkChanged: resolveVolumeSink()
  Component.onCompleted: { refreshStreams(); resolveVolumeSink() }

  PwObjectTracker { objects: root.liveStreams }

  Timer { id: snapshotTimer; interval: 75; onTriggered: root.refreshStreams() }
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
    signal changed(real value)
    signal muteRequested()

    implicitHeight: Style.space(46)
    opacity: available ? 1 : 0.38

    Text {
      id: volumeIcon
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: volumeRow.muted ? "󰝟" : volumeRow.glyph
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.displayLarge
    }
    Text {
      id: volumeLabel
      anchors.left: volumeIcon.right
      anchors.leftMargin: Style.spacing.controlGap
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(74)
      text: volumeRow.label
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
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
      anchors.right: muteButton.left
      anchors.rightMargin: Style.spacing.sm
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(38)
      horizontalAlignment: Text.AlignRight
      text: Math.round(volumeRow.level * 100) + "%"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    Button {
      id: muteButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: volumeRow.muted ? "󰝟" : "󰕾"
      foreground: volumeRow.muted ? Color.muted : Color.accent
      enabled: volumeRow.available
      onClicked: volumeRow.muteRequested()
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
    readonly property real childrenHeight: expanded ? Math.min(Style.space(180), childrenColumn.implicitHeight) : 0

    visible: streams.length > 0
    width: parent ? parent.width : 0
    height: visible ? headerHeight + childrenHeight : 0
    clip: true
    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Item {
      id: categoryHeader
      width: parent.width
      height: category.headerHeight

      TapHandler { onTapped: root.expandedCategory = category.expanded ? "" : category.categoryId }
      Text {
        id: categoryIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: category.glyph
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.displayLarge
      }
      Text {
        id: categoryLabel
        anchors.left: categoryIcon.right
        anchors.leftMargin: Style.spacing.controlGap
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(68)
        text: category.label + "  " + category.streams.length
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }
      PanelSlider {
        anchors.left: categoryLabel.right
        anchors.right: categoryMute.left
        anchors.leftMargin: Style.spacing.controlGap
        anchors.rightMargin: Style.spacing.controlGap
        anchors.verticalCenter: parent.verticalCenter
        value: root.categoryVolume(category.categoryId)
        fillColor: Color.accent
        knobColor: Color.accent
        onMoved: value => root.setCategoryVolume(category.categoryId, value)
        onRightClicked: root.toggleCategoryMute(category.categoryId)
      }
      Button {
        id: categoryMute
        anchors.right: chevron.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.categoryMuted(category.categoryId) ? "󰝟" : "󰕾"
        foreground: root.categoryMuted(category.categoryId) ? Color.muted : Color.accent
        onClicked: root.toggleCategoryMute(category.categoryId)
      }
      Text {
        id: chevron
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: category.expanded ? "󰅀" : "󰅂"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }

    Flickable {
      anchors.top: categoryHeader.bottom
      width: parent.width
      height: category.childrenHeight
      contentHeight: childrenColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      opacity: category.expanded ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }

      Column {
        id: childrenColumn
        width: parent.width
        Repeater {
          model: category.streams
          delegate: VolumeRow {
            required property var modelData
            width: childrenColumn.width
            label: AudioModel.streamLabel(modelData)
            glyph: "󰎆"
            level: modelData && modelData.audio ? modelData.audio.volume : 0
            muted: modelData && modelData.audio ? modelData.audio.muted : false
            available: !!(modelData && modelData.audio)
            onChanged: value => modelData.audio.volume = root.clamp(value)
            onMuteRequested: modelData.audio.muted = !modelData.audio.muted
          }
        }
      }
    }
  }

  Column {
    anchors.fill: parent
    spacing: 0

    VolumeRow {
      width: parent.width
      label: "Output"
      glyph: "󰕾"
      level: root.volumeSink && root.volumeSink.audio ? root.volumeSink.audio.volume : 0
      muted: root.volumeSink && root.volumeSink.audio ? root.volumeSink.audio.muted : false
      available: !!(root.volumeSink && root.volumeSink.audio)
      onChanged: value => root.volumeSink.audio.volume = root.clamp(value)
      onMuteRequested: root.volumeSink.audio.muted = !root.volumeSink.audio.muted
    }
    VolumeRow {
      width: parent.width
      label: "Mic"
      glyph: "󰍬"
      level: root.source && root.source.audio ? root.source.audio.volume : 0
      muted: root.source && root.source.audio ? root.source.audio.muted : false
      available: !!(root.source && root.source.audio)
      onChanged: value => root.source.audio.volume = root.clamp(value)
      onMuteRequested: root.source.audio.muted = !root.source.audio.muted
    }

    Rectangle { width: parent.width; height: 1; color: Color.muted; opacity: 0.25 }
    Category { categoryId: "media"; label: "Media"; glyph: "󰎆" }
    Category { categoryId: "games"; label: "Games"; glyph: "󰊴" }
    Category { categoryId: "voice"; label: "Voice"; glyph: "󰍬" }
    Category { categoryId: "other"; label: "Other"; glyph: "󰘔" }

    Text {
      width: parent.width
      visible: root.displayStreams.length === 0
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
