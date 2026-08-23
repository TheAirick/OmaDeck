function nodeProps(node) {
  return node && node.ready && node.properties ? node.properties : {}
}

function isPlaybackStream(node) {
  if (!node || !node.isStream) return false
  if (node.isSink === true) return true
  var mediaClass = String(node.type || "")
  return mediaClass.indexOf("Stream/Output/Audio") !== -1
    || mediaClass.indexOf("AudioOutStream") !== -1
    || mediaClass.indexOf("Output") !== -1
}

function rawStreamLabel(node) {
  if (!node) return ""
  var p = nodeProps(node)
  return p["application.name"] || node.description || p["media.name"]
    || p["node.name"] || node.name || "Stream"
}

function streamLabel(node) {
  var label = String(rawStreamLabel(node) || "Stream").trim()
  if (label.toLowerCase() === "audio-src") return "Browser audio"
  return label
}

function categoryFor(node) {
  var p = nodeProps(node)
  var haystack = String([
    rawStreamLabel(node), node && node.name, node && node.description,
    p["application.process.binary"], p["application.id"], p["media.name"]
  ].join(" ")).toLowerCase()

  if (/discord|vesktop|teams|slack|zoom|webex|mumble|teamspeak|voice/.test(haystack)) return "voice"
  if (/world of warcraft|wow-|steam_app|gamescope|lutris|heroic|proton|wine|game/.test(haystack)) return "games"
  if (/zen|firefox|chromium|chrome|spotify|vlc|mpv|music|video|youtube|plex|jellyfin|browser/.test(haystack)) return "media"
  return "other"
}
