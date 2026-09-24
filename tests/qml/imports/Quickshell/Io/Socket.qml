import QtQuick

QtObject {
  property bool connected: false
  property string path: ""
  property var parser: null
  property var sent: []
  signal connectionStateChanged()
  onConnectedChanged: connectionStateChanged()
  function write(data) { sent = sent.concat([String(data)]) }
  function flush() {}
}
