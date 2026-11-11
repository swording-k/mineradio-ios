const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
function fixture(opts = {}) {
  const posts = [], calls = [], intervals = [];
  function node() {
    const classes = new Set();
    return {style: {props: {}, setProperty(k, v, p) { this.props[k] = [v, p]; }, removeProperty(k) { delete this.props[k]; }},
      classList: {add: (...x) => x.forEach(c => classes.add(c)), remove: (...x) => x.forEach(c => classes.delete(c)),
        contains: c => classes.has(c), toggle(c, on) { on === undefined ? (classes.has(c) ? classes.delete(c) : classes.add(c)) : on ? classes.add(c) : classes.delete(c); }}};
  }
  const elements = {'heart-btn': node(), 'fx-fab': node()};
  const body = node(), root = node();
  const context = {
    window: {webkit: {messageHandlers: {appleNowPlaying: {postMessage: m => posts.push(JSON.parse(JSON.stringify(m)))}}},
      __mineradioAppleNativeControls: opts.phone !== false},
    document: {body, documentElement: root, head: {appendChild() {}}, createElement: () => ({}),
      getElementById: id => elements[id] || null, querySelector: () => opts.modal ? {} : null, addEventListener() {}},
    setInterval: (fn, ms) => { intervals.push(fn); return 1; }, setTimeout: fn => { fn(); return 1; },
    MutationObserver: class { constructor(fn) { context.observe = fn; } observe() {} },
    playQueue: [{name: '晴天', artist: '周杰伦', cover: 'http://p1.music.126.net/a.jpg', trial: false}], currentIdx: 0,
    playing: false, immersiveMode: false, controlsAutoHide: true,
    getPlaybackCurrentSeconds: () => 12.34, getPlaybackDurationSeconds: () => 269,
    togglePlay: () => { calls.push('toggle'); context.playing = !context.playing; },
    nextTrack: u => calls.push(['next', u]), prevTrack: u => calls.push(['prev', u]),
    commitProgressSeek: (t, resume) => calls.push(['seek', t, resume]),
    toggleLikeCurrent: () => calls.push('like'), toggleFxPanel: f => calls.push(['fx', f]),
    togglePlaylistPanel: f => calls.push(['pl', f])
  };
  vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-native-controls.js', 'utf8'), context);
  return {context, posts, calls, elements, body, root, tick() { intervals.forEach(fn => fn()); }};
}
test('pushes the original player state for the native bar and lock screen', () => {
  const f = fixture();
  const s = f.posts.at(-1).state;
  assert.equal(s.hasSong, true); assert.equal(s.title, '晴天'); assert.equal(s.artist, '周杰伦');
  assert.equal(s.cover, 'https://p1.music.126.net/a.jpg', 'http covers are upgraded so native ATS can load them');
  assert.equal(s.current, 12.3); assert.equal(s.duration, 269); assert.equal(s.playing, false);
  const count = f.posts.length; f.tick();
  assert.equal(f.posts.length, count, 'Unchanged state is not re-posted every tick');
});
test('native commands drive the unchanged original playback functions', () => {
  const f = fixture(); const cmd = f.context.window.__mineradioAppleCommand;
  cmd('toggle'); cmd('next'); cmd('prev'); cmd('seek', 90); cmd('like'); cmd('library');
  assert.deepEqual(f.calls, ['toggle', ['next', true], ['prev', true], ['seek', 90, true], 'like', ['fx', false], ['pl', true]]);
  cmd('play'); assert.equal(f.calls.filter(c => c === 'toggle').length, 1, 'play while playing is a no-op');
  cmd('pause'); assert.equal(f.context.playing, false);
  assert.equal(cmd('unknown'), false);
});
test('iPhone hides the web control bar, moves the DIY button above the native bar, and can show the full web bar', () => {
  const f = fixture();
  assert(f.body.classList.contains('apple-native-controls'));
  f.context.window.__mineradioAppleCommand('barHeight', 120);
  assert.deepEqual(f.elements['fx-fab'].style.props.bottom, ['calc(120px + 16px)', 'important']);
  f.context.window.__mineradioAppleCommand('webBar', true);
  assert(f.body.classList.contains('apple-native-web-bar'));
  assert.equal(f.posts.at(-1).state.webBar, true);
  f.body.classList.add('apple-controls-folded'); f.context.observe();
  assert.equal(f.posts.at(-1).state.webBar, false, 'Folding the web bar returns to the native bar');
});
test('iPad keeps the original control bar but still feeds the lock screen', () => {
  const f = fixture({phone: false});
  assert(!f.body.classList.contains('apple-native-controls'));
  assert.equal(f.posts.at(-1).state.title, '晴天');
});
test('folding native controls returns the reserved stage space and lowers the visual controls button', () => {
  const f = fixture(); const command = f.context.window.__mineradioAppleCommand;
  command('barHeight', 150);
  assert.equal(f.root.style.props['--apple-native-reserved'][0], '150px');
  command('barVisible', false);
  assert.equal(f.root.style.props['--apple-native-reserved'][0], '0px');
  assert.equal(f.elements['fx-fab'].style.props.bottom[0], 'calc(0px + 16px)');
  command('barVisible', true);
  assert.equal(f.root.style.props['--apple-native-reserved'][0], '150px');
});

test('visual guide suppresses native overlay and restores it after completion', () => {
  const f = fixture();
  f.body.classList.add('visual-guide-active'); f.tick();
  assert.equal(f.posts.at(-1).state.modal, true);
  f.body.classList.remove('visual-guide-active'); f.tick();
  assert.equal(f.posts.at(-1).state.modal, false);
});
