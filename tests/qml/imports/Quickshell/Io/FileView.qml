import QtQuick

QtObject {
  property string path: ""
  property bool atomicWrites: false
  property bool blockWrites: false
  property bool printErrors: true
  property bool watchChanges: false
  property string storedText: ""
  signal loaded()
  signal loadFailed(var error)
  signal fileChanged()
  signal saved()
  signal saveFailed(var error)
  function setText(value) { storedText = value; saved() }
  function text() { return storedText }
  function reload() {}
}
