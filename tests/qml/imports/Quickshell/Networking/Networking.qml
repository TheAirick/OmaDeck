pragma Singleton
import QtQuick

QtObject {
  property bool wifiEnabled: false
  readonly property int backend: 0
  readonly property QtObject devices: QtObject { readonly property var values: [] }
}
