pragma Singleton
import QtQuick
QtObject {
  readonly property QtObject applications: QtObject { property var values: [] }
  function heuristicLookup(appId) {
    var values = applications.values
    for (var i = 0; i < values.length; i++)
      if (values[i].id === appId || values[i].startupClass === appId) return values[i]
    return null
  }
}
