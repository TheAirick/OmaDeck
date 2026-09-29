import QtQuick
import Quickshell.Services.Mpris

// The Now Playing card's sources: every desktop media player, with Chi's
// single WebKit player expanded into Chi's own recent videos. Most recently
// started first. Pausing never switches the card; starting something does,
// and a swipe picks any source. Presents the media-service API the card
// expects, so `activePlayer` is the selected source.
QtObject {
  id: root

  property var source: null   // Omarchy's media service or MprisMediaAdapter
  property var chi: null      // ChiWatchBridge, when present
  property string selectedKey: ""
  // Source key -> when it last started playing (ms). Reassigned to notify.
  property var startedAt: ({})
  property var chiPlaying: ({})

  // Service lists can arrive as Qt sequences rather than JS arrays.
  function asArray(value) {
    if (!value) return []
    if (Array.isArray(value)) return value
    return typeof value.length === "number" ? Array.prototype.slice.call(value) : []
  }
  readonly property var players: {
    var curated = asArray(source ? source.sourcePlayers : null)
    if (curated.length) return curated
    var own = asArray(source ? source.players : null)
    if (own.length) return own
    return asArray(Mpris.players ? Mpris.players.values : null)
  }
  readonly property var entries: buildEntries()
  readonly property int index: indexOf(selectedKey)
  readonly property var selected: entries.length ? entries[index] : null
  readonly property int count: entries.length
  readonly property var activePlayer: selected ? selected.player : (source ? source.activePlayer : null)
  // The Chi tab shown, or -1 for any other player.
  readonly property int selectedChiTab: selected ? selected.tab : -1

  function keyOf(player) {
    return source && typeof source.playerKey === "function" ? source.playerKey(player) : String(player && player.dbusName || "")
  }
  function playerKey(player) { return keyOf(player) }
  function playerForKey(key) { return source && typeof source.playerForKey === "function" ? source.playerForKey(key) : null }
  function runAction(action, showFeedback, key) {
    return !!source && typeof source.runAction === "function" && source.runAction(action, showFeedback, key)
  }

  function buildEntries() {
    var list = []
    var chiPlayer = null
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!p || !keyOf(p)) continue
      if (String(p.identity) === "Chi") { chiPlayer = chiPlayer || p; continue }
      if (!(p.trackTitle || p.trackArtist || p.isPlaying)) continue
      list.push({ key: "player:" + keyOf(p), player: p, tab: -1, rank: 100 + i })
    }
    var chiTabs = chi && chi.ready ? asArray(chi.recent).filter(function(tab) { return !!chi.tabs[tab] }) : []
    if (chiPlayer && chiTabs.length) {
      for (var j = 0; j < chiTabs.length; j++)
        list.push({ key: "chi:" + chiTabs[j], player: chiPlayer, tab: chiTabs[j], rank: j })
    } else if (chiPlayer) {
      list.push({ key: "player:" + keyOf(chiPlayer), player: chiPlayer, tab: -1, rank: 50 })
    }
    var started = startedAt
    return list.sort(function(a, b) {
      var sa = started[a.key] || 0, sb = started[b.key] || 0
      if (sa !== sb) return sb - sa
      return a.rank - b.rank
    })
  }
  function indexOf(key) {
    for (var i = 0; i < entries.length; i++) if (entries[i].key === key) return i
    return 0
  }

  // Something started: remember when, and show it.
  function started(key) {
    var next = Object.assign({}, startedAt)
    next[key] = Date.now()
    startedAt = next
    selectedKey = key
  }
  function select(i) { if (i >= 0 && i < entries.length) selectedKey = entries[i].key }
  function next() { if (count > 1) select((index + 1) % count) }
  function previous() { if (count > 1) select((index - 1 + count) % count) }

  // Other players report their own playing state. Chi's WebKit player does
  // not track the right video, so Chi sources come from Chi itself.
  property Instantiator playerWatch: Instantiator {
    model: root.players
    delegate: QtObject {
      required property var modelData
      readonly property bool playing: !!modelData && !!modelData.isPlaying && String(modelData.identity) !== "Chi"
      onPlayingChanged: if (playing) root.started("player:" + root.keyOf(modelData))
    }
  }
  property Connections chiWatch: Connections {
    target: root.chi
    ignoreUnknownSignals: true
    function onMediaUpdated(tabId, media) {
      var audible = !!media && !!media.playing && !media.muted
      var was = !!root.chiPlaying[tabId]
      if (audible !== was) {
        var next = Object.assign({}, root.chiPlaying)
        next[tabId] = audible
        root.chiPlaying = next
      }
      if (audible && !was) root.started("chi:" + tabId)
    }
    function onDropped() { root.chiPlaying = ({}) }
  }
}
