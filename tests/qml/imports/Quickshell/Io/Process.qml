import QtQuick

QtObject {
  property var command: []
  property bool running: false
  signal exited(int exitCode)
}
