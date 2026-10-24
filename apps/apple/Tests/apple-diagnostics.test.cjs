const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
function fixture(late = false) {
  const posts = [], timers = [], audio = new EventTarget(), doc = new EventTarget();
  Object.assign(audio, {currentTime: 40, duration: 200, paused: false, ended: false, seeking: false, readyState: 4, networkState: 1});
  Object.defineProperty(audio, 'currentSrc', {get() { throw new Error('Audio URL must never be read'); }});
  doc.hidden = false;
  const window = {webkit: {messageHandlers: {appleDiagnostics: {postMessage: async value => posts.push(value)}}},
    __mineradioPerf: {fps: 30, targetFps: 30, adaptiveFrameCostMs: 12, adaptivePressure: 1}};
  const context = {window, document: doc, audio: late ? null : audio, renderer: {info: {memory: {textures: 12, geometries: 3}, programs: [1,2]}, domElement: {width: 800, height: 600}, getPixelRatio: () => 1.5},
    Date, WeakSet, Number, setInterval: (fn, delay) => {timers.push({fn,delay}); return 1;}};
  const path = 'apps/apple/Web/apple-diagnostics.js';
  vm.runInNewContext(fs.existsSync(path) ? fs.readFileSync(path,'utf8') : '', context);
  return {posts, timers, audio, doc, context};
}
test('Apple diagnostic sampling reuses original counters without content or render changes', () => {
  const f = fixture();
  assert(f.posts.some(p => p.event === 'sample'), 'Local diagnostic collector must record render and media state');
  assert.equal(f.timers[0].delay, 10000);
  const record = f.posts.find(p => p.event === 'sample');
  assert.equal(record.metrics.textures, 12); assert.equal(record.metrics.fps, 30); assert.equal(record.metrics.mediaTime, 40);
  assert(!JSON.stringify(f.posts).includes('http')); assert.equal(f.context.audio, f.audio);
  f.doc.hidden = true; const count = f.posts.length; f.timers[0].fn(); assert.equal(f.posts.length, count);
});
test('backward media movement is recorded with seek context, never restarts playback', () => {
  const f = fixture();
  f.audio.currentTime = 1; f.audio.dispatchEvent(new Event('timeupdate'));
  assert(f.posts.some(p => p.event === 'media-time-regressed'));
  assert.equal(f.audio.currentTime, 1); assert.equal(f.audio.paused, false);
  f.audio.dispatchEvent(new Event('seeking'));
  f.audio.dispatchEvent(new Event('seeked'));
  assert(f.posts.some(p => p.event === 'media-seeked' && p.metrics.recentSeek === 1));
});
test('late-created audio is observed once and delayed native replies cannot stack', async () => {
  const f = fixture(true);
  assert.equal(f.posts[0].metrics.mediaTime, undefined);
  f.context.audio = f.audio;
  let events = 0;
  f.audio.addEventListener('play', () => events++);
  f.timers[0].fn(); f.timers[0].fn();
  f.audio.dispatchEvent(new Event('play')); assert.equal(events, 1);
  assert.equal(f.posts.filter(p => p.event === 'media-play').length, 1);
  for (let i = 0; i < 20; i++) f.timers[0].fn();
  assert(f.posts.length <= 4);
  await new Promise(resolve => setImmediate(resolve));
  f.timers[0].fn(); assert.equal(f.posts.length, 5);
});
