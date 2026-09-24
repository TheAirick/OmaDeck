.pragma library

// Keep the handoff independent of the browser's MPRIS bus name. Firefox,
// Zen, and Chromium can all supply the same source contract.
function youtubeVideoId(rawUrl) {
  var url = String(rawUrl || "")
  var watch = url.match(/^https:\/\/(?:www\.|m\.|music\.)?youtube\.com\/watch\?([^#]*)/i)
  if (watch) {
    var parts = watch[1].split("&")
    for (var i = 0; i < parts.length; i++) {
      var video = parts[i].match(/^v=([A-Za-z0-9_-]{11})$/)
      if (video) return video[1]
    }
  }
  var short = url.match(/^https:\/\/youtu\.be\/([A-Za-z0-9_-]{11})(?:[?#]|$)/i)
  return short ? short[1] : ""
}

function candidate(player, sourceKey) {
  if (!player || !sourceKey || !player.metadata) return null
  var videoId = youtubeVideoId(player.metadata["xesam:url"])
  if (!videoId) return null
  var position = Number(player.position)
  var seconds = isFinite(position) && position >= 0
    ? Math.min(Math.floor(position), 604800) : 0
  return {
    videoId: videoId,
    seconds: seconds,
    sourceKey: String(sourceKey),
    sourceWasPlaying: !!player.isPlaying
  }
}
