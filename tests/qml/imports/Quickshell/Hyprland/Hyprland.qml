pragma Singleton
import QtQuick

QtObject {
  readonly property QtObject workspaces: QtObject { readonly property var values: [] }
  readonly property var focusedWorkspace: null
}
