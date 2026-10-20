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
  const context = {window, renderer: {domElement: canvas}, document: {getElementById: id => id === 'splash' ? splash : zone, readyState: 'complete', body: {classList: {add() {}}}, head: {appendChild: el => styles.push(el.textContent)}, createElement: () => ({})},
    MouseEvent: Mouse, MutationObserver: class {constructor(fn) {observer = fn;} observe() {} disconnect() {}},
    splashAnimating: true, splashCanvas: {width: 1000, height: 1000},
    splashGl: {deleteBuffer: () => calls.push('buffer'), deleteProgram: () => calls.push('program'), getExtension: () => ({loseContext: () => calls.push('context')})},
    splashGlBuffer: {}, splashGlProgram: {}, splashGlUniforms: {}, splashCtx: {}, splashDust: [1], splashStreaks: [1], splashShards: [1]};
  Object.assign(context, extra);
  vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-runtime.js', 'utf8'), context);
  function pointer(type, id = 1, kind = 'touch') {const e = new Event(type, {cancelable: true}); Object.assign(e, {pointerId: id, pointerType: kind, isPrimary: true, clientX: 12, clientY: 30}); canvas.dispatchEvent(e); return e;}
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
