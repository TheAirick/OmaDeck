import QtQuick
import Quickshell
import Quickshell.Io
import "LayoutPolicy.js" as LayoutPolicy

Item {
  id: root

  readonly property string configDir: Quickshell.env("HOME") + "/.config/omadeck"
  readonly property string layoutPath: configDir + "/dashboard-layout.json"
  readonly property string legacyLayoutPath: configDir + "/layout.json"
  readonly property bool dashboardLayout: true
  property var editSnapshot: null
  property bool legacyChecked: false

  property var layout: defaultLayout()
  property int revision: 0
  property bool loaded: false
  property bool directoryReady: false
  // Pending includes debounce, in-flight writes and failed unsaved edits.
  property bool savePending: false
  property string saveError: ""
  property bool saveInFlight: false
  property int savingRevision: -1
  property string savedText: ""
  property string savingText: ""
  property bool editMode: false
  property string selectedPath: ""

  signal layoutChangedByUser()

  function defaultLayout() {
    return LayoutPolicy.dashboardLayout({
      version: 2,
      root: {
        type: "split",
        orientation: "horizontal",
        ratio: 0.36,
        first: { type: "module", moduleId: "clock" },
        second: { type: "module", moduleId: "command-center" }
      }
    })
  }

  function clone(value) {
    return JSON.parse(JSON.stringify(value))
  }

  function load(raw) {
    if (editMode || savePending || saveInFlight) return
    savedText = raw
    try {
      var parsed = LayoutPolicy.parseLayout(raw)
      if (!parsed) throw new Error("unsupported layout")
      layout = LayoutPolicy.dashboardLayout(parsed)
      if (!layout) throw new Error("invalid dashboard modules")
      revision++
      loaded = true
    } catch (error) {
      console.warn("OmaDeck: invalid layout, using defaults:", error)
      layout = defaultLayout()
      revision++
      loaded = true
      scheduleSave()
    }
  }

  function pathParts(path) {
    return String(path || "").split("/").filter(function(part) { return part === "first" || part === "second" })
  }

  function nodeAt(path, tree) {
    var node = (tree || layout).root
    var parts = pathParts(path)
    for (var i = 0; i < parts.length; i++) {
      if (!node || node.type !== "split") return null
      node = node[parts[i]]
    }
    return node
  }

  function parentAt(path, tree) {
    var parts = pathParts(path)
    if (parts.length === 0) return null
    var key = parts.pop()
    var parent = nodeAt(parts.join("/"), tree)
    return parent ? { node: parent, key: key } : null
  }

  function commit(next) {
    layout = next
    revision++
    layoutChangedByUser()
    if (!editMode) scheduleSave()
  }

  function setRatio(path, value) {
    var nextRatio = LayoutPolicy.ratioForUpdate(value)
    if (nextRatio === null) return
    var next = clone(layout)
    var node = nodeAt(path, next)
    if (!node || node.type !== "split") return
    node.ratio = nextRatio
    commit(next)
  }

  function swap(firstPath, secondPath) {
    if (!firstPath || !secondPath || firstPath === secondPath) return
    var next = clone(layout)
    var firstParent = parentAt(firstPath, next)
    var secondParent = parentAt(secondPath, next)
    if (!firstParent || !secondParent
      || firstParent.node[firstParent.key].type !== "module"
      || secondParent.node[secondParent.key].type !== "module") return
    var temporary = firstParent.node[firstParent.key]
    firstParent.node[firstParent.key] = secondParent.node[secondParent.key]
    secondParent.node[secondParent.key] = temporary
    selectedPath = secondPath
    commit(next)
  }

  function selectOrSwap(path) {
    if (!editMode) return
    if (!selectedPath) {
      selectedPath = path
      return
    }
    if (selectedPath === path) {
      selectedPath = ""
      return
    }
    var from = selectedPath
    selectedPath = ""
    swap(from, path)
  }

  function moveModule(sourceId, targetId, edge) {
    if (!editMode) return
    var next = LayoutPolicy.moveModule(layout, sourceId, targetId, edge)
    if (!next) return
    selectedPath = LayoutPolicy.modulePath(next.root, sourceId, "")
    commit(next)
  }

  function beginEdit(path) {
    if (!editMode) editSnapshot = clone(layout)
    editMode = true
    selectedPath = path
  }

  function finishEdit() {
    editMode = false
    selectedPath = ""
    editSnapshot = null
    scheduleSave()
  }

  function cancelEdit() {
    if (!editMode || !editSnapshot) return
    layout = clone(editSnapshot)
    revision++
    editSnapshot = null
    editMode = false
    selectedPath = ""
    scheduleSave()
  }

  function scheduleSave() {
    savePending = true
    if (directoryReady) saveDelay.restart()
  }

  function persist() {
    if (editMode) return
    if (!directoryReady) {
      if (!mkdirProcess.running) {
        mkdirProcess.launchPending = true
        mkdirProcess.running = true
      }
      return
    }
    if (!savePending || saveInFlight) return
    saveDelay.stop()
    savingText = JSON.stringify(layout, null, 2) + "\n"
    if (saveError === "" && savingText === savedText) {
      savePending = false
      return
    }
    savingRevision = revision
    saveInFlight = true
    // Failed writes remain cached by FileView 0.3.1; an identical retry would
    // otherwise silently do nothing. Unload before retrying the same payload.
    if (saveError !== "") {
      layoutFile.path = ""
      layoutFile.path = layoutPath
    }
    try {
      layoutFile.setText(savingText)
    } catch (error) {
      saveInFlight = false
      saveError = String(error)
    }
  }

  Process {
    id: mkdirProcess
    command: ["/usr/bin/mkdir", "-p", root.configDir]
    property bool launchPending: true
    onStarted: launchPending = false
    onRunningChanged: {
      if (!running && launchPending) finishDirectory(-1)
    }
    onExited: function(exitCode) { finishDirectory(exitCode) }
    function finishDirectory(exitCode) {
      launchPending = false
      root.directoryReady = exitCode === 0
      if (!root.directoryReady) {
        root.loaded = true
        root.saveError = "Settings directory unavailable"
        return
      }
      if (root.savePending) saveDelay.restart()
      else {
        root.saveError = ""
        layoutFile.reload()
      }
    }
  }

  FileView {
    id: layoutFile
    path: root.layoutPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onSaved: {
      root.savedText = root.savingText
      root.saveInFlight = false
      root.savePending = root.revision !== root.savingRevision
      root.saveError = ""
      if (root.savePending) saveDelay.restart()
    }
    onSaveFailed: function(error) {
      root.saveInFlight = false
      root.saveError = String(error)
    }
    onLoaded: root.load(text())
    onLoadFailed: {
      root.savedText = ""
      if (!root.directoryReady) return
      if (!root.loaded && !root.legacyChecked) {
        root.legacyChecked = true
        legacyLayoutFile.path = root.legacyLayoutPath
        return
      }
      root.loaded = true
      root.scheduleSave()
    }
    onFileChanged: reload()
  }

  FileView {
    id: legacyLayoutFile
    path: ""
    printErrors: false
    onLoaded: {
      if (root.loaded) return
      root.load(text())
      root.savedText = ""
      root.scheduleSave()
    }
    onLoadFailed: {
      if (!root.legacyChecked || root.loaded) return
      root.loaded = true
      root.scheduleSave()
    }
  }

  Timer {
    id: saveDelay
    interval: 180
    repeat: false
    onTriggered: root.persist()
  }

  Timer {
    interval: 5000
    running: root.saveError !== "" && !root.saveInFlight
    repeat: true
    onTriggered: root.persist()
  }

  Component.onCompleted: mkdirProcess.running = true
}
