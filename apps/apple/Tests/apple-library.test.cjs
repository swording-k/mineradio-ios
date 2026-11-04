const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
function fixture(trial = true) {
  const store = new Map(), calls = [];
  const context = {
    window: {}, document: {head: {appendChild() {}}, createElement: () => ({}), addEventListener() {}, getElementById: () => null},
    localStorage: {getItem: k => store.get(k) ?? null, setItem: (k, v) => store.set(k, v)},
    crypto: {getRandomValues: a => { a.forEach((_, i) => { a[i] = i + 1; }); return a; }},
    URLSearchParams, trackSwitchToken: 7, currentIdx: 0,
    playQueue: [{provider: 'qishui', id: 'q1', name: 'S', artist: 'A'}],
    apiJson: async url => url.startsWith('/api/qishui/song/url?') ? {url: 'https://x.douyinvod.com/a.m4a', trial, duration: 30} : {},
    skipFailedQueueItem: async () => { calls.push('skip'); return false; },
    settleSourceFallbackTerminal: () => { calls.push('settle'); return false; },
    handlePlaybackUnavailable: () => calls.push('unavailable'),
    playQueueAt: async (idx, opts) => { calls.push(['play', idx, opts.preResolvedPlaybackData && opts.preResolvedPlaybackData.url, opts.fallbackDepth]); return true; }
  };
  context.window.crypto = context.crypto;
  vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-library.js', 'utf8'), context);
  return {context, calls, store};
}
test('qishui trial remains directly playable instead of forcing a failing cross-platform lookup', async () => {
  const f = fixture();
  const data = await f.context.apiJson('/api/qishui/song/url?id=q1&quality=x');
  assert.equal(data.url, 'https://x.douyinvod.com/a.m4a');
  assert.equal(data.trial, true);
  assert.equal(data.reason, undefined);
});
test('full qishui playback and other providers are untouched', async () => {
  const f = fixture(false);
  assert.equal((await f.context.apiJson('/api/qishui/song/url?id=q1')).url, 'https://x.douyinvod.com/a.m4a');
});
test('built-in playlists work on iOS with the desktop contract and persist', async () => {
  const f = fixture(); const host = f.context.window.desktopWindow;
  assert.equal(host.isDesktop, false, 'Must not make the app look like the Electron desktop');
  const created = await host.createBuiltInPlaylist('跑步');
  assert.equal(created.ok, true); const id = created.playlist.id;
  assert.equal((await host.addBuiltInPlaylistTrack(id, {provider: 'netease', id: 1, name: '晴天', artist: '周杰伦'})).added, true);
  assert.equal((await host.addBuiltInPlaylistTrack(id, {provider: 'netease', id: 1, name: '晴天'})).duplicate, true);
  assert.equal((await host.addBuiltInPlaylistTrack(id, {provider: 'spotify', spotifyId: 'x'})).ok, false);
  const page = await host.readBuiltInPlaylist(id, {});
  assert.equal(page.total, 1); assert.equal(page.tracks[0].name, '晴天');
  assert(f.store.get('mineradio-apple-built-in-playlists-v1').includes('晴天'));
  assert.equal((await host.removeBuiltInPlaylistTrack(id, 0)).ok, true);
  assert.equal((await host.deleteBuiltInPlaylist(id)).count, 0);
});
