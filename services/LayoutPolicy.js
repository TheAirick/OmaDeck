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
  return !!layout
    && typeof layout === "object"
    && !Array.isArray(layout)
    && layout.version === 2
    && !!layout.root
    && layout.root.type === "split"
    && validNode(layout.root)
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
