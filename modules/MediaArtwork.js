function trackUrl(player) {
  if (!player || !player.metadata) return ""
  return String(player.metadata["xesam:url"] || "")
}

function youtubeVideoId(rawUrl) {
  var url = String(rawUrl || "")
  var match = url.match(/(?:youtube\.com\/(?:watch\?(?:[^#]*&)?v=|shorts\/|embed\/)|youtu\.be\/)([A-Za-z0-9_-]{6,})/i)
  return match ? match[1] : ""
}

function youtubeThumbnail(rawUrl) {
  var videoId = youtubeVideoId(rawUrl)
  return videoId ? "https://i.ytimg.com/vi/" + videoId + "/mqdefault.jpg" : ""
}
