.pragma library

var MIN_RATIO = 0.18
var MAX_RATIO = 0.82
var SUPPORTED_MODULE_IDS = ["clock", "workspaces", "command-center"]

function isFiniteNumber(value) {
  return typeof value === "number" && isFinite(value)
}

function validRatio(value) {
  return isFiniteNumber(value) && value >= MIN_RATIO && value <= MAX_RATIO
}

function supportedModuleId(moduleId) {
  return typeof moduleId === "string" && SUPPORTED_MODULE_IDS.indexOf(moduleId) !== -1
}

function validNode(node) {
  if (!node || typeof node !== "object" || Array.isArray(node)) return false
  if (node.type === "module") return supportedModuleId(node.moduleId)
  if (node.type !== "split") return false
  if (node.orientation !== "horizontal" && node.orientation !== "vertical") return false
  return validRatio(node.ratio) && validNode(node.first) && validNode(node.second)
}

function validLayout(layout) {
  if (layout && layout.version === 3) return validDashboard(layout)
  return !!layout
    && typeof layout === "object"
    && !Array.isArray(layout)
    && layout.version === 2
    && !!layout.root
    && layout.root.type === "split"
    && validNode(layout.root)
}

function validDashboard(layout) {
  var ids = []
  function visit(node, depth) {
    if (!node || depth > 8) return false
    if (node.type === "module") {
      if (["media", "clock", "weather", "command-center", "workspaces"].indexOf(node.moduleId) < 0
          || ids.indexOf(node.moduleId) >= 0) return false
      ids.push(node.moduleId)
      return true
    }
    return node.type === "split" && ["horizontal", "vertical"].indexOf(node.orientation) >= 0
      && validRatio(node.ratio) && visit(node.first, depth + 1) && visit(node.second, depth + 1)
  }
  return !!layout && layout.version === 3 && visit(layout.root, 0)
    && ["media", "clock", "weather", "command-center"].every(function(id) { return ids.indexOf(id) >= 0 })
}

function dashboardLayout(layout) {
  if (layout && layout.version === 3) return validDashboard(layout) ? JSON.parse(JSON.stringify(layout)) : null
  if (!validLayout(layout)) return null
  function expand(node) {
    if (node.type === "module") return node.moduleId === "clock"
      ? { type: "split", orientation: "vertical", ratio: 0.48,
          first: { type: "module", moduleId: "clock" }, second: { type: "module", moduleId: "weather" } }
      : JSON.parse(JSON.stringify(node))
    var ratio = node.ratio
    if (node.orientation === "horizontal") {
      if (node.first.moduleId === "clock" && node.second.moduleId === "command-center") ratio = Math.max(0.5, ratio)
      if (node.first.moduleId === "command-center" && node.second.moduleId === "clock") ratio = Math.min(0.5, ratio)
    }
    return { type: "split", orientation: node.orientation, ratio: ratio, first: expand(node.first), second: expand(node.second) }
  }
  var result = { version: 3, root: { type: "split", orientation: "horizontal", ratio: 0.27,
    first: { type: "module", moduleId: "media" }, second: expand(layout.root) } }
  return validDashboard(result) ? result : null
}

function modulePath(node, id, path) {
  if (!node) return null
  if (node.type === "module") return node.moduleId === id ? (path || "") : null
  var first = modulePath(node.first, id, path ? path + "/first" : "first")
  return first !== null ? first : modulePath(node.second, id, path ? path + "/second" : "second")
}

function moveModule(layout, sourceId, targetId, edge) {
  if (!validDashboard(layout) || sourceId === targetId || ["left", "right", "top", "bottom"].indexOf(edge) < 0
      || modulePath(layout.root, sourceId, "") === null || modulePath(layout.root, targetId, "") === null) return null
  function remove(node) {
    if (node.type === "module") return node.moduleId === sourceId ? null : node
    var first = remove(node.first), second = remove(node.second)
    return !first ? second : !second ? first : Object.assign({}, node, { first: first, second: second })
  }
  function insert(node) {
    if (node.type === "module") {
      if (node.moduleId !== targetId) return node
      var source = { type: "module", moduleId: sourceId }, before = edge === "left" || edge === "top"
      return { type: "split", orientation: edge === "left" || edge === "right" ? "horizontal" : "vertical",
        ratio: 0.5, first: before ? source : node, second: before ? node : source }
    }
    return Object.assign({}, node, { first: insert(node.first), second: insert(node.second) })
  }
  return { version: 3, root: insert(remove(JSON.parse(JSON.stringify(layout.root)))) }
}

function parseLayout(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    return validLayout(parsed) ? parsed : null
  } catch (error) {
    return null
  }
}

function ratioForUpdate(value) {
  if (!isFiniteNumber(value)) return null
  return Math.max(MIN_RATIO, Math.min(MAX_RATIO, value))
}
