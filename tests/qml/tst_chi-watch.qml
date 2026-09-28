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
  Component { id: watchFactory; Stores.BrowserWatchBridge { enabled: false } }
  Component { id: controllerFactory; Stores.WatchController { targetScreen: "DP-3" } }

  function deckFixture() {
    // Temporaries are destroyed in creation order: the controller goes first.
    var watch = createTemporaryObject(controllerFactory, this)
    var browser = createTemporaryObject(watchFactory, this)
    var bridge = browser.chiBridge
    bridge.ready = true
    Mp.Mpris.players.values = [player]
    bridge.update(12, { media_id: "doc:1", has_video: true, page_url: "https://www.youtube.com/watch?v=M7lc1UVf-VE",
      title: player.trackTitle, artwork: player.trackArtUrl, position_ms: 12345, duration_ms: 60000, playing: true })
    watch.browserBridge = browser
    return { bridge: bridge, watch: watch, commands: findChild(bridge, "chiWatchCommands"),
      candidate: bridge.candidateForPlayer("webkit-one", player) }
  }
  function reply(f, data) {
    f.commands.parser.read(JSON.stringify(data || { status: "ok" }))
  }
  function lastSent(f) { return JSON.parse(f.commands.sent[f.commands.sent.length - 1]) }

  function test_deckPlacesChiOwnVideoAndFollowsItsPresentation() {
    var f = deckFixture()
    verify(f.watch.begin(f.candidate, { left: 16, top: 16, width: 704, height: 396 }))
    verify(f.watch.chiDeck)
    compare(f.watch.state, "launching")
    compare(f.watch.videoPosition, 12.345)
    var place = lastSent(f)
    compare(place.cmd, "pip-place")
    compare(place.tab, 12)
    compare(JSON.stringify(place.placement), JSON.stringify({ monitor: "DP-3", x: 16, y: 16, width: 704, height: 396 }))
    reply(f)
    compare(f.watch.state, "launching") // until Chi confirms the presentation
    f.bridge.receiveEvent(JSON.stringify({ event: "tab-state-changed", id: 12, from: "tiled", to: "picture-in-picture" }))
    compare(f.watch.state, "playing")
    // Media reports drive OmaDeck's own controls; no Watch host process.
    f.bridge.update(12, Object.assign({}, f.bridge.tabs[12], { position_ms: 20000, playing: false }))
    compare(f.watch.videoPosition, 20)
    verify(!f.watch.videoPlaying)
    f.watch.togglePlayback()
    var play = lastSent(f)
    compare(play.cmd, "media")
    compare(play.action.action, "guarded")
    compare(play.action.media_id, "doc:1")
    compare(play.action.control.action, "play")
    reply(f)
    f.watch.seekTo(30)
    compare(lastSent(f).action.control.position_ms, 30000)
    reply(f)
    verify(f.watch.setVideoGeometry({ left: 16, top: 27, width: 560, height: 315 }))
    compare(lastSent(f).placement.width, 560)
    reply(f)
    f.watch.returnToSource()
    compare(f.watch.state, "returning")
    compare(lastSent(f).cmd, "pip-release")
    // Release moves Chi's video; that state change is not a lost session.
    f.bridge.receiveEvent(JSON.stringify({ event: "tab-state-changed", id: 12, from: "picture-in-picture", to: "tiled" }))
    compare(f.watch.state, "returning")
    reply(f, { status: "ok", data: "tab" })
    compare(f.watch.state, "idle")
    verify(!f.watch.chiDeck)
    compare(f.watch.notice, "")
  }

  function test_deckEndsWhenChiTakesTheVideoBackOrItsDocumentChanges() {
    var f = deckFixture()
    verify(f.watch.begin(f.candidate, { left: 16, top: 16, width: 704, height: 396 }))
    reply(f)
    f.bridge.receiveEvent(JSON.stringify({ event: "tab-state-changed", id: 12, from: "tiled", to: "picture-in-picture" }))
    var sent = f.commands.sent.length
    f.bridge.receiveEvent(JSON.stringify({ event: "tab-state-changed", id: 12, from: "picture-in-picture", to: "tiled" }))
    compare(f.watch.state, "idle")
    compare(f.watch.notice, "Video returned to Chi")
    compare(f.commands.sent.length, sent) // nothing sent to a video Chi already moved
    verify(f.watch.begin(f.candidate, { left: 16, top: 16, width: 704, height: 396 }))
    reply(f)
    f.bridge.receiveEvent(JSON.stringify({ event: "tab-state-changed", id: 12, from: "tiled", to: "picture-in-picture" }))
    f.bridge.update(12, Object.assign({}, f.bridge.tabs[12], { media_id: "replacement" }))
    compare(f.watch.state, "idle")
    compare(f.watch.notice, "Video changed in Chi")
  }

  function test_closePausesBeforeReleasingAndRefusalFallsBackToEmbeddedPlayer() {
    var f = deckFixture()
    verify(f.watch.begin(f.candidate, { left: 16, top: 16, width: 704, height: 396 }))
    reply(f)
    f.bridge.receiveEvent(JSON.stringify({ event: "tab-state-changed", id: 12, from: "tiled", to: "picture-in-picture" }))
    f.watch.abort()
    var pause = JSON.parse(f.commands.sent[f.commands.sent.length - 1])
    compare(pause.action.control.action, "pause")
    reply(f)
    compare(lastSent(f).cmd, "pip-release")
    reply(f, { status: "ok", data: "picture-in-picture" })
    compare(f.watch.state, "idle")
    // A background (shelved) tab keeps the existing embedded path.
    f.bridge.receiveEvent(JSON.stringify({ event: "tab-state-changed", id: 12, from: "tiled", to: "shelved" }))
    verify(!f.watch.canPresentInChi(f.candidate))
    // Chi can also refuse (for example another PiP is open).
    f.bridge.receiveEvent(JSON.stringify({ event: "tab-state-changed", id: 12, from: "shelved", to: "tiled" }))
    verify(f.watch.begin(f.candidate, { left: 16, top: 16, width: 704, height: 396 }))
    reply(f, { status: "error", message: "return the current picture-in-picture video first" })
    verify(!f.watch.chiDeck)
    compare(f.watch.state, "idle") // no native host in this fixture
    compare(f.watch.notice, "Chi could not show this video here")
  }

  Component { id: signalSpy; SignalSpy {} }
}
