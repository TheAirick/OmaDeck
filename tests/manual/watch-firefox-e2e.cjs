// Optional live Firefox/Zen check; requires selenium-webdriver on NODE_PATH.
// Registers a distinct test-only native host, then restores/removes it in finally.
const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');
const {spawn} = require('node:child_process');
const {Builder}=require('selenium-webdriver'); const firefox=require('selenium-webdriver/firefox'); const os=require('node:os'); const manifests=[];
const repo = path.resolve(__dirname, '../..');
const firefoxPath=process.env.OMADECK_TEST_FIREFOX;
const geckodriverPath=process.env.OMADECK_TEST_GECKODRIVER;
if(!firefoxPath||!geckodriverPath)throw Error('Set OMADECK_TEST_FIREFOX and OMADECK_TEST_GECKODRIVER');
const lab = fs.mkdtempSync('/tmp/omadeck-watch-live-');
const testNativeName='pretty.omadeck.watch.test_'+process.pid;
const testAddonId=testNativeName+'@theairick';
const shellQuote=value=>"'"+value.replaceAll("'","'\"'\"'")+"'";
const runtime = path.join(lab,'runtime'); fs.mkdirSync(runtime,{mode:0o700});
const config = path.join(lab,'config'); fs.mkdirSync(config);
const extension = path.join(lab,'extension'); fs.mkdirSync(extension);
for(const f of ['background.js','content.js']) fs.copyFileSync(path.join(repo,'browser/watch-extension',f),path.join(extension,f));
fs.copyFileSync(path.join(repo,'browser/watch-extension/manifest.firefox.json'),path.join(extension,'manifest.json'));
for(const file of ['manifest.json','background.js']){const target=path.join(extension,file);fs.writeFileSync(target,fs.readFileSync(target,'utf8').replaceAll('pretty.omadeck.watch',testNativeName));}

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
  property string family: "firefox"
  // Keep the fixture attached to its browser while the native Qt player also
  // advertises MPRIS. Discovery and playerForKey still use real browser objects.
  property string sourceKey: watch.active && watch.source ? watch.source.sourceKey
    : nativeMedia.activePlayer ? nativeMedia.activePlayer.dbusName : "org.mpris.MediaPlayer2." + family + ".integration"
  Stores.MprisMediaAdapter { id: nativeMedia }
  QtObject { id: player; property bool isPlaying: true; property var metadata: ({}) }
  QtObject { id: sourceMedia; function playerForKey(key) { return nativeMedia.playerForKey(key) } }
  Stores.BrowserWatchBridge { id: bridge }
  Stores.WatchController { id: watch; pluginDir: "${lab}"; media: sourceMedia; browserBridge: bridge }
  function snapshot() { return { state:watch.state, notice:watch.notice, available:watch.hostAvailable,
    position:watch.videoPosition, pendingSeek:watch.pendingSeekPosition, duration:watch.videoDuration, playing:watch.videoPlaying, shuttingDown:watch.shuttingDown,
    sourcePaused:watch.sourcePausedByUs, sourceClosed:watch.sourceClosed, focused:watch.focused, candidate:bridge.candidateForPlayer(sourceKey),
    mprisPlayers:nativeMedia.players.map(p=>p.dbusName), connections:bridge.connections.length, pending:Object.keys(bridge.pendingRequests).length } }
  SocketServer {
    path: "${runtime}/control.sock"; active:true
    handler: Socket { id: client
      parser: SplitParser { splitMarker:"\\n"; onRead: line => {
        var m=JSON.parse(line); var ok=true
        if(m.op === "begin") ok=watch.begin(bridge.candidateForPlayer(root.sourceKey),{left:0,top:0,width:768,height:432})
        else if(m.op === "toggle") watch.togglePlayback()
        else if(m.op === "seek") watch.seekTo(m.seconds)
        else if(m.op === "skip") watch.seekBy(m.seconds)
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
let context, control, privateAudio; let counter=0; const replies=new Map();
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function waitFor(fn,label,ms=20000) {const end=Date.now()+ms;let v;while(Date.now()<end){v=await fn();if(v)return v;await delay(200)}throw Error('Timed out: '+label)}
function command(op,extra={}){return new Promise((resolve,reject)=>{const id=++counter;const timer=setTimeout(()=>{replies.delete(id);reject(Error('control timeout'))},5000);replies.set(id,r=>{clearTimeout(timer);resolve(r)});control.write(JSON.stringify({id,op,...extra})+'\n')})}
async function status(){return (await command('status')).data}
async function videoState(page){return page.evaluate(()=>{const v=document.querySelector('video');return v?{paused:v.paused,time:v.currentTime,ready:v.readyState,duration:v.duration,error:v.error?.code,muted:v.muted}:null})}
(async()=>{
  console.log('LAB '+lab);
  privateAudio=await require('./watch-private-audio.cjs')(lab,env);
  Object.assign(env,privateAudio.env);
  await waitFor(()=>fs.existsSync(path.join(runtime,'control.sock')),'QML control');
  control=net.createConnection(path.join(runtime,'control.sock'));let buffer='';
  control.on('data',d=>{buffer+=d;while(buffer.includes('\n')){const p=buffer.indexOf('\n');const m=JSON.parse(buffer.slice(0,p));buffer=buffer.slice(p+1);replies.get(m.id)?.(m);replies.delete(m.id)}});
  for(const base of ['.mozilla','.zen']) {
    const dir=path.join(os.homedir(),base,'native-messaging-hosts');fs.mkdirSync(dir,{recursive:true});
    const file=path.join(dir,testNativeName+'.json');const original=fs.existsSync(file)?fs.readFileSync(file):null;
    manifests.push({file,original});fs.writeFileSync(file,JSON.stringify({name:testNativeName,description:'Isolated OmaDeck test',path:path.join(lab,'relay'),type:'stdio',allowed_extensions:[testAddonId]}),{mode:0o600});
  }
  const options=new firefox.Options().setBinary(firefoxPath).addArguments('-headless','--no-remote');
  // Zeroing Gecko's volume suppresses MPRIS after navigation. The private null
  // sink keeps the browser genuinely audible internally without producing sound.
  options.setPreference('zen.welcome-screen.seen',true); options.setPreference('media.autoplay.default',0); options.setPreference('media.volume_scale','1.0');
  options.setPreference('browser.tabs.warnOnClose',false); options.setPreference('browser.warnOnQuit',false);
  const driver=await new Builder().forBrowser('firefox').setFirefoxOptions(options).setFirefoxService(new firefox.ServiceBuilder(geckodriverPath).setEnvironment(env).addArguments('--allow-system-access')).build();
  context={close:()=>driver.quit()};
  console.log('EXTENSION '+await driver.installAddon(extension,true)); await driver.setContext('chrome'); console.log('PERMISSIONS '+JSON.stringify(await driver.executeScript("const p=WebExtensionPolicy.getByID(arguments[0]); return {active:p.active, origins:p.allowedOrigins.patterns, url:p.getURL('')};",testAddonId))); await driver.setContext('content');
  const worker={evaluate:async()=>({native:'Firefox browser native messaging'})};
  const page={goto:url=>driver.get(url),evaluate:fn=>driver.executeScript('return ('+fn.toString()+')()')};
  await page.goto('https://www.youtube.com/watch?v=jNQXAC9IVRw',{waitUntil:'domcontentloaded',timeout:45000});
  await waitFor(async()=>{const v=await videoState(page);return v?.ready>=2?v:null},'YouTube source ready',45000);
  await page.evaluate(async()=>{const v=document.querySelector('video');v.muted=false;v.currentTime=2;await v.play()});
  console.log('SOURCE '+JSON.stringify(await videoState(page)));
  await waitFor(async()=>{const s=await status();return s.candidate?.sourceWasPlaying?s:null},'extension candidate').catch(async e=>{console.log('DEBUG '+JSON.stringify({deck:await status()}));await driver.setContext('chrome');console.log('GECKO_DEBUG '+JSON.stringify(await driver.executeScript("const e=ChromeUtils.importESModule('resource://gre/modules/ExtensionParent.sys.mjs').ExtensionParent.GlobalManager.getExtension(arguments[0]);return {views:[...e.views].map(v=>v.viewType),messages:Services.console.getMessageArray().filter(m=>String(m.sourceName||'').includes('moz-extension')).map(m=>({error:m.errorMessage,source:m.sourceName}))};",testAddonId)));await driver.setContext('content');throw e});
  await waitFor(async()=>(await status()).mprisPlayers.some(k=>/firefox|zen/i.test(k)),'real Zen MPRIS');
  console.log('CANDIDATE '+JSON.stringify(await status()));
  const sourceHandle=await driver.getWindowHandle();
  await driver.switchTo().newWindow('tab');
  await driver.get('about:blank');
  await delay(1200);
  console.log('BACKGROUND_CANDIDATE '+JSON.stringify(await status()));
  console.log('BEGIN '+JSON.stringify(await command('begin')));
  const playing=await waitFor(async()=>{const s=await status();if(s.notice)throw Error(s.notice);return s.state==='playing'?s:null},'handoff playing',22000);
  await driver.switchTo().window(sourceHandle);
  await waitFor(async()=>Math.abs((await status()).position-(await videoState(page)).time)<2,'aligned handoff'); console.log('HANDOFF '+JSON.stringify({deck:await status(),source:await videoState(page)}));
  await command('seek',{seconds:8});await waitFor(async()=>{const s=await status();return s.position>=7&&s.position<13?s:null},'host seek');
  await command('toggle');await waitFor(async()=>!(await status()).playing,'host pause');
  await command('toggle');await waitFor(async()=>(await status()).playing,'host play');
  const returnedAt=(await status()).position;console.log('RETURN_REQUEST '+JSON.stringify(await command('return')));
  await waitFor(async()=>(await status()).state==='idle','return').catch(async e=>{console.log('DEBUG_RETURN '+JSON.stringify({deck:await status(),source:await videoState(page),page:await page.evaluate(()=>({error:document.querySelector('.ytp-error')?.textContent,videos:[...document.querySelectorAll('video')].map(v=>({time:v.currentTime,ready:v.readyState,paused:v.paused,src:!!v.currentSrc}))})),extension:await worker.evaluate(()=>({lastCandidate,nativeConnected:!!nativePort}))}));throw e});
  const returned=await videoState(page);console.log('RETURN '+JSON.stringify({returnedAt,source:returned,deck:await status()}));
  if(returned.paused||Math.abs(returned.time-returnedAt)>3)throw Error('Return playback or position mismatch');
  await delay(3000)
  const settled=await videoState(page)
  console.log('RETURN_SETTLED '+JSON.stringify({returnedAt,source:settled}))
  if(settled.paused || settled.time < returnedAt - 1 || settled.time > returnedAt + 7)
    throw Error('Browser reset its position after Return')
  console.log('PASS Zen with actual MPRIS background-tab handoff, seek, pause/play, settled return');
  // Reproduce an ended Edge session whose source tab is closed while Zen stays open.
  await page.evaluate(async()=>{const v=document.querySelector('video');v.currentTime=2;await v.play()});
  await waitFor(async()=>{const c=(await status()).candidate;return c&&c.sourceWasPlaying&&c.seconds<5},'fresh source');
  await command('begin');
  await waitFor(async()=>(await status()).state==='playing','second handoff');
  await command('seek',{seconds:18});
  await waitFor(async()=>{const s=await status();return s.position>18&&!s.playing},'video ended');
  await driver.close();
  await driver.switchTo().window((await driver.getAllWindowHandles())[0]);
  await waitFor(async()=>(await status()).sourceClosed,'original tab closure');
  await page.goto('https://www.youtube.com/watch?v=jNQXAC9IVRw');
  await waitFor(async()=>{const v=await videoState(page);return v?.ready>=2},'new video ready',45000);
  await page.evaluate(async()=>{const v=document.querySelector('video');v.muted=false;v.currentTime=2;await v.play()});
  const beforeClose=await videoState(page);
  await command('return');
  await waitFor(async()=>(await status()).state==='idle','close orphaned Watch');
  const afterClose=await videoState(page);
  if(afterClose.paused||afterClose.time<beforeClose.time-0.1||afterClose.time>beforeClose.time+3)
    throw Error('Closing old Watch altered the new browser video');
  console.log('PASS ended video, original tab closed, new browser video untouched '+JSON.stringify({beforeClose,afterClose}));

  if(process.env.OMADECK_TEST_STRESS==='1') {
    // Adapt the shared integration scenarios to Selenium-owned windows only.
    const ownedPages=[];
    function wrap(handle) {
      const tab={
        async goto(url) {await driver.switchTo().window(handle);await driver.get(url)},
        async evaluate(fn,arg) {await driver.switchTo().window(handle);return driver.executeScript('return ('+fn.toString()+')(arguments[0])',arg===undefined?null:arg)},
        async bringToFront() {await driver.switchTo().window(handle)},
        async close() {await driver.switchTo().window(handle);await driver.close();ownedPages.splice(ownedPages.indexOf(tab),1);if(ownedPages.length)await ownedPages[0].bringToFront()},
      };
      ownedPages.push(tab);return tab;
    }
    const stressPage=wrap(await driver.getWindowHandle());
    context.pages=()=>ownedPages.slice();
    context.newPage=async()=>{await driver.switchTo().newWindow('tab');return wrap(await driver.getWindowHandle())};
    await require('./watch-stress-scenarios.cjs')({page:stressPage,context,command,status,waitFor,videoState,delay,runtime,lab});
  }

})().catch(e=>{console.error(e.stack);process.exitCode=1}).finally(async()=>{
  try {if(context)await context.close()}
  finally {
    for(const {file,original} of manifests){if(original===null)fs.unlinkSync(file);else fs.writeFileSync(file,original)}
    if(control)control.destroy();qs.kill('SIGTERM');
    if(privateAudio)await privateAudio.close();
    fs.closeSync(log);console.log('LOG '+path.join(lab,'quickshell.log'));
  }
});
