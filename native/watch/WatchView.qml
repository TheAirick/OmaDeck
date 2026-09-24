import QtQuick
import QtWebEngine

WebEngineView {
  id: root
  objectName: "watchVideo"
  anchors.fill: parent
  backgroundColor: "black"
  profile: WebEngineProfile { offTheRecord: true }
  settings.playbackRequiresUserGesture: false
  property bool polling: false
  property bool reportedPrimed: false
  property real reportedDuration: 0

  Component.onCompleted: {
    if (watchProbe) loadHtml("<!doctype html><title>OmaDeck watch probe</title>")
  }

  function watchHtml(videoId, seconds) {
    // Both values are validated in the native host before reaching this page.
    var id = JSON.stringify(videoId)
    var start = Math.floor(seconds)
    return [
      '<!doctype html><html><head><meta charset="utf-8">',
      '<meta name="viewport" content="width=device-width,initial-scale=1">',
      '<style>html,body,#player{margin:0;width:100%;height:100%;background:#000;overflow:hidden}</style>',
      '</head><body><div id="player"></div><script>',
      'const videoId=', id, ';const startSeconds=', start, ';',
      'let player=null;let captionsWanted=false;let savedCaptionTrack=null;window.omadeckError=0;',
      'function applyCaptions(){if(!player||typeof player.getOption!=="function")return;const track=player.getOption("captions","track");if(track&&track.languageCode)savedCaptionTrack=track;if(captionsWanted){if(typeof player.loadModule==="function")player.loadModule("captions");if(savedCaptionTrack)player.setOption("captions","track",savedCaptionTrack);}else if(track&&track.languageCode){player.setOption("captions","track",{});}}',
      'function onYouTubeIframeAPIReady(){player=new YT.Player("player",{',
      'videoId:videoId,playerVars:{playsinline:1,controls:0,cc_load_policy:0,rel:0,origin:"http://127.0.0.1:9"},',
      'events:{onReady:function(e){e.target.mute();e.target.loadVideoById({videoId:videoId,startSeconds:startSeconds});},',
      'onApiChange:function(){if(!captionsWanted)applyCaptions();},',
      'onError:function(e){window.omadeckError=e.data;}}});}',
      'window.omadeckControl=function(action,seconds){if(!player)return;',
      'if(action==="commit"){player.seekTo(seconds,true);player.unMute();}',
      'else if(action==="play"){player.playVideo();}',
      'else if(action==="pause"){player.pauseVideo();}',
      'else if(action==="captionsOn"||action==="captionsOff"){captionsWanted=action==="captionsOn";applyCaptions();}',
      'else if(action==="seek"){player.seekTo(seconds,true);}};',
      '</script><script src="https://www.youtube.com/iframe_api"></script></body></html>'
    ].join("")
  }

  Connections {
    target: watchBridge
    function onLoadRequested(videoId, seconds) {
      root.reportedPrimed = false
      root.reportedDuration = 0
      root.polling = true
      try {
        root.loadHtml(root.watchHtml(videoId, seconds), "http://127.0.0.1:9/")
      } catch (error) {
        watchBridge.playerError(-2)
      }
    }
    function onControlRequested(action, seconds) {
      if (action === "returnSnapshot") {
        root.runJavaScript("(function(){if(!player||typeof player.getCurrentTime!=='function')return -1;player.pauseVideo();return player.getCurrentTime();})()",
          function(result) { if (typeof result === "number" && result >= 0) watchBridge.returnSnapshot(result) })
        return
      }
      root.runJavaScript("window.omadeckControl(" + JSON.stringify(action)
        + "," + Number(seconds) + ")")
    }
  }

  onLoadingChanged: function(request) {
    if (watchProbe && (request.status === WebEngineView.LoadSucceededStatus
        || request.status === WebEngineView.LoadFailedStatus)) {
      watchBridge.probeLoaded(request.status === WebEngineView.LoadSucceededStatus)
      return
    }
    if (request.status === WebEngineView.LoadFailedStatus) watchBridge.playerError(-1)
  }

  Timer {
    interval: 500
    repeat: true
    running: root.polling
    onTriggered: root.runJavaScript(
      "JSON.stringify({error:window.omadeckError||0,ready:!!player&&typeof player.getPlayerState==='function',state:player&&typeof player.getPlayerState==='function'?player.getPlayerState():-1,time:player&&typeof player.getCurrentTime==='function'?player.getCurrentTime():0,duration:player&&typeof player.getDuration==='function'?player.getDuration():0,captionApi:!!player&&typeof player.setOption==='function'&&!!savedCaptionTrack,captions:captionsWanted})",
      function(result) {
        if (!root.polling || !result) return
        var value
        try { value = JSON.parse(result) } catch (error) { return }
        if (value.error) { root.polling = false; watchBridge.playerError(value.error); return }
        if (!value.ready) return
        if (value.state === 1 && !root.reportedPrimed) {
          root.reportedPrimed = true
          watchBridge.primed(value.time)
        }
        if (value.duration > 0 && Math.abs(value.duration - root.reportedDuration) > 1) {
          root.reportedDuration = value.duration
          watchBridge.playerDuration(value.duration)
        }
        watchBridge.playerState(value.state)
        watchBridge.playerPosition(value.time)
        watchBridge.captionState(value.captionApi, value.captions)
      })
  }
}
