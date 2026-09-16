.pragma library

function label(value) {
  return typeof value === "string" && value.trim().length > 0 && value.trim().length <= 48
    && !/[\u0000-\u001f\u007f]/.test(value) ? value.trim() : null
}
function defaults() { return { version: 1, enabled: false, selectedId: "", monitors: [] } }
function normalize(value) {
  if (!value || value.version !== 1 || typeof value.enabled !== "boolean"
      || !Array.isArray(value.monitors) || value.monitors.length > 8) return null
  var monitors = [], ids = []
  for (var entry of value.monitors) {
    if (!entry || !/^[0-9a-f]{64}$/.test(entry.id) || ids.indexOf(entry.id) !== -1 || !label(entry.label)
        || !Array.isArray(entry.sources) || !entry.sources.length || entry.sources.length > 4) return null
    var codes = [], sources = []
    for (var source of entry.sources) {
      if (!source || !/^[0-9a-f]{2}$/.test(source.code) || source.code === "00"
          || codes.indexOf(source.code) !== -1 || !label(source.label)) return null
      codes.push(source.code)
      sources.push({ code: source.code, label: label(source.label) })
    }
    ids.push(entry.id)
    monitors.push({ id: entry.id, label: label(entry.label), sources: sources })
  }
  return { version: 1, enabled: value.enabled,
    selectedId: ids.indexOf(value.selectedId) !== -1 ? value.selectedId : (ids[0] || ""), monitors: monitors }
}
function parse(raw) {
  try { return normalize(JSON.parse(String(raw || ""))) } catch (error) { return null }
}
