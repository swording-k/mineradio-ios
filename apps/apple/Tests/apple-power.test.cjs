const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
function fixture() {
  let time = 1000, layouts = 0, rafs = 0, serial = 0;
  const timers = new Map(), doc = new EventTarget(), win = new EventTarget();
  const toast = {textContent: '', classList: {remove(){}, add(){}}, get offsetWidth(){ layouts++; return 100; }};
  doc.getElementById = id => id === 'toast' ? toast : null;
  doc.hidden = false;
  const context = {window:win, document:doc, performance:{now:()=>time}, Date:{now:()=>time},
    setTimeout(fn,delay){const id=++serial;timers.set(id,{fn,delay});return id;},clearTimeout(id){timers.delete(id);},
    requestAnimationFrame(){rafs++;},animate(){},fx:{},playing:false,playToggleBusy:false,audio:{paused:true,ended:false},
    stageLyrics:{current:null,outgoing:[]},playbackResumeRecovery:{pending:false},albumGaplessState:{handoff:false},
    isDeepBackgroundMode:()=>context.deep, isMainSceneCoveredBySplash:()=>context.splash,
    isLiveBackgroundKeepMode:()=>false, isBackgroundReleaseMode:()=>false,
    mainLoopInteractionActive:()=>false,markRenderInteraction(){},
    playQueueAt:()=>new Promise(resolve=>{context.finishLoad=resolve;}),
    togglePlay:()=>Promise.resolve(true),splash:false,deep:false};
  context.getAdaptiveRenderFps=()=>context.baseFps||0;
  context.resolveAdaptiveRenderCadence=()=>context.cadence||null;
  const original = fs.readFileSync('public/js/modules/11-main-loop.js','utf8');
  vm.runInNewContext(original.slice(original.indexOf('var mainLoopBackgroundTimer ='),original.indexOf('function tickDeepBackgroundFrame(')),context);
  const toastSource=fs.readFileSync('public/js/modules/09-idle-toast-libraries.js','utf8');
  vm.runInNewContext(toastSource.slice(toastSource.indexOf('var toastTimer ='),toastSource.indexOf('var visualGuideSteps =')),context);
  const path='apps/apple/Web/apple-power.js';
  if(fs.existsSync(path))vm.runInNewContext(fs.readFileSync(path,'utf8'),context);
  return {context,doc,win,timers,toast, advance(ms){time+=ms;},get layouts(){return layouts;},get rafs(){return rafs;}};
}
test('repeated identical errors avoid repeated forced layout; new messages and later retry remain visible',()=>{
  const f=fixture();
  for(let i=0;i<100;i++){f.context.showToast('暂时不可播放');f.advance(1);}
  assert.equal(f.layouts,1,'Identical errors must not force layout 100 times');
  f.context.showToast('已暂停');assert.equal(f.layouts,2);
  f.advance(900);f.context.showToast('暂时不可播放');assert.equal(f.layouts,3);
});
test('quiet paused stage uses a timer and wakes immediately on input, without changing background policy',()=>{
  const f=fixture();
  assert.equal(f.context.mainLoopBackgroundDelayMs(),0);
  f.advance(3100);
  assert.equal(f.context.mainLoopBackgroundDelayMs(),500,'Idle must reduce actual wakeups, not merely skip work after rAF');
  f.context.scheduleNextMainLoopFrame();
  assert.equal(f.rafs,0);assert([...f.timers.values()].some(t=>t.delay===500));
  f.doc.dispatchEvent(new Event('pointerdown'));
  assert.equal(f.rafs,1);assert.equal(f.context.mainLoopBackgroundDelayMs(),0);
  f.advance(4000);f.context.deep=true;
  assert.equal(f.context.mainLoopBackgroundDelayMs(),1000);
});
test('playing, loading after toggle resets, splash, fades and recovery remain awake',async()=>{
  const f=fixture();f.advance(3100);assert.equal(f.context.mainLoopBackgroundDelayMs(),500);
  f.context.playing=true;assert.equal(f.context.mainLoopBackgroundDelayMs(),0);
  f.context.playing=false;f.context.splash=true;f.advance(4000);assert.equal(f.context.mainLoopBackgroundDelayMs(),0);
  f.context.splash=false;
  const load=f.context.playQueueAt(0);f.context.playToggleBusy=false;f.advance(4000);
  assert.equal(f.context.mainLoopBackgroundDelayMs(),0,'Pending URL must stay awake even when original switch code clears busy');
  f.context.finishLoad(true);await load;
  f.context.stageLyrics.current={userData:{lyric:{globalOpacity:0.2}}};
  f.advance(4000);assert.equal(f.context.mainLoopBackgroundDelayMs(),0);
  f.context.stageLyrics.current.userData.lyric.globalOpacity=0;
  assert.equal(f.context.mainLoopBackgroundDelayMs(),0);f.advance(3100);assert.equal(f.context.mainLoopBackgroundDelayMs(),500);
  f.context.playbackResumeRecovery.pending=true;assert.equal(f.context.mainLoopBackgroundDelayMs(),0);
});
test('failed loading does not poison idle accounting; markRenderInteraction also interrupts the timer',async()=>{
  const f=fixture();const pending=f.context.playQueueAt(0);f.context.finishLoad(false);await pending;
  f.advance(3100);assert.equal(f.context.mainLoopBackgroundDelayMs(),500);
  f.context.scheduleNextMainLoopFrame();f.context.markRenderInteraction('camera',800);
  assert.equal(f.context.mainLoopBackgroundDelayMs(),0);assert.equal(f.rafs,1);
});
test('scrolling DOM panels bounds 3D work without reducing canvas gestures or leaving a sticky cap',()=>{
  const f=fixture();f.context.playing=true;
  f.context.cadence={fps:45,divisor:3};
  f.doc.dispatchEvent(new Event('scroll'));
  assert.equal(f.context.getAdaptiveRenderFps(),20);
  assert.equal(f.context.resolveAdaptiveRenderCadence(),null,'A cadence shortcut must not bypass the temporary budget');
  f.context.baseFps=15;assert.equal(f.context.getAdaptiveRenderFps(),15);
  f.advance(181);f.context.baseFps=0;
  assert.equal(f.context.getAdaptiveRenderFps(),0);assert.equal(f.context.resolveAdaptiveRenderCadence().fps,45);
  // A wheel generated by the native pinch bridge belongs to the stage, not a list.
  const event=new Event('wheel');Object.defineProperty(event,'target',{value:{closest:()=>({})}});
  f.doc.dispatchEvent(event);assert.equal(f.context.getAdaptiveRenderFps(),0);
});
