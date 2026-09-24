const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');
const {spawn,execFileSync} = require('node:child_process');
const {chromium} = require('playwright-core');
// Optional live network check. Requires playwright-core on NODE_PATH and a
// Chromium build supporting unpacked extensions. Uses only disposable profiles.
const repo = path.resolve(__dirname, '../..');
const chromiumPath = process.env.OMADECK_TEST_CHROMIUM;
if (!chromiumPath) throw Error('Set OMADECK_TEST_CHROMIUM to a Chromium executable');
const shellQuote = value => "'" + value.replaceAll("'", "'\"'\"'") + "'";
const lab = fs.mkdtempSync('/tmp/omadeck-watch-live-');
const runtime = path.join(lab,'runtime'); fs.mkdirSync(runtime,{mode:0o700});
const config = path.join(lab,'config'); fs.mkdirSync(config);
const extension = path.join(lab,'extension'); fs.mkdirSync(extension);
for(const f of ['background.js','content.js','manifest.chromium.json']) {
  const bytes=process.env.OMADECK_TEST_EXTENSION_REF
    ? execFileSync('git',['show',process.env.OMADECK_TEST_EXTENSION_REF+':browser/watch-extension/'+f],{cwd:repo})
    : fs.readFileSync(path.join(repo,'browser/watch-extension',f));
  fs.writeFileSync(path.join(extension,f.startsWith('manifest.')?'manifest.json':f),bytes);
}
fs.symlinkSync(path.join(repo,'services'),path.join(lab,'services'));
fs.mkdirSync(path.join(lab,'native/bin'),{recursive:true});
fs.writeFileSync(path.join(lab,'native/bin/omadeck-watch-host'),`#!/bin/sh\nexec ${shellQuote(path.join(repo,'native/bin/omadeck-watch-host'))} --offscreen-host "$@"\n`,{mode:0o755});
fs.writeFileSync(path.join(lab,'relay'),`#!/bin/sh\nexport XDG_RUNTIME_DIR='${runtime}'\nexec ${shellQuote(path.join(repo,'scripts/browser-watch-native-host'))} "$@"\n`,{mode:0o755});
fs.writeFileSync(path.join(lab,'shell.qml'),`import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Stores
ShellRoot {
  id: root
  property string family: "chromium"
  property string sourceKey: nativeMedia.activePlayer ? nativeMedia.activePlayer.dbusName : "org.mpris.MediaPlayer2." + family + ".integration"
  Stores.MprisMediaAdapter { id: nativeMedia }
  Stores.BrowserWatchBridge { id: bridge }
  Stores.WatchController { id: watch; pluginDir: ${JSON.stringify(lab)}; media: nativeMedia; browserBridge: bridge }
  function snapshot() { return { state:watch.state, notice:watch.notice, available:watch.hostAvailable,
    position:watch.videoPosition, duration:watch.videoDuration, playing:watch.videoPlaying, shuttingDown:watch.shuttingDown,
    captionsAvailable:watch.captionsAvailable,captionsEnabled:watch.captionsEnabled,sourcePaused:watch.sourcePausedByUs, sourceClosed:watch.sourceClosed, focused:watch.focused, candidate:bridge.candidateForPlayer(sourceKey),
    mprisPlayers:nativeMedia.players.map(p=>p.dbusName), connections:bridge.connections.length, pending:Object.keys(bridge.pendingRequests).length } }
  SocketServer {
    path: "${runtime}/control.sock"; active:true
    handler: Socket { id: client
      parser: SplitParser { splitMarker:"\\n"; onRead: line => {
        var m=JSON.parse(line); var ok=true
        if(m.op === "begin") ok=watch.begin(bridge.candidateForPlayer(root.sourceKey),{left:0,top:0,width:768,height:432})
        else if(m.op === "captions") watch.toggleCaptions()
        else if(m.op === "toggle") watch.togglePlayback()
        else if(m.op === "seek") watch.seekTo(m.seconds)
        else if(m.op === "return") watch.returnToSource()
        else if(m.op === "abort") watch.abort()
        else if(m.op === "geometry") ok=watch.setVideoGeometry(m.rect)
        else if(m.op === "focus") ok=watch.setFocus(m.focused,m.rect)
        else if(m.op === "family") root.family=m.family
        client.write(JSON.stringify({id:m.id,ok:ok,data:root.snapshot()})+"\\n");client.flush()
      } }
    }
  }
}`);
const env={...process.env,XDG_RUNTIME_DIR:runtime,XDG_CONFIG_HOME:config,QT_QPA_PLATFORM:'offscreen',QT_QPA_PLATFORMTHEME:'basic',GTK_USE_PORTAL:'0',NO_AT_BRIDGE:'1',QT_QUICK_BACKEND:'software',QSG_RHI_BACKEND:'software',QTWEBENGINE_CHROMIUM_FLAGS:'--mute-audio'};
delete env.WAYLAND_DISPLAY;delete env.DISPLAY;
const log=fs.openSync(path.join(lab,'quickshell.log'),'w');
const qs=spawn('qs',['-p',path.join(lab,'shell.qml')],{env,stdio:['ignore',log,log]});
let context, control; let counter=0; const replies=new Map();
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function waitFor(fn,label,ms=20000) {const end=Date.now()+ms;let v;while(Date.now()<end){v=await fn();if(v)return v;await delay(200)}throw Error('Timed out: '+label)}
function command(op,extra={}){return new Promise((resolve,reject)=>{const id=++counter;const timer=setTimeout(()=>{replies.delete(id);reject(Error('control timeout'))},5000);replies.set(id,r=>{clearTimeout(timer);resolve(r)});control.write(JSON.stringify({id,op,...extra})+'\n')})}
async function status(){return (await command('status')).data}
async function videoState(page){return page.evaluate(()=>{const v=document.querySelector('video');return v?{paused:v.paused,time:v.currentTime,ready:v.readyState,duration:v.duration,error:v.error?.code,muted:v.muted}:null})}
(async()=>{
  console.log('LAB '+lab);
  await waitFor(()=>fs.existsSync(path.join(runtime,'control.sock')),'QML control');
  control=net.createConnection(path.join(runtime,'control.sock'));let buffer='';
  control.on('data',d=>{buffer+=d;while(buffer.includes('\n')){const p=buffer.indexOf('\n');const m=JSON.parse(buffer.slice(0,p));buffer=buffer.slice(p+1);replies.get(m.id)?.(m);replies.delete(m.id)}});
  context=await chromium.launchPersistentContext(path.join(lab,'profile'),{executablePath:chromiumPath,headless:true,env,args:[`--disable-extensions-except=${extension}`,`--load-extension=${extension}`,'--mute-audio','--autoplay-policy=no-user-gesture-required']});
  const worker=context.serviceWorkers()[0]||await context.waitForEvent('serviceworker');
  const id=worker.url().split('/')[2];console.log('EXTENSION '+id);
  for(const dir of ['chromium','google-chrome','google-chrome-for-testing'].map(browser=>path.join(config,browser,'NativeMessagingHosts')).concat([path.join(lab,'profile','NativeMessagingHosts')])){fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'pretty.omadeck.watch.json'),JSON.stringify({name:'pretty.omadeck.watch',description:'Isolated OmaDeck test',path:path.join(lab,'relay'),type:'stdio',allowed_origins:[`chrome-extension://${id}/`]}));}
  const page=context.pages()[0]||await context.newPage();
  await page.goto('https://www.youtube.com/watch?v=jNQXAC9IVRw',{waitUntil:'domcontentloaded',timeout:45000});
  await waitFor(async()=>{const v=await videoState(page);return v?.ready>=2?v:null},'YouTube source ready',45000);
  await page.evaluate(async()=>{const v=document.querySelector('video');v.muted=false;v.currentTime=2;await v.play()});
  console.log('SOURCE '+JSON.stringify(await videoState(page)));
  await waitFor(async()=>{const s=await status();return s.candidate?.sourceWasPlaying?s:null},'extension candidate').catch(async e=>{console.log('DEBUG '+JSON.stringify({deck:await status(),extension:await worker.evaluate(()=>({lastCandidate,nativeConnected:!!nativePort}))}));throw e});
  const offered=await status();
  if(!offered.mprisPlayers.includes(offered.candidate.sourceKey)) throw Error('Source MPRIS player missing');
  console.log('CANDIDATE '+JSON.stringify(offered));
  const otherPage=await context.newPage();await otherPage.goto('about:blank');await otherPage.bringToFront();
  await delay(1200);
  if(!(await status()).candidate)throw Error('Background source was cleared');
  console.log('BEGIN '+JSON.stringify(await command('begin')));
  const playing=await waitFor(async()=>{const s=await status();if(s.notice)throw Error(s.notice);return s.state==='playing'?s:null},'handoff playing',22000);
  await waitFor(async()=>Math.abs((await status()).position-(await videoState(page)).time)<2,'aligned handoff'); console.log('HANDOFF '+JSON.stringify({deck:await status(),source:await videoState(page)}));
  await waitFor(async()=>(await status()).captionsAvailable,'caption API');
  if((await status()).captionsEnabled)throw Error('Captions should start off');
  await command('captions');await waitFor(async()=>(await status()).captionsEnabled,'captions on');
  await command('captions');await waitFor(async()=>!(await status()).captionsEnabled,'captions off');
  console.log('PASS captions default off, toggle on and off');
  await command('seek',{seconds:8});await waitFor(async()=>{const s=await status();return s.position>=7&&s.position<13?s:null},'host seek');
  await command('toggle');await waitFor(async()=>!(await status()).playing,'host pause');
  await command('toggle');await waitFor(async()=>(await status()).playing,'host play');
  await otherPage.bringToFront();
  const returnedAt=(await status()).position;console.log('RETURN_REQUEST '+JSON.stringify(await command('return')));
  await waitFor(async()=>(await status()).state==='idle','return').catch(async e=>{console.log('DEBUG_RETURN '+JSON.stringify({deck:await status(),source:await videoState(page),page:await page.evaluate(()=>({error:document.querySelector('.ytp-error')?.textContent,videos:[...document.querySelectorAll('video')].map(v=>({time:v.currentTime,ready:v.readyState,paused:v.paused,src:!!v.currentSrc}))})),extension:await worker.evaluate(()=>({lastCandidate,nativeConnected:!!nativePort}))}));throw e});
  const returned=await videoState(page);console.log('RETURN '+JSON.stringify({returnedAt,source:returned,deck:await status()}));
  if(returned.paused||Math.abs(returned.time-returnedAt)>3)throw Error('Return playback or position mismatch');
  console.log('PASS chromium background YouTube handoff, seek, pause/play, return to background tab');
  await otherPage.close();await page.bringToFront();
  if (process.env.OMADECK_TEST_STRESS === '1') {
    await require('./watch-stress-scenarios.cjs')({page,context,worker,command,status,waitFor,videoState,delay,runtime,lab});
  }
  async function beginAgain(){await page.evaluate(async()=>{const v=document.querySelector('video');v.currentTime=2;await v.play()});await waitFor(async()=>{const c=(await status()).candidate;return c&&c.sourceWasPlaying&&c.seconds<5},'fresh next session');await command('begin');await waitFor(async()=>(await status()).state==='playing','next session playing');}
  await beginAgain();
  const hostSocket=fs.readdirSync(runtime).find(n=>{if(!/^omadeck-watch-[0-9]+-[0-9a-f]+\.sock$/.test(n))return false;try{process.kill(Number(n.split('-')[2]),0);return true}catch{return false}});
  if(!hostSocket)throw Error('No owned host socket');
  process.kill(Number(hostSocket.split('-')[2]),'SIGKILL');
  await waitFor(async()=>(await status()).state==='idle','renderer loss cleanup');
  await waitFor(async()=>!(await videoState(page)).paused,'renderer loss source restore');
  console.log('PASS renderer loss restores browser '+JSON.stringify(await status()));
  await beginAgain();await context.close();context=null;
  await waitFor(async()=>(await status()).state==='idle','browser loss cleanup');
  console.log('PASS browser loss cleans watch '+JSON.stringify(await status()));
})().catch(e=>{console.error(e.stack);process.exitCode=1}).finally(async()=>{if(context)await context.close();if(control)control.destroy();qs.kill('SIGTERM');fs.closeSync(log);console.log('LOG '+path.join(lab,'quickshell.log'))});
