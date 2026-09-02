.pragma library

var CATALOG = [
  { id: "terminal", kind: "application", desktopId: "com.mitchellh.ghostty", name: "Terminal", iconText: "󰆍", classes: ["com.mitchellh.ghostty"] },
  { id: "browser", kind: "application", desktopId: "chromium", name: "Browser", iconText: "󰖟", classes: ["chromium", "google-chrome", "zen"] },
  { id: "files", kind: "application", desktopId: "org.gnome.Nautilus", name: "Files", iconText: "󰉋", classes: ["org.gnome.nautilus", "nautilus"] },
  { id: "discord", kind: "application", desktopId: "discord", name: "Discord", iconText: "󰙯", classes: ["discord", "vesktop"] },
  { id: "obsidian", kind: "application", desktopId: "obsidian", name: "Obsidian", iconText: "󰠮", classes: ["md.obsidian.obsidian", "obsidian"] },
  { id: "omawrite", kind: "application", desktopId: "omawrite", name: "Omawrite", iconText: "󰈙", classes: ["omawrite"] },
  { id: "notifications", kind: "shortcut", action: "notifications", name: "Notifications", iconText: "󰂚" },
  { id: "scratchpad", kind: "shortcut", action: "overview", name: "Overview", iconText: "󰖲" },
  { id: "clipboard", kind: "shortcut", action: "clipboard", name: "Clipboard", iconText: "󰅇" },
  { id: "performance", kind: "shortcut", action: "performance", name: "Performance", iconText: "󰍛" },
  { id: "lock", kind: "shortcut", action: "lock", name: "Lock", iconText: "󰌾" }
]

var DEFAULT_IDS = ["terminal", "browser", "files", "discord", "obsidian", "omawrite"]

function clone(value) {
  return JSON.parse(JSON.stringify(value))
}

function catalog() {
  return clone(CATALOG)
}

function entryForId(id) {
  var wanted = String(id || "")
  for (var i = 0; i < CATALOG.length; i++) {
    if (CATALOG[i].id === wanted) return clone(CATALOG[i])
  }
  if (wanted.indexOf("desktop:") === 0) {
    var desktopId = wanted.slice(8)
    if (desktopId.length > 0 && desktopId.length <= 256
        && desktopId.indexOf("/") === -1 && !/[\x00-\x1f\x7f]/.test(desktopId)) {
      return { id: wanted, kind: "desktop", desktopId: desktopId,
        name: desktopId, iconText: "󰀻", classes: [desktopId] }
    }
  }
  return null
}

function normalizeIds(ids) {
  if (!Array.isArray(ids)) return null
  var result = []
  for (var i = 0; i < ids.length; i++) {
    var id = String(ids[i] || "")
    if (!entryForId(id) || result.indexOf(id) !== -1) continue
    result.push(id)
  }
  return result
}

function parseSettings(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || parsed.version !== 1) return null
    var ids = normalizeIds(parsed.entries)
    return ids === null ? null : ids
  } catch (error) {
    return null
  }
}

function snapshot(ids) {
  var normalized = normalizeIds(ids)
  return { version: 1, entries: normalized === null ? DEFAULT_IDS.slice() : normalized }
}

function entries(ids) {
  var normalized = normalizeIds(ids)
  if (normalized === null) normalized = DEFAULT_IDS.slice()
  var result = []
  for (var i = 0; i < normalized.length; i++) {
    var entry = entryForId(normalized[i])
    if (entry) result.push(entry)
  }
  return result
}

function available(ids) {
  var normalized = normalizeIds(ids) || []
  return catalog().filter(function(entry) { return normalized.indexOf(entry.id) === -1 })
}

function add(ids, id) {
  var normalized = normalizeIds(ids) || []
  var wanted = String(id || "")
  if (!entryForId(wanted) || normalized.indexOf(wanted) !== -1) return normalized
  return normalized.concat([wanted])
}

function remove(ids, id) {
  var wanted = String(id || "")
  return (normalizeIds(ids) || []).filter(function(value) { return value !== wanted })
}

function move(ids, id, delta) {
  var normalized = normalizeIds(ids) || []
  var from = normalized.indexOf(String(id || ""))
  var to = from + Number(delta || 0)
  if (from < 0 || to < 0 || to >= normalized.length) return normalized
  var result = normalized.slice()
  var temporary = result[from]
  result[from] = result[to]
  result[to] = temporary
  return result
}
