const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
function fixture(extra = {}) {
  class Target extends EventTarget { constructor() { super(); this.style = {}; } setPointerCapture() {} }
  class Mouse extends Event { constructor(type, options) { super(type, options); Object.assign(this, {clientX: options.clientX, clientY: options.clientY, button: options.button}); } }
  const canvas = new Target(), window = new Target();
  const splash = {classList: {contains: () => false}};
  let observer;
  const styles = [];
  const zone = {setAttribute() {}};
  const calls = [];
  const context = {window, renderer: {domElement: canvas}, document: {addEventListener: window.addEventListener.bind(window), getElementById: id => id === 'splash' ? splash : zone, readyState: 'complete', body: {classList: {add() {}}}, head: {appendChild: el => styles.push(el.textContent)}, createElement: () => ({})},
    MouseEvent: Mouse, MutationObserver: class {constructor(fn) {observer = fn;} observe() {} disconnect() {}},
    splashAnimating: true, splashCanvas: {width: 1000, height: 1000},
    splashGl: {deleteBuffer: () => calls.push('buffer'), deleteProgram: () => calls.push('program'), getExtension: () => ({loseContext: () => calls.push('context')})},
    splashGlBuffer: {}, splashGlProgram: {}, splashGlUniforms: {}, splashCtx: {}, splashDust: [1], splashStreaks: [1], splashShards: [1]};
  Object.assign(context, extra);
  vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-runtime.js', 'utf8'), context);
  function pointer(type, id = 1, kind = 'touch', x = 12, y = 30) {const e = new Event(type, {cancelable: true}); Object.assign(e, {pointerId: id, pointerType: kind, isPrimary: true, clientX: x, clientY: y}); canvas.dispatchEvent(e); return e;}
  return {context, canvas, window, splash, calls, pointer, styles, observe: () => observer()};
}
test('touch drag reaches original mouse handlers; cancel releases drag without ripple', () => {
  const f = fixture(), seen = [];
  f.canvas.addEventListener('mousedown', () => seen.push('down'));
  f.window.addEventListener('mousemove', () => seen.push('move'));
  f.window.addEventListener('mouseup', () => seen.push('up'));
  assert(f.pointer('pointerdown').defaultPrevented);
  f.pointer('pointermove', 2); // unrelated second finger
  f.pointer('pointermove'); f.pointer('pointerup');
  assert.deepEqual(seen, ['down', 'move', 'up']);
  f.pointer('pointerdown', 3, 'mouse');
  assert.equal(seen.length, 3);
  assert.equal(f.canvas.style.touchAction, 'none');
  f.context.orbit = {rotating: true};
  f.pointer('pointerdown'); f.pointer('pointercancel');
  assert.equal(f.context.orbit.rotating, false);
  assert.deepEqual(seen, ['down', 'move', 'up', 'down']);
});
test('splash graphics released only after exit; repeated observer calls are harmless', () => {
  const f = fixture();
  f.observe(); assert.equal(f.calls.length, 0);
  f.splash.classList.contains = name => name === 'hide'; f.observe(); f.observe();
  assert.deepEqual(f.calls, ['buffer', 'program', 'context']);
  assert.equal(f.context.splashAnimating, false);
  assert.equal(f.context.splashCanvas.width, 1);
  assert.equal(f.context.splashGl, null);
  assert.equal(f.context.splashDust.length, 0);
});

test('Apple DIY entry is visible without desktop titlebar or mouse hover', () => {
  const f = fixture();
  assert(f.styles.join('').includes('#fullscreen-diy-btn'));
  assert(f.styles.join('').includes('pointer-events: auto'));
  assert(f.styles.join('').includes('env(safe-area-inset-right)'));
});

