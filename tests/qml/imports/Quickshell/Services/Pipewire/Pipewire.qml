pragma Singleton
import QtQuick

QtObject {
  readonly property QtObject nodes: QtObject { property var values: [] }
  property var defaultAudioSink: null
  property var defaultAudioSource: null
}
