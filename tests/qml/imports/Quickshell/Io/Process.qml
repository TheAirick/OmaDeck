import QtQuick

QtObject {
  property var command: []
  property bool running: false
  property var stdout: null
  signal exited(int exitCode)
}
