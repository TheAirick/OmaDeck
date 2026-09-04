import QtQuick
QtObject {
  property string path: ""
  property bool atomicWrites: false
  property bool blockWrites: false
  property bool printErrors: true
  property bool watchChanges: false
  property bool failWrites: false
  property bool deferWrites: false
  property int writes: 0
  property string content: ""
  property string pendingText: ""
  signal saved()
  signal saveFailed(var error)
  signal loaded()
  signal loadFailed(var error)
  signal fileChanged()
  function text() { return content }
  function reload() {}
  // Match 0.3.1: even failed writes update the comparison cache; identical
  // setText is a no-op with no completion signal until the view is reloaded.
  onPathChanged: if (path === "") content = ""
  function setText(value) {
    if (value === content) return
    writes++
    pendingText = value
    if (!deferWrites) finishWrite()
  }
  function finishWrite() {
    content = pendingText
    if (failWrites) saveFailed("injected I/O failure")
    else saved()
  }
}
