const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function recover(snapshot, recovering = true) {
  const intervals = [], calls = [];
  const element = () => ({querySelectorAll: () => [], addEventListener() {}});
  const c = {
    window: {}, document: {getElementById: () => null, querySelectorAll: () => [],
      querySelector: () => null, createElement: element, head: {appendChild() {}},
      body: {classList: {contains: () => false}}},
    localStorage: {getItem: () => null}, history: {replaceState() {}},
    location: {search: recovering ? '?apple-recover=1' : '', pathname: '/'},
    setInterval(fn, ms) { intervals.push({fn, ms}); return intervals.length; }, clearInterval() {},
    setTimeout(fn) { fn(); }, clearTimeout() {},
    playing: false, startupAutoplayPreference: false, startupResumeModePreference: 'restart',
    restoredLastPlaybackSnapshot: snapshot, pendingPlaybackResumeAt: 0,
    readLastPlaybackSnapshot: () => snapshot,
    startupResumeSecondsFromSnapshot: s => c.startupResumeModePreference === 'resume' ? s.currentTime : 0,
    scheduleStartupAutoplayFromSnapshot: reason => calls.push(reason),
  };
  vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-mobile.js', 'utf8'), c);
  intervals.filter(x => x.ms === 250).forEach(x => x.fn());
  return {c, calls};
}
test('recovery keeps a paused snapshot paused', () => {
  const {c, calls} = recover({playing: false, currentTime: 73});
  assert.equal(c.startupAutoplayPreference, false);
  assert.deepEqual(calls, []);
});
test('recovery resumes a playing snapshot at its saved position even if startup already restored it', () => {
  const {c, calls} = recover({playing: true, currentTime: 73});
  assert.equal(c.pendingPlaybackResumeAt, 73);
  assert.equal(c.startupAutoplayPreference, true);
  assert.deepEqual(calls, ['apple-recover']);
});
test('missing recovery snapshot does not start unrelated music; ordinary launch keeps user preference', () => {
  assert.deepEqual(recover(null).calls, []);
  const {c, calls} = recover({playing: true, currentTime: 73}, false);
  assert.equal(c.startupAutoplayPreference, false);
  assert.deepEqual(calls, []);
});
