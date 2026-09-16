// Copy scalar descriptors only. Delegates must never own live PipeWire nodes.
function isDevice(node, kind) {
  if (!node || node.isStream || !node.audio || !node.name) return false
  if (kind === "output") return node.isSink === true
  return kind === "input" && !node.isSink && node.name !== "quickshell"
    && !String(node.name).endsWith(".monitor")
}

function label(node) {
  return node ? String(node.description || node.nickname || node.name || "Unknown device") : "No device connected"
}

function snapshot(nodes, kind) {
  var result = []
  for (var i = 0; i < nodes.length; i++) {
    var node = nodes[i]
    if (isDevice(node, kind))
      result.push({ id: String(node.id), name: String(node.name), label: label(node) })
  }
  result.sort(function(a, b) { return a.label.localeCompare(b.label) || a.name.localeCompare(b.name) })
  return result
}

function find(nodes, kind, id, name) {
  for (var i = 0; i < nodes.length; i++) {
    var node = nodes[i]
    if (isDevice(node, kind) && String(node.id) === String(id) && String(node.name) === name)
      return node
  }
  return null
}
