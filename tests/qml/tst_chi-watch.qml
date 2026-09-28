import QtQuick
import QtTest
import Quickshell.Services.Mpris as Mp
import "../../services" as Stores

TestCase {
  name: "ChiWatchBridge"
  when: windowShown
  Component { id: factory; Stores.ChiWatchBridge { enabled: false } }
  property var player: ({ identity: "Chi", dbusName: "webkit-one", trackTitle: "Video",
    trackArtUrl: "https://i.ytimg.com/vi/M7lc1UVf-VE/hqdefault.jpg" })
  function fixture() {
    var bridge = createTemporaryObject(factory, this)
    bridge.ready = true
    Mp.Mpris.players.values = [player]
    bridge.update(12, { media_id: "doc:1", has_video: true, page_url: "https://www.youtube.com/watch?v=M7lc1UVf-VE",
      title: player.trackTitle, artwork: player.trackArtUrl, position_ms: 12345, playing: true })
    return bridge
  }
  function test_exactCandidateAndAmbiguousPlayers() {
    var bridge = fixture()
    var c = bridge.candidateForPlayer("webkit-one", player)
    compare(c.tabId, 12)
    compare(c.seconds, 12)
    compare(c.mediaId, "doc:1")
    compare(c.browser, "chi")
    verify(bridge.connectedSource(c))
    Mp.Mpris.players.values = [player, Object.assign({}, player, {dbusName: "webkit-two"})]
    compare(bridge.candidateForPlayer("webkit-one", player), null)
    Mp.Mpris.players.values = [player]
    bridge.update(13, bridge.tabs[12])
    compare(bridge.candidateForPlayer("webkit-one", player), null)
  }
  function test_navigationAndReloadRetireOnlyOriginalIdentity() {
    var bridge = fixture()
    var c = bridge.candidateForPlayer("webkit-one", player)
    var spy = signalSpy.createObject(this, {target:bridge, signalName:"sourceClosed"})
    bridge.update(12, Object.assign({}, bridge.tabs[12], {media_id:"replacement"}))
    compare(spy.count, 1)
    verify(!bridge.connectedSource(c))
    verify(!bridge.command(c, "resume", 10, true, 7))
    spy.destroy()
  }
  function test_guardedReturnWaitsForEveryConfirmedAction() {
    var bridge = fixture()
    var c = bridge.candidateForPlayer("webkit-one", player)
    var spy = signalSpy.createObject(this, {target:bridge, signalName:"result"})
    verify(bridge.command(c, "resume", 42.125, true, 7))
    compare(JSON.parse(findChild(bridge, "chiWatchCommands").sent[0]).cmd, "media-hold")
    compare(bridge.tasks[7].actions.length, 2) // pause in flight; seek + play queued locally
    var token = bridge.tasks[7].token
    bridge.receiveEvent(JSON.stringify({event:"media-action-finished",tab:12,media_id:"doc:1",request:"stale",ok:true,position_ms:42125}))
    compare(bridge.tasks[7].token, token)
    for (var i = 0; i < 3; i++) {
      bridge.receiveEvent(JSON.stringify({event:"media-action-finished",tab:12,media_id:"doc:1",request:bridge.tasks[7].token,ok:true,position_ms:42125}))
    }
    compare(spy.count, 1)
    compare(spy.signalArguments[0][0], 7)
    compare(spy.signalArguments[0][1], true)
    compare(spy.signalArguments[0][2], 42.125)
    verify(!bridge.tasks[7])
    spy.destroy()
  }
  function test_failureNeverSchedulesPlayAndCancellationDropsQueuedWork() {
    var bridge = fixture()
    var c = bridge.candidateForPlayer("webkit-one", player)
    verify(bridge.command(c, "resume", 42, true, 8))
    bridge.receiveEvent(JSON.stringify({event:"media-action-finished",tab:12,media_id:"doc:1",request:bridge.tasks[8].token,ok:false,position_ms:0}))
    verify(!bridge.tasks[8])
    verify(bridge.command(c, "resume", 42, true, 9))
    bridge.forget(9)
    verify(!bridge.tasks[9])
    verify(!bridge.queue.some(e=>e.taskId===9))
    bridge.releaseSource(c)
    compare(bridge.held, null)
  }
  Component { id: signalSpy; SignalSpy {} }
}
