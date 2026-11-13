const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
function setup() {
  const calls=[];
  const elements={};
  const ctx={Date:{now:()=>0},window:{webkit:{messageHandlers:{appleMusic:{postMessage:async p=>{calls.push(p); return {ok:true};}}}}}, document:{querySelector:()=>null,getElementById:id=>elements[id]||null,createElement:()=>({setAttribute(){}})}, playQueue:[],currentIdx:-1,playing:false,trackSwitchToken:0,firstPlayDone:false,
    playQueueAt:async()=>{calls.push('original');return true;},togglePlay:()=>{},nextTrack:()=>{},prevTrack:()=>{},commitProgressSeek:()=>{}, getPlaybackCurrentSeconds:()=>1,getPlaybackDurationSeconds:()=>2,
    audio:{pause(){calls.push('pause-web');}},showToast:()=>{}, setTimeout:fn=>fn()};
  vm.createContext(ctx);vm.runInContext(fs.readFileSync('apps/apple/Web/apple-music.js','utf8'),ctx);
  return {ctx,calls};
}
test('native MusicKit state drives duration, time and existing queue without an HTML audio URL',()=>{
 const {ctx}=setup();ctx.window.__mineradioAppleMusicReceive({active:true,playing:true,current:22,duration:180,song:{id:'1',name:'Song',artist:'Artist',provider:'applemusic'}});
 assert.equal(ctx.playing,true);assert.equal(ctx.getPlaybackCurrentSeconds(),22);assert.equal(ctx.getPlaybackDurationSeconds(),180);assert.equal(ctx.playQueue[0].provider,'applemusic');
});
test('switching back to another source pauses native playback before invoking original player',async()=>{
 const {ctx,calls}=setup();ctx.window.__mineradioAppleMusicReceive({active:true,playing:true,current:0,duration:180,song:{id:'1',name:'S',provider:'applemusic'}});
 ctx.playQueue=[{id:'2',provider:'netease'}];await ctx.playQueueAt(0);
 assert.equal(calls[0].action,'stop');assert.equal(calls[1],'original');
});
test('preparing native playback pauses web audio and invalidates in-flight track resolution',()=>{
 const {ctx,calls}=setup();ctx.window.__mineradioAppleMusicPrepare();assert.deepEqual(calls,['pause-web']);assert.equal(ctx.trackSwitchToken,1);
});
test('pause toggle and seek use native MusicKit while Apple Music is active',async()=>{
 const {ctx,calls}=setup();ctx.window.__mineradioAppleMusicReceive({active:true,playing:true,current:0,duration:180,song:{id:'1',name:'S',provider:'applemusic'}});
 await ctx.togglePlay();await ctx.commitProgressSeek(45,true);
 assert.deepEqual(calls.map(c=>c.action),['toggle','seek']);assert.equal(calls[1].value,45);
});
test('failed native pause prevents the original source from starting',async()=>{
 const {ctx,calls}=setup();ctx.window.webkit.messageHandlers.appleMusic.postMessage=async()=>({ok:false,message:'Unavailable'});
 ctx.window.__mineradioAppleMusicReceive({active:true,playing:true,current:0,duration:180,song:{id:'1',name:'S',provider:'applemusic'}});
 ctx.playQueue=[{id:'2',provider:'netease'}];assert.equal(await ctx.playQueueAt(0),false);assert.equal(calls.includes('original'),false);
});
test('late artwork replaces the initially missing native artwork without losing the queue',()=>{
 const {ctx}=setup();ctx.playQueue=[{id:'1',provider:'applemusic'},{id:'2',provider:'applemusic'}];const covers=[];ctx.loadCoverFromUrl=u=>covers.push(u);
 ctx.window.__mineradioAppleMusicReceive({active:true,playing:true,current:0,duration:180,song:{id:'1',provider:'applemusic',cover:''}});
 ctx.window.__mineradioAppleMusicReceive({active:true,playing:true,current:0,duration:180,song:{id:'1',provider:'applemusic',cover:'https://is1-ssl.mzstatic.com/image/a.jpg'}});
 assert.equal(ctx.playQueue.length,2);assert.equal(covers.at(-1),'https://is1-ssl.mzstatic.com/image/a.jpg');
});
test('native time interpolates between snapshots and freezes when paused',()=>{
 const {ctx}=setup();ctx.window.__mineradioAppleMusicReceive({active:true,playing:true,current:22,duration:180,song:{id:'1',provider:'applemusic'}});
 ctx.Date.now=()=>500;assert.equal(ctx.getPlaybackCurrentSeconds(),22.5);
 ctx.window.__mineradioAppleMusicReceive({active:true,playing:false,current:22.5,duration:180,song:{id:'1',provider:'applemusic'}});
 ctx.Date.now=()=>1500;assert.equal(ctx.getPlaybackCurrentSeconds(),22.5);
});
test('first native playback uses the original stage fade-in and play icon',()=>{
 const {ctx}=setup(),calls=[];ctx.uniforms={uAlpha:{value:0}};ctx.tweenParticleAlpha=(a,b)=>calls.push([a,b]);ctx.setPlayIcon=p=>calls.push(p);
 ctx.window.__mineradioAppleMusicReceive({active:true,playing:true,current:0,duration:180,song:{id:'1',provider:'applemusic'}});
 assert(calls.some(v=>Array.isArray(v)&&v[0]===0&&v[1]===1));assert(calls.includes(true));
});
