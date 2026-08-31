pragma Singleton
import QtQuick

QtObject {
  readonly property real cornerRadius: 12
  readonly property real normalBorderWidth: 1
  readonly property QtObject spacing: QtObject {
    readonly property real controlGap: 8
    readonly property real panelGap: 12
    readonly property real labelGap: 4
    readonly property real rowGap: 8
    readonly property real panelPadding: 12
    readonly property real controlPaddingX: 12
    readonly property real controlPaddingY: 8
    readonly property real rowPaddingX: 8
  }
  readonly property QtObject font: QtObject {
    readonly property string family: "DejaVu Sans"
    readonly property real caption: 12
    readonly property real body: 14
    readonly property real subtitle: 18
    readonly property real title: 20
    readonly property real display: 28
    readonly property real displayLarge: 36
  }

  function space(value) {
    return value
  }
}
