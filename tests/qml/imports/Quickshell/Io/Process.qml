import QtQuick

QtObject {
  property var command: []
  property bool running: false
  property var stdout: null
  signal started()
  signal exited(int exitCode)
  function signal(number) {}
}
