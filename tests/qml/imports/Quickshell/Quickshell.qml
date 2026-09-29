pragma Singleton
import QtQuick

QtObject {
  function iconPath(name, fallback) { return "" }
  function env(name) { return "" }
  property var detached: []
  function execDetached(command) { detached = detached.concat([command]) }
}
