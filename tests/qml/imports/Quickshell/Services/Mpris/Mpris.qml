pragma Singleton
import QtQuick

QtObject {
  property QtObject players: QtObject {
    property var values: []
  }
}
