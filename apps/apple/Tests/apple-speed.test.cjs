const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
function fixture(saved) {
  const nodes = {}, storage = new Map(saved === undefined ? [] : [['mineradio-apple-speed-v1', saved]]);
  function node() { return {children:[],listeners:{},style:{},setAttribute(k,v){this[k]=v;},appendChild(n){this.children.push(n);if(n.id)nodes[n.id]=n;},addEventListener(k,f){this.listeners[k]=f;}}; }
  class Media { constructor(){this.playbackRate=1;this.preservesPitch=false;this.plays=0;} play(){this.plays++;return Promise.resolve();} }
  const popover=node(), head=node();
  const ctx={window:{},document:{querySelector:()=>popover,createElement:node,head},localStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v)},
    HTMLMediaElement:Media,audio:new Media(),cuefieldAutoMixEnabled:false,
    replaceAudioElementForGraphRecovery(){ctx.audio=new Media();return true;},initAudio(){return true;},bindPlaybackProgressEvents(){},startAlbumGaplessMix(){return true;}};
  if(fs.existsSync('apps/apple/Web/apple-speed.js'))vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-speed.js','utf8'),ctx);
  return {ctx,nodes,storage,Media};
}
test('speed changes the main player with pitch preserved and survives a recovered audio element',async()=>{
  const f=fixture();assert(f.nodes['apple-speed-slider'],'Speed must be reachable inside the original volume popup');
  f.nodes['apple-speed-slider'].value='1.5';f.nodes['apple-speed-slider'].listeners.input();
  assert.equal(f.ctx.audio.playbackRate,1.5);assert.equal(f.ctx.audio.preservesPitch,true);
  assert.equal(f.storage.get('mineradio-apple-speed-v1'),'1.5');
  f.ctx.replaceAudioElementForGraphRecovery();assert.equal(f.ctx.audio.playbackRate,1.5);
  f.ctx.audio.playbackRate=1;await f.ctx.audio.play();assert.equal(f.ctx.audio.playbackRate,1.5);assert.equal(f.ctx.audio.plays,1);
  assert.equal(f.nodes['apple-speed-slider']['aria-valuetext'],'1.5 倍');
  f.nodes['apple-speed-reset'].listeners.click();assert.equal(f.ctx.audio.playbackRate,1);
});
test('gapless pre-roll and adopted media keep the chosen speed instead of silently returning to 1x',()=>{
  const f=fixture('1.5'), next=new f.Media();
  f.ctx.startAlbumGaplessMix({media:next});assert.equal(next.playbackRate,1.5);
  f.ctx.audio=new f.Media();f.ctx.bindPlaybackProgressEvents(f.ctx.audio);assert.equal(f.ctx.audio.playbackRate,1.5);
});
test('invalid preferences reset, speed bounds hold, and non-player media / AutoMix tempo remain owned by their engine',async()=>{
  const f=fixture('bad');assert(f.nodes['apple-speed-slider']);assert.equal(f.ctx.audio.playbackRate,1);
  f.nodes['apple-speed-slider'].value='100';f.nodes['apple-speed-slider'].listeners.input();assert.equal(f.ctx.audio.playbackRate,3);
  f.nodes['apple-speed-slider'].value='0.1';f.nodes['apple-speed-slider'].listeners.input();assert.equal(f.ctx.audio.playbackRate,0.5);
  const unrelated=new f.Media();unrelated.playbackRate=0.97;await unrelated.play();assert.equal(unrelated.playbackRate,0.97);
  // AutoMix decks must retain their timing until the engine releases ownership.
  f.ctx.cuefieldAutoMixEnabled=true;f.ctx.audio.playbackRate=1.03;
  await f.ctx.audio.play();assert.equal(f.ctx.audio.playbackRate,1.03);
  f.ctx.cuefieldAutoMixEnabled=false;await f.ctx.audio.play();assert.equal(f.ctx.audio.playbackRate,0.5);
});
