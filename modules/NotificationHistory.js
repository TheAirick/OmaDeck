.pragma library

function normalizedEntry(value, live, sourceIndex) {
  if (!value || typeof value !== "object") return null
  var summary = String(value.summary || "").trim()
  var body = String(value.body || "").trim()
  if (!summary && !body) return null
  return {
    app: String(value.app || "Notification"),
    summary: summary || "Notification",
    body: body,
    glyph: String(value.glyph || ""),
    urgency: Number(value.urgency || 0),
    timestamp: Number(value.timestamp || 0),
    originalId: Number(value.originalId || -1),
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
      var normalized = normalizedEntry(JSON.parse(line), false, -1)
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
    var entry = normalizedEntry(history[j], false, -1)
    if (!entry) continue
    var key = entry.originalId + ":" + entry.timestamp
    if (seen[key]) continue
    seen[key] = true
    result.push(entry)
  }
  result.sort(function(first, second) { return second.timestamp - first.timestamp })
  return result.slice(0, Math.max(0, Number(limit || 10)))
}
