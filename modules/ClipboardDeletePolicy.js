.pragma library

function sameEntry(left, right) {
  if (!left || !right || String(left.type || "") !== String(right.type || "")) return false
  if (left.type === "image") {
    return String(left.path || "") === String(right.path || "")
      && String(left.mime || "image/png") === String(right.mime || "image/png")
  }
  // The snapshot text is only a preview. Qt.md5 hashes the full UTF-8 text,
  // matching system-stats; this checksum detects stale selections, not trust.
  if (right.textDigest !== undefined) {
    return typeof left.text === "string" && /^[a-f0-9]{32}$/.test(right.textDigest)
      && Qt.md5(left.text) === right.textDigest
  }
  return String(left.text || "") === String(right.text || "")
}

function removeEntry(history, selected) {
  var current = Array.isArray(history) ? history.slice() : []
  var index = selected ? selected.historyIndex : -1
  if (typeof index !== "number" || !isFinite(index) || Math.floor(index) !== index
      || index < 0 || index >= current.length || !sameEntry(current[index], selected)) {
    return { ok: false, reason: "changed", history: current }
  }

  current.splice(index, 1)
  return { ok: true, reason: "", history: current, removedIndex: index }
}
