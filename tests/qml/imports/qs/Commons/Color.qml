pragma Singleton
import QtQuick

QtObject {
  property color foreground: "#f4f4f5"
  property color muted: "#a1a1aa"
  property color accent: "#f59e0b"
  property color background: "#18181b"
  property color urgent: "#ef4444"
  readonly property QtObject popups: QtObject {
    property color background: "#18181b"
    property color border: "#52525b"
  }
}
