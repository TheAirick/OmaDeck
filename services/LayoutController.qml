import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string configDir: Quickshell.env("HOME") + "/.config/omadeck"
  readonly property string layoutPath: configDir + "/layout.json"

  property var layout: defaultLayout()
  property int revision: 0
  property bool loaded: false
  property bool directoryReady: false
  property bool editMode: false
  property string selectedPath: ""

  signal layoutChangedByUser()

  function defaultLayout() {
    return {
      version: 2,
      root: {
        type: "split",
        orientation: "horizontal",
        ratio: 0.36,
        first: { type: "module", moduleId: "clock" },
        second: { type: "module", moduleId: "command-center" }
      }
    }
  }

  function clone(value) {
    return JSON.parse(JSON.stringify(value))
  }

  function validNode(node) {
    if (!node || typeof node !== "object") return false
    if (node.type === "module") return typeof node.moduleId === "string" && node.moduleId.length > 0
    if (node.type !== "split") return false
    if (node.orientation !== "horizontal" && node.orientation !== "vertical") return false
    return validNode(node.first) && validNode(node.second)
  }

  function load(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (!parsed || parsed.version !== 2 || !validNode(parsed.root)) throw new Error("unsupported layout")
      layout = parsed
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
    scheduleSave()
  }

  function setRatio(path, value) {
    var next = clone(layout)
    var node = nodeAt(path, next)
    if (!node || node.type !== "split") return
    node.ratio = Math.max(0.18, Math.min(0.82, Number(value)))
    commit(next)
  }

  function swap(firstPath, secondPath) {
    if (!firstPath || !secondPath || firstPath === secondPath) return
    var next = clone(layout)
    var firstParent = parentAt(firstPath, next)
    var secondParent = parentAt(secondPath, next)
    if (!firstParent || !secondParent) return
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

  function beginEdit(path) {
    editMode = true
    selectedPath = path
  }

  function finishEdit() {
    editMode = false
    selectedPath = ""
    scheduleSave()
  }

  function scheduleSave() {
    if (!directoryReady) return
    saveDelay.restart()
  }

  function persist() {
    if (!directoryReady) return
    layoutFile.setText(JSON.stringify(layout, null, 2) + "\n")
  }

  Process {
    id: mkdirProcess
    command: ["mkdir", "-p", root.configDir]
    onExited: {
      root.directoryReady = true
      layoutFile.reload()
    }
  }

  FileView {
    id: layoutFile
    path: root.layoutPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: {
      if (!root.directoryReady) return
      root.loaded = true
      root.persist()
    }
    onFileChanged: reload()
  }

  Timer {
    id: saveDelay
    interval: 180
    repeat: false
    onTriggered: root.persist()
  }

  Component.onCompleted: mkdirProcess.running = true
}
