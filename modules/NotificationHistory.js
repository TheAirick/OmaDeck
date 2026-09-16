.pragma library

function normalizedEntry(value, live, sourceIndex) {
  if (!value || typeof value !== "object") return null
  var summary = String(value.summary || "").trim()
  var body = String(value.body || "").trim()
  if (!summary && !body) return null
  return {
    app: String(value.app || "Notification").slice(0, 256),
    fileName: /^\d{1,20}-\d{1,20}\.json$/.test(String(value.fileName || "")) ? String(value.fileName) : "",
    appIcon: /^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(String(value.appIcon || "")) ? String(value.appIcon) : "",
    summary: summary.slice(0, 4096) || "Notification",
    body: body.slice(0, 32768),
    glyph: String(value.glyph || ""),
    urgency: Number(value.urgency || 0),
    timestamp: Number(value.timestamp || 0),
    originalId: Number(value.originalId === undefined ? -1 : value.originalId),
    live: live === true,
    sourceIndex: Number(sourceIndex)
  }
}

function parseHistory(raw, limit) {
  var rows = []
  var lines = String(raw || "").split(/\n+/)
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line) continue
    try {
      var parsed = JSON.parse(line)
      var normalized = normalizedEntry(parsed, parsed.live === true, -1)
      if (normalized) rows.push(normalized)
    } catch (error) {
      // A torn or legacy row must not hide the remaining valid history.
    }
  }
  rows.sort(function(first, second) { return second.timestamp - first.timestamp })
  return rows.slice(0, Math.max(0, Number(limit || 10)))
}

function merge(liveRows, historyRows, limit) {
  var result = []
  var seen = ({})
  var live = Array.isArray(liveRows) ? liveRows : []
  var history = Array.isArray(historyRows) ? historyRows : []
  for (var i = 0; i < live.length; i++) {
    var liveEntry = normalizedEntry(live[i], true, live[i].sourceIndex)
    if (!liveEntry) continue
    var liveKey = liveEntry.originalId + ":" + liveEntry.timestamp
    seen[liveKey] = true
    result.push(liveEntry)
  }
  for (var j = 0; j < history.length; j++) {
    var entry = normalizedEntry(history[j], history[j].live === true, -1)
    if (!entry) continue
    var key = entry.originalId + ":" + entry.timestamp
    if (seen[key]) continue
    seen[key] = true
    result.push(entry)
  }
  result.sort(function(first, second) { return second.timestamp - first.timestamp })
  return result.slice(0, Math.max(0, Number(limit || 10)))
}


function entryKey(entry) {
  return entry ? String(entry.originalId) + ":" + String(entry.timestamp) + ":" + entry.app : ""
}

function relativeTime(timestamp, now) {
  var elapsed = Math.max(0, Number(now) - Number(timestamp))
  if (!(timestamp > 0) || !isFinite(elapsed)) return "Recent"
  if (elapsed < 60000) return "Just now"
  if (elapsed < 3600000) return Math.floor(elapsed / 60000) + "m ago"
  if (elapsed < 86400000) return Math.floor(elapsed / 3600000) + "h ago"
  return Math.floor(elapsed / 86400000) + "d ago"
}
