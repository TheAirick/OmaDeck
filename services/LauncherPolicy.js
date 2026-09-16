.pragma library

var CATALOG = [
  { id: "terminal", kind: "application", desktopId: "com.mitchellh.ghostty", name: "Terminal", iconText: "󰆍", classes: ["com.mitchellh.ghostty"] },
  { id: "browser", kind: "application", desktopId: "chromium", name: "Browser", iconText: "󰖟", classes: ["chromium", "google-chrome", "zen"] },
  { id: "files", kind: "application", desktopId: "org.gnome.Nautilus", name: "Files", iconText: "󰉋", classes: ["org.gnome.nautilus", "nautilus"] },
  { id: "discord", kind: "application", desktopId: "discord", name: "Discord", iconText: "󰙯", classes: ["discord", "vesktop"] },
  { id: "obsidian", kind: "application", desktopId: "obsidian", name: "Obsidian", iconText: "󰠮", classes: ["md.obsidian.obsidian", "obsidian"] },
  { id: "omawrite", kind: "application", desktopId: "omawrite", name: "Omawrite", iconText: "󰈙", classes: ["omawrite"] },
  { id: "notifications", kind: "shortcut", action: "notifications", name: "Notifications", iconText: "󰂚" },
  { id: "scratchpad", kind: "shortcut", action: "overview", name: "Workspaces", iconText: "󰖲" },
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

var ICONS = [
  { id: "terminal", glyph: "󰆍", label: "Terminal" }, { id: "code", glyph: "󰅩", label: "Script" },
  { id: "play", glyph: "󰐊", label: "Play" }, { id: "folder", glyph: "󰉋", label: "Folder" },
  { id: "web", glyph: "󰖟", label: "Web" }, { id: "gear", glyph: "󰒓", label: "Settings" },
  { id: "music", glyph: "󰎆", label: "Music" }, { id: "monitor", glyph: "󰍹", label: "Display" },
  { id: "download", glyph: "󰇚", label: "Download" }, { id: "backup", glyph: "󰁯", label: "Backup" },
  { id: "bolt", glyph: "󰚥", label: "Action" }, { id: "power", glyph: "󰐥", label: "Power" }
]
var MAX_ENTRIES = 128

function commandError(value) {
  if (!value || typeof value !== "object" || typeof value.name !== "string" || typeof value.command !== "string") return "Enter a name and command."
  if (!String(value.name || "").trim() || String(value.name).length > 64) return "Use a name between 1 and 64 characters."
  if (!String(value.command || "").trim() || String(value.command).length > 4096) return "Enter a command or script path (up to 4096 characters)."
  if (/[\x00-\x1f\x7f]/.test(String(value.name)) || /\x00/.test(String(value.command))) return "Remove unsupported control characters."
  var directory = String(value.directory || "").trim()
  if (directory.length > 1024 || /[\x00-\x1f\x7f]/.test(directory)) return "Use a valid working folder."
  if (directory && directory.charAt(0) !== "/" && directory !== "~" && directory.indexOf("~/") !== 0) return "Use a full folder path or ~/ for your home folder."
  return ""
}

function normalizeCommands(values) {
  if (!Array.isArray(values)) return []
  var result = [], seen = ({})
  for (var i = 0; i < Math.min(values.length, MAX_ENTRIES); i++) {
    var value = values[i]
    if (!value || !/^custom:[a-z0-9-]{1,64}$/.test(String(value.id || "")) || commandError(value) || seen[value.id]) continue
    seen[value.id] = true
    var icon = ICONS.filter(function(item) { return item.id === value.iconId })[0] || ICONS[0]
    result.push({ id: value.id, kind: "command", name: String(value.name).trim(), command: String(value.command).trim(),
      directory: String(value.directory || "").trim(), terminal: value.terminal === true, iconId: icon.id, iconText: icon.glyph })
  }
  return result
}

function entryForId(id, commands) {
  var wanted = String(id || "")
  var custom = Array.isArray(commands) ? commands : []
  if (wanted.indexOf("custom:") === 0) {
    for (var c = 0; c < Math.min(custom.length, MAX_ENTRIES); c++)
      if (custom[c] && custom[c].id === wanted) return normalizeCommands([custom[c]])[0] || null
    return null
  }
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

function normalizeIds(ids, commands) {
  if (!Array.isArray(ids)) return null
  var result = []
  for (var i = 0; i < Math.min(ids.length, MAX_ENTRIES); i++) {
    var id = String(ids[i] || "")
    if (!entryForId(id, commands) || result.indexOf(id) !== -1) continue
    result.push(id)
  }
  return result
}

function parseData(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || (parsed.version !== 1 && parsed.version !== 2)) return null
    if (parsed.version === 2 && !Array.isArray(parsed.custom)) return null
    var custom = parsed.version === 2 ? normalizeCommands(parsed.custom) : []
    var ids = normalizeIds(parsed.entries, custom)
    return ids === null ? null : { entries: ids, custom: custom }
  } catch (error) { return null }
}

function parseSettings(raw) {
  var data = parseData(raw)
  return data ? data.entries : null
}

function snapshot(ids, commands) {
  var custom = normalizeCommands(commands)
  var normalized = normalizeIds(ids, custom)
  return { version: 2, entries: normalized === null ? DEFAULT_IDS.slice() : normalized, custom: custom }
}

function entries(ids, commands) {
  var normalized = normalizeIds(ids, commands)
  if (normalized === null) normalized = DEFAULT_IDS.slice()
  var result = []
  for (var i = 0; i < normalized.length; i++) {
    var entry = entryForId(normalized[i], commands)
    if (entry) result.push(entry)
  }
  return result
}

function available(ids, commands) {
  var normalized = normalizeIds(ids, commands) || []
  return catalog().filter(function(entry) { return normalized.indexOf(entry.id) === -1 })
}

function add(ids, id, commands) {
  var normalized = normalizeIds(ids, commands) || []
  var wanted = String(id || "")
  if (!entryForId(wanted, commands) || normalized.length >= MAX_ENTRIES || normalized.indexOf(wanted) !== -1) return normalized
  return normalized.concat([wanted])
}

function remove(ids, id, commands) {
  var wanted = String(id || "")
  return (normalizeIds(ids, commands) || []).filter(function(value) { return value !== wanted })
}

function move(ids, id, delta, commands) {
  var normalized = normalizeIds(ids, commands) || []
  var from = normalized.indexOf(String(id || ""))
  var to = from + Number(delta || 0)
  if (from < 0 || to < 0 || to >= normalized.length) return normalized
  var result = normalized.slice()
  var temporary = result[from]
  result[from] = result[to]
  result[to] = temporary
  return result
}
