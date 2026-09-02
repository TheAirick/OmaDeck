import QtQuick
import Quickshell.Io

// SplitParser with an empty delimiter forwards each read chunk without
// retaining the full stream. Consumers get only a bounded UTF-8 prefix.
SplitParser {
  id: root

  property int maxBytes: 64 * 1024
  property string text: ""
  property bool truncated: false

  splitMarker: ""

  function utf8ByteLength(value) {
    var encoded = encodeURIComponent(String(value || ""))
    var bytes = 0
    for (var index = 0; index < encoded.length; index++) {
      if (encoded[index] === "%") index += 2
      bytes++
    }
    return bytes
  }

  function boundedPrefix(value, limit) {
    var prefix = ""
    var used = 0
    value = String(value || "")
    for (var index = 0; index < value.length;) {
      var next = index + 1
      var first = value.charCodeAt(index)
      if (first >= 0xd800 && first <= 0xdbff && index + 1 < value.length) {
        var second = value.charCodeAt(index + 1)
        if (second >= 0xdc00 && second <= 0xdfff) next++
      }
      var unit = value.slice(index, next)
      var unitBytes = utf8ByteLength(unit)
      if (used + unitBytes > limit) break
      prefix += unit
      used += unitBytes
      index = next
    }
    return prefix
  }

  function append(value) {
    value = String(value || "")
    if (value === "" || truncated) return
    var remaining = maxBytes - utf8ByteLength(text)
    if (remaining <= 0) {
      truncated = true
      return
    }
    if (utf8ByteLength(value) <= remaining) {
      text += value
      return
    }
    text += boundedPrefix(value, remaining)
    truncated = true
  }

  function reset() {
    text = ""
    truncated = false
  }

  onRead: function(value) { root.append(value) }
}