test('Apple bounds lyric residency across long playback and keeps translated visible rows', () => {
  const disposed = [];
  const f = fixture({
    lyricsLines: Array(1000).fill('lyric'), fx: {},
    lyricDisplayOffsetsForMode: () => [-2, 0, 2],
    stageLyricPersistentNextTextRunwayRange: () => ({start: 0, end: 999}),
    trimStageLyricPersistentTrackRows: () => false,
    disposeStageLyricResidentRow: row => disposed.push(row.lineIndex),
    updateStageLyricPersistentResidentBounds: data => {data.updated = true;},
    lyricQualityPoolBudgetBytes: () => 192 * 1024 * 1024,
  });
  const rows = Array.from({length: 1000}, (_, lineIndex) => ({lineIndex, isPrimary: true}));
  rows.push({lineIndex: 999, parentIndex: 50, isTranslation: true});
  const data = {trackPersistent: true, rowLayers: rows};
  f.context.trimStageLyricPersistentTrackRows({userData: {lyric: data}}, 50);
  assert(data.rowLayers.length <= 42);
  assert(data.rowLayers.some(row => row.isTranslation));
  assert(data.rowLayers.some(row => row.lineIndex === 48));
  assert(data.rowLayers.some(row => row.lineIndex === 52));
  assert(disposed.length > 900);
  assert.equal(f.context.stageLyricPersistentNextTextRunwayRange(data, 50), null);
  assert(f.context.lyricQualityPoolBudgetBytes(4) <= 24 * 1024 * 1024);
});
test('Apple controls use original account anchor and leave room above playback controls', () => {
  const css = fixture().styles.join('');
  assert(css.includes('var(--fullscreen-diy-top'));
  assert(css.includes('body.apple-client.diy-mode.controls-visible #fx-fab'));
});

test('a stationary finger tap sends one canvas click; drag and cancel never select', () => {
  const f = fixture(), clicks = [];
  f.canvas.addEventListener('click', event => clicks.push([event.clientX, event.clientY]));
  f.pointer('pointerdown'); f.pointer('pointerup');
  assert.deepEqual(clicks, [[12, 30]]);
  f.pointer('pointerdown'); f.pointer('pointermove', 1, 'touch', 65, 30); f.pointer('pointerup', 1, 'touch', 65, 30);
  f.pointer('pointerdown'); f.pointer('pointercancel');
  assert.equal(clicks.length, 1);
});
test('Apple skips whole-track offline PCM analysis instead of allocating four song-length bands', async () => {
  let decoded = 0;
  const f = fixture({analyzeAudioBeats: async () => { decoded++; }, analyzePodcastDjBeats: async () => { decoded++; }});
  assert.equal(await f.context.analyzeAudioBeats('fixture', 200, 1), null);
  assert.equal(await f.context.analyzePodcastDjBeats('fixture', 1, 200), null);
  assert.equal(decoded, 0);
});
test('audio playback activates native session before play and resumes interrupted analysis', async () => {
  const calls = [];
  class Media { play() { calls.push('play'); return Promise.resolve(); } }
  const f = fixture({HTMLMediaElement: Media, audioCtx: {state: 'interrupted', resume: () => { calls.push('resume'); return Promise.resolve(); }}});
  f.window.webkit = {messageHandlers: {appleAudioActivate: {postMessage: async () => {calls.push('native'); return {active:true};}}}};
  const media = new Media(); media.tagName = 'AUDIO';
  await media.play();
  assert.deepEqual(calls, ['native', 'resume', 'play']);
});

test('3D picking uses CSS canvas bounds rather than screen or retina pixels', () => {
  const samples = [];
  class Ray { setFromCamera(vector) { samples.push([vector.x, vector.y]); } }
  class Vector { constructor(x,y) {this.x=x;this.y=y;} }
  const f = fixture({THREE: {Raycaster: Ray, Vector2: Vector}, camera: {}, raycasterFromPointerEvent: () => null});
  f.canvas.getBoundingClientRect = () => ({left:20,top:40,width:300,height:500});
  f.context.raycasterFromPointerEvent({clientX:170,clientY:290});
  assert.deepEqual(samples, [[0,0]]);
});
test('WebKit audio session explicitly uses playback rather than ambient sound', () => {
  const navigator = {audioSession: {type: 'auto'}};
  fixture({navigator});
  assert.equal(navigator.audioSession.type, 'playback');
});

test('first gesture primes AudioContext before any song/audio element exists', async () => {
  let started = 0;
  class Context { constructor() { this.state='suspended'; } resume() { started++; this.state='running'; return Promise.resolve(); } }
  const f = fixture({audio: null, audioCtx: null, initAudio: () => false});
  f.window.AudioContext = Context;
  f.window.dispatchEvent(new Event('pointerdown'));
  assert(f.context.audioCtx instanceof Context);
  assert.equal(started,1);
});
