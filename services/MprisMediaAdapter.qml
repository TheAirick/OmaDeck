import QtQuick
import Quickshell.Services.Mpris

// Uses Quickshell's shared discovery model when the host keeps its service
// objects private. No extra D-Bus watcher, helper process, or polling loop.
QtObject {
  id: root

  property bool enabled: true
  property string preferredPlayerKey: ""
  readonly property var players: enabled && Mpris.players ? Mpris.players.values : []
  readonly property var activePlayer: selectPlayer()

  function playerKey(player) { return player ? String(player.dbusName || "") : "" }

  function playerForKey(key) {
    if (!key) return null
    for (var i = 0; i < players.length; i++) {
      if (playerKey(players[i]) === key) return players[i]
    }
    return null
  }

  function selectPlayer() {
    var preferred = playerForKey(preferredPlayerKey)
    if (preferred) return preferred
    var candidate = null
    for (var i = 0; i < players.length; i++) {
      var player = players[i]
      if (!player || !playerKey(player)) continue
      // Prefer a playing source, then one with track metadata. Stable bus-name
      // ordering avoids a presentation change when the discovery list reorders.
      var score = (player.isPlaying ? 4 : 0)
        + (player.trackTitle || player.trackArtist ? 2 : 0)
        + (player.canControl ? 1 : 0)
      var previousScore = candidate ? candidate.score : -1
      if (score > previousScore || (score === previousScore
          && playerKey(player) < playerKey(candidate.player)))
        candidate = { player: player, score: score }
    }
    return candidate ? candidate.player : null
  }

  function runAction(action, showFeedback, targetKey) {
    var player = playerForKey(targetKey)
    if (!player || !player.canControl) return false
    if (action === "playPause") {
      if (player.isPlaying && player.canPause) player.pause()
      else if (!player.isPlaying && player.canPlay) player.play()
      else return false
    } else if (action === "next" && player.canGoNext) player.next()
    else if (action === "previous" && player.canGoPrevious) player.previous()
    else return false
    preferredPlayerKey = targetKey
    return true
  }
}
