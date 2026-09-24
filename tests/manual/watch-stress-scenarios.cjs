// Extra real-network integration scenarios. Invoked by watch-chromium-e2e.cjs
// with OMADECK_TEST_STRESS=1. Every page/profile/player belongs to that fixture.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

module.exports = async function stress(t) {
  const {page,context,command,status,waitFor,videoState,delay,runtime,lab}=t;
  const first=process.env.OMADECK_TEST_PRIMARY_VIDEO||'jNQXAC9IVRw', second='aqz-KE-bpKQ';
  const results=[];
  let missingMediaRuns=0;
  const url=id=>'https://www.youtube.com/watch?v='+id;
  const hosts=()=>fs.readdirSync(runtime).filter(n=>/^omadeck-watch-[0-9]+-[0-9a-f]+\.sock$/.test(n))
    .filter(n=>{try {process.kill(Number(n.split('-')[2]),0);return true}catch{return false}});
  async function idle() {
    await waitFor(async()=>(await status()).state==='idle','idle');
    await waitFor(()=>hosts().length===0,'owned renderer cleanup');
    await waitFor(async()=>!(await status()).shuttingDown,'Watch here ready after renderer shutdown');
    assert.equal((await status()).pending,0,'pending browser requests');
  }
  async function load(p,id) {
    await p.goto(url(id),{waitUntil:'domcontentloaded',timeout:45000});
    await waitFor(async()=>(await videoState(p))?.ready>=2,'source '+id,45000);
    await p.evaluate(async()=>{const v=document.querySelector('video');v.muted=false;await v.play()});
    // A direct controller test must observe the same gate as Now Playing:
    // the browser has actually registered its MPRIS player, not just a DOM video.
    await waitFor(async()=>{const s=await status(),c=s.candidate;return c?.videoId===id&&c.sourceWasPlaying&&s.mprisPlayers.includes(c.sourceKey)},'candidate and MPRIS '+id);
    await p.evaluate(async()=>{const v=document.querySelector('video');v.currentTime=2;await v.play()});
  }
  async function reset(id=first) {
    await command('abort'); await idle();
    for(const other of context.pages())if(other!==page)await other.close();
    await page.bringToFront();await load(page,id);
  }
  async function begin() {
    assert.equal((await command('begin')).ok,true,'begin accepted');
    await waitFor(async()=>{const s=await status();if(s.notice)throw Error(s.notice);return s.state==='playing'},'playing',25000);
  }
  async function seek(n) {
    await command('seek',{seconds:n});
    await waitFor(async()=>Math.abs((await status()).position-n)<2,'seek '+n);
  }
  async function returned(p=page,playing=true) {
    const at=(await status()).position;
    await command('return');await idle();
    const value=await videoState(p);
    assert.equal(value.paused,!playing,'returned playback state');
    assert.ok(Math.abs(value.time-at)<3,`returned timestamp ${value.time} vs ${at}`);
    await delay(1200);
    const settled=await videoState(p);
    assert.ok(settled.time>=at-1 && settled.time<=at+5,'settled timestamp');
  }
  async function scenario(name,fn) {
    if(process.env.OMADECK_TEST_SCENARIO && !name.includes(process.env.OMADECK_TEST_SCENARIO))return;
    if(missingMediaRuns>=2) {
      results.push({name,passed:false,blocked:true,error:'Browser MPRIS prerequisite failed twice; scenario not exercised'});
      console.log('STRESS_BLOCKED '+name);
      fs.writeFileSync(path.join(lab,'stress-results.json'),JSON.stringify(results,null,2)+'\n');
      return;
    }
    const start=Date.now();
    try { await reset();await fn();results.push({name,passed:true,ms:Date.now()-start});console.log('STRESS_PASS '+name) }
    catch(e) {if(String(e.message).includes('candidate and MPRIS'))missingMediaRuns++;results.push({name,passed:false,error:String(e.message),ms:Date.now()-start,deck:await status().catch(()=>null)});console.log('STRESS_FAIL '+name+' '+e.message)}
    fs.writeFileSync(path.join(lab,'stress-results.json'),JSON.stringify(results,null,2)+'\n');
  }

  await scenario('five consecutive handoffs and settled timestamp returns',async()=>{
    const times=[];
    for(let i=0;i<5;i++){
      if(i)await load(page,first);
      const start=Date.now();await begin();times.push(Date.now()-start);
      await seek(7);await returned();
    }
    console.log('HANDOFF_TIMINGS_MS '+JSON.stringify(times));
  });
  await scenario('paused source returns paused at updated position',async()=>{
    await page.evaluate(()=>document.querySelector('video').pause());
    await waitFor(async()=>(await status()).candidate?.sourceWasPlaying===false,'paused candidate');
    await begin();await seek(8);await returned(page,false);
  });
  await scenario('ended video returns cleanly to the still-open original tab',async()=>{
    await begin();await seek(18);
    await waitFor(async()=>{const s=await status();return s.position>18&&!s.playing},'ended');
    await command('return');await idle();
    assert.ok((await videoState(page)).time>=18,'browser retains ended timestamp');
  });
  await scenario('double Watch and double Return do not create extra players',async()=>{
    assert.equal((await command('begin')).ok,true);
    assert.equal((await command('begin')).ok,false);
    await waitFor(async()=>(await status()).state==='playing','playing');
    assert.equal(hosts().length,1);await seek(7);
    await command('return');await command('return');await idle();
    assert.equal((await videoState(page)).paused,false);
  });
  await scenario('cancel immediately during launch leaves browser playing',async()=>{
    const before=await videoState(page);
    assert.equal((await command('begin')).ok,true);await command('abort');await idle();
    await delay(1500);const after=await videoState(page);
    assert.equal(after.paused,false);assert.ok(after.time>=before.time);
  });
  await scenario('rapid resize and focus cycles keep the same native player',async()=>{
    await begin();const host=hosts()[0];assert.ok(host);
    for(let i=0;i<30;i++){
      const focused=i%2===0;
      assert.equal((await command('focus',{focused,rect:{left:focused?409:5,top:5,width:782,height:440}})).ok,true);
      assert.equal((await command('geometry',{rect:{left:111,top:19,width:730,height:411}})).ok,true);
    }
    assert.deepEqual(hosts(),[host]);await seek(8);await returned();
  });
  await scenario('playing source tab closed; different second video stays untouched',async()=>{
    const source=await context.newPage();await load(source,first);await begin();await seek(8);
    await source.close();await waitFor(async()=>(await status()).sourceClosed,'source closed');
    await load(page,second);const before=await videoState(page);
    await command('return');await idle();const after=await videoState(page);
    assert.equal(after.paused,false);assert.ok(after.time>=before.time-.1&&after.time<before.time+3);
    await begin();await seek(12);await returned();
  });
  await scenario('source navigates to second video; old session closes safely',async()=>{
    await begin();await seek(8);await load(page,second);
    await waitFor(async()=>(await status()).sourceClosed,'navigated source');
    const before=await videoState(page);await command('return');await idle();const after=await videoState(page);
    assert.equal(after.paused,false);assert.ok(after.time>=before.time-.1&&after.time<before.time+3);
  });
  await scenario('Return targets original document while another video plays',async()=>{
    // Loading another real YouTube page can outlast the 19-second sample.
    // Use the long clip as the source so this measures tab ownership rather
    // than the site's end-of-video autoplay. Ended Return is tested separately.
    await load(page,second);
    await begin();await seek(8);
    const other=await context.newPage();await load(other,first);
    const before=await videoState(other);await returned();const after=await videoState(other);
    assert.equal(after.paused,false);assert.ok(after.time>=before.time&&after.time<before.time+6);
  });
  await scenario('Close preserves browser after its source page is reloaded',async()=>{
    await begin();await seek(8);await load(page,first);
    await waitFor(async()=>(await status()).sourceClosed,'reloaded source');
    const before=await videoState(page);await command('return');await idle();const after=await videoState(page);
    assert.equal(after.paused,false);assert.ok(after.time>=before.time-.1&&after.time<before.time+3);
  });
  await scenario('source closes during startup without stranding Watch',async()=>{
    // A distinct video proves the selected candidate belongs to the tab closed
    // below, rather than a same-video report left over from the reset tab.
    const source=await context.newPage();await load(source,second);
    await command('begin');await source.close();await idle();
    await load(page,first);await begin();await returned();
  });
  if(typeof context.setOffline==='function') {
    await scenario('offline source returns correctly when the timestamp is already buffered',async()=>{
      await begin();await seek(8);await context.setOffline(true);
      try {await returned()} finally {await context.setOffline(false)}
    });
    await scenario('offline source reload can close Watch and recover after reconnection',async()=>{
      await begin();await context.setOffline(true);
      try {
        await page.reload({waitUntil:'domcontentloaded',timeout:10000}).catch(()=>{});
        await waitFor(async()=>(await status()).sourceClosed,'offline source reload closes document');
        await command('return');await idle();
      } finally {await context.setOffline(false)}
      await load(page,first);await begin();await returned();
    });
  }
  await scenario('YouTube Home to watch-page history navigation injects candidate reporter',async()=>{
    await command('abort');await idle();
    await page.goto('https://www.youtube.com/',{waitUntil:'domcontentloaded',timeout:45000});
    await waitFor(()=>page.evaluate(()=>document.readyState==='complete'),'Home loaded');
    await delay(2000);
    // Same-document navigation, as used by YouTube links; no full reload.
    // A deterministic media element avoids recommendation/ad dependencies.
    await page.evaluate(id=>{
      history.pushState({},'', '/watch?v='+id);
      const v=document.querySelector('video')||document.body.appendChild(document.createElement('video'));
      v.currentTime=2;
      document.dispatchEvent(new Event('yt-navigate-finish'));
    },first);
    try {
      await waitFor(async()=>{const c=(await status()).candidate;return c?.videoId===first},'SPA candidate after Home',6000);
    } catch(error) {
      console.log('SPA_DEBUG '+JSON.stringify({
        page:await page.evaluate(()=>({url:location.href,visible:document.visibilityState,video:!!document.querySelector('video')})),
        deck:await status(),
        extension:t.worker?await t.worker.evaluate(()=>({lastCandidate,pages:[...pages.values()].map(p=>p.sender),connected:!!nativePort})):null,
      }));
      throw error;
    }
  });
  if(missingMediaRuns===0)await reset();
  else {await command('abort');await idle()}
  console.log('STRESS_RESULTS '+path.join(lab,'stress-results.json'));
  const failed=results.filter(r=>!r.passed);
  if(failed.length)process.exitCode=1;
};
