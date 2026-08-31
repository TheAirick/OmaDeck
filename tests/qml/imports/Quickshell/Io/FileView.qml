import QtQuick

QtObject {
  property string path: ""
  property bool atomicWrites: false
  property bool blockWrites: false
  property bool printErrors: true
  signal saved()
  signal saveFailed(var error)
  function setText(text) { saved() }
}
