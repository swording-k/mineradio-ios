const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
function fixture() {
  let time = 10000;
  const calls = {trim: [], apply: 0};
  const context = {window: {}, performance: {now: () => time},
    renderQualityProfile: () => ({cap: 1.35, min: 0.72, budget: 5200000}),
    trimRuntimeCaches: (reason, aggressive) => { calls.trim.push([reason, aggressive]); return 0; },
    applyRendererPowerMode: () => { calls.apply++; },
    renderer: {getPixelRatio: () => context.renderQualityProfile().cap}};
  vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-memory.js', 'utf8'), context);
  return {context, calls, advance(ms) { time += ms; }};
}
test('memory warning lowers internal render resolution through the original budget and deep-trims caches', () => {
  const f = fixture();
  assert.equal(f.context.renderQualityProfile().cap, 1.35, 'No change before pressure');
  const after = f.context.window.__mineradioAppleMemoryPressure('warning');
  assert.equal(after.level, 1);
  assert(f.context.renderQualityProfile().cap < 1.35);
  assert(f.context.renderQualityProfile().budget < 5200000);
  assert.deepEqual(f.calls.trim[0], ['apple-memory-warning', true]);
  assert.equal(f.calls.apply, 1, 'Renderer must be resized immediately');
});
test('bursts of warnings are coalesced and the level is bounded', () => {
  const f = fixture();
  f.context.window.__mineradioAppleMemoryPressure('warning');
  f.context.window.__mineradioAppleMemoryPressure('warning');
  assert.equal(f.context.window.__mineradioAppleMemory.snapshot().level, 1);
  for (let i = 0; i < 10; i++) { f.advance(2000); f.context.window.__mineradioAppleMemoryPressure('warning'); }
  assert.equal(f.context.window.__mineradioAppleMemory.snapshot().level, 3);
  const p = f.context.renderQualityProfile();
  assert(p.min >= 0.5 && p.cap >= p.min, 'Resolution never drops below a readable floor');
});
test('restore after a WebContent restart reapplies the previous level once', () => {
  const f = fixture();
  assert.equal(f.context.window.__mineradioAppleMemoryPressure('restore', 2).level, 2);
  assert.equal(f.calls.trim.length, 1);
  assert.equal(f.context.window.__mineradioAppleMemoryPressure('restore', 1).level, 2, 'Restore never raises quality');
  assert.equal(f.calls.trim.length, 1);
});
