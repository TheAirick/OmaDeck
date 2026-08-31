pragma Singleton
import QtQuick

QtObject {
  readonly property color foreground: "#f4f4f5"
  readonly property color muted: "#a1a1aa"
  readonly property color accent: "#f59e0b"
  readonly property color background: "#18181b"
  readonly property color urgent: "#ef4444"
  readonly property QtObject popups: QtObject {
    readonly property color background: "#18181b"
    readonly property color border: "#52525b"
  }
}
