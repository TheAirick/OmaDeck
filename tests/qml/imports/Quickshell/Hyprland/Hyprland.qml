pragma Singleton
import QtQuick

QtObject {
  readonly property QtObject workspaces: QtObject { property var values: [] }
  readonly property QtObject toplevels: QtObject { property var values: [] }
  readonly property QtObject monitors: QtObject { property var values: [] }
  property var focusedWorkspace: null
  property var activeToplevel: null
  property var requests: []
  property int refreshCount: 0
  signal rawEvent(var event)
  function refreshToplevels() { refreshCount++ }
  function refreshWorkspaces() {}
  function refreshMonitors() {}
  function dispatch(request) { requests = requests.concat([request]) }
}
