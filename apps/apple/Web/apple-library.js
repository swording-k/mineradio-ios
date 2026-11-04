// 移动端功能补齐（与桌面同源的前端逻辑，只补 iOS 缺失的宿主能力）：
// 1) 自建（内置）歌单：桌面由 Electron 主进程 built-in-playlist-library.js 存盘；iOS 用本机存储实现同一接口。
// 2) 保留汽水的可用试听音源，不强制跨平台换源。
// 3) iPad 与 iPhone 一样显示「歌单」入口（触屏没有桌面左边缘悬停）；触屏隐藏键盘热键设置。
(function installAppleLibrary() {
  if (window.__mineradioAppleLibrary) return;
  window.__mineradioAppleLibrary = true;

  // ---------- 1) 自建歌单（接口与 desktop/built-in-playlist-library.js 一致） ----------
  var KEY = 'mineradio-apple-built-in-playlists-v1', MAX_PLAYLISTS = 100, MAX_TRACKS = 3000;
  var FIELDS = ['provider','source','type','id','providerSongId','trackId','mid','songmid','mediaMid','media_mid','qqId','hash','fileHash',
    'audioHash','albumId','album_id','albumMid','albumAudioId','album_audio_id','mixSongId','hqHash','sqHash','resHash','name','title',
    'artist','album','cover','duration','durationMs','dt','fee','playable','playbackMode','vipRequired','needVip','onlyVipPlayable','privilege'];
  function text(v, fallback, max) { var s = String(v == null ? '' : v).replace(/\0/g, '').trim(); return (s || String(fallback || '')).slice(0, max || 1000); }
  function providerOf(t) {
    var s = text(t && (t.provider || t.source || t.type), '', 32).toLowerCase();
    if (s === 'spotify' || (t && (t.spotifyId || t.spotifyUri))) return '';
    if (s === 'local' || (t && (t.localFileId || t.localKey))) return '';
    if (s === 'qq') return 'qq';
    if (s === 'kugou' || (t && (t.hash || t.fileHash))) return 'kugou';
    if (s === 'qishui') return 'qishui';
    return 'netease';
  }
  function identity(t) {
    var p = providerOf(t), v = p === 'qq' ? (t.mid || t.songmid || t.id) : p === 'kugou' ? String(t.hash || t.fileHash || t.id || '').toLowerCase() : (t.id || t.providerSongId);
    v = text(v, '', 512); return p && v ? p + ':' + v : '';
  }
  function clean(source) {
    if (!source || typeof source !== 'object') return null;
    var p = providerOf(source); if (!p) return null;
    var t = {};
    FIELDS.forEach(function (k) { var v = source[k]; if (v == null || v === '' || typeof v === 'object') return; t[k] = typeof v === 'string' ? v.slice(0, 2048) : v; });
    t.provider = t.source = p; if (!t.type) t.type = p === 'qq' ? 'qq' : 'song';
    t.name = text(t.name || t.title, '未知歌曲'); t.title = t.title || t.name; t.artist = text(t.artist, '未知歌手');
    t.builtInIdentity = identity(t);
    return t.builtInIdentity ? t : null;
  }
  function load() {
    try { var d = JSON.parse(localStorage.getItem(KEY) || 'null'); return d && Array.isArray(d.playlists) ? d.playlists : []; } catch (_) { return []; }
  }
  var playlists = load();
  function save() {
    try { localStorage.setItem(KEY, JSON.stringify({version: 1, updatedAt: Date.now(), playlists: playlists})); return true; }
    catch (_) { return false; }
  }
  function summary(pl) {
    var first = pl.tracks[0] || {};
    return {id: pl.id, provider: 'mineradio', source: 'mineradio', builtin: true, name: pl.name, creator: 'Mineradio',
      trackCount: pl.tracks.length, cover: first.cover || '', createdAt: pl.createdAt, updatedAt: pl.updatedAt, shelfPane: 'mine', subscribed: false};
  }
  function list(extra) { return Object.assign({ok: true, version: 1, count: playlists.length, playlists: playlists.map(summary)}, extra || {}); }
  function find(id) { id = text(id, '', 64).toLowerCase(); return playlists.filter(function (p) { return p.id === id; })[0]; }
  function fail(code) { return {ok: false, error: code}; }
  function commit(extra) { return save() ? list(extra) : fail('BUILT_IN_PLAYLIST_INDEX_TOO_LARGE'); }
  function newId() { var a = new Uint8Array(12); (window.crypto || {}).getRandomValues ? crypto.getRandomValues(a) : a.forEach(function (_, i) { a[i] = Math.random() * 256; }); return Array.prototype.map.call(a, function (b) { return ('0' + b.toString(16)).slice(-2); }).join(''); }
  var api = {
    listBuiltInPlaylists: function () { return Promise.resolve(list()); },
    readBuiltInPlaylist: function (id, o) {
      var pl = find(id); if (!pl) return Promise.resolve({ok: false, error: 'BUILT_IN_PLAYLIST_NOT_FOUND', playlist: null, tracks: [], total: 0, nextOffset: 0, hasMore: false});
      o = o || {}; var off = Math.max(0, Math.floor(Number(o.offset) || 0)), lim = Math.max(1, Math.min(500, Math.floor(Number(o.limit) || 96)));
      var tracks = pl.tracks.slice(off, off + lim).map(function (t) { return Object.assign({}, t); });
      return Promise.resolve({ok: true, playlist: summary(pl), tracks: tracks, total: pl.tracks.length, nextOffset: off + tracks.length, hasMore: off + tracks.length < pl.tracks.length});
    },
    createBuiltInPlaylist: function (name) {
      if (playlists.length >= MAX_PLAYLISTS) return Promise.resolve(fail('BUILT_IN_PLAYLIST_LIMIT_REACHED'));
      var pl = {id: newId(), name: text(name, '我的歌单', 80), createdAt: Date.now(), updatedAt: Date.now(), tracks: []};
      playlists.unshift(pl); return Promise.resolve(commit({playlist: summary(pl)}));
    },
    renameBuiltInPlaylist: function (id, name) {
      var pl = find(id); if (!pl) return Promise.resolve(fail('BUILT_IN_PLAYLIST_NOT_FOUND'));
      pl.name = text(name, pl.name, 80); pl.updatedAt = Date.now(); return Promise.resolve(commit({playlist: summary(pl)}));
    },
    deleteBuiltInPlaylist: function (id) {
      var pl = find(id); if (!pl) return Promise.resolve(fail('BUILT_IN_PLAYLIST_NOT_FOUND'));
      playlists = playlists.filter(function (p) { return p !== pl; }); return Promise.resolve(commit({removedId: pl.id}));
    },
    addBuiltInPlaylistTrack: function (id, source) {
      var pl = find(id), t = clean(source);
      if (!pl) return Promise.resolve(fail('BUILT_IN_PLAYLIST_NOT_FOUND'));
      if (!t) return Promise.resolve(fail('BUILT_IN_PLAYLIST_TRACK_INVALID'));
      if (pl.tracks.some(function (x) { return x.builtInIdentity === t.builtInIdentity; })) return Promise.resolve(list({playlist: summary(pl), duplicate: true}));
      if (pl.tracks.length >= MAX_TRACKS) return Promise.resolve(fail('BUILT_IN_PLAYLIST_TRACK_LIMIT_REACHED'));
      pl.tracks.push(t); pl.updatedAt = Date.now(); return Promise.resolve(commit({playlist: summary(pl), added: true}));
    },
    removeBuiltInPlaylistTrack: function (id, index) {
      var pl = find(id), i = Math.floor(Number(index));
      if (!pl) return Promise.resolve(fail('BUILT_IN_PLAYLIST_NOT_FOUND'));
      if (!(i >= 0 && i < pl.tracks.length)) return Promise.resolve(fail('BUILT_IN_PLAYLIST_TRACK_NOT_FOUND'));
      pl.tracks.splice(i, 1); pl.updatedAt = Date.now(); return Promise.resolve(commit({playlist: summary(pl), removedIndex: i}));
    },
    reorderBuiltInPlaylistTrack: function (id, from, to) {
      var pl = find(id); from = Math.floor(Number(from)); to = Math.floor(Number(to));
      if (!pl || !(from >= 0 && from < pl.tracks.length && to >= 0 && to < pl.tracks.length)) return Promise.resolve(fail('BUILT_IN_PLAYLIST_TRACK_NOT_FOUND'));
      pl.tracks.splice(to, 0, pl.tracks.splice(from, 1)[0]); pl.updatedAt = Date.now(); return Promise.resolve(commit({playlist: summary(pl)}));
    }
  };
  // 只挂歌单相关方法；isDesktop 保持 false，桌面窗口/托盘/全屏等能力仍按「非桌面」处理。
  var host = window.desktopWindow || {isDesktop: false};
  Object.keys(api).forEach(function (k) { if (typeof host[k] !== 'function') host[k] = api[k]; });
  window.desktopWindow = host;
  if (typeof refreshBuiltInPlaylists === 'function') { try { refreshBuiltInPlaylists(true); } catch (_) {} }

  // 汽水返回的试听仍是有效音源，交给原版播放并明确显示试听。
  // 不将有效 URL 改为空来强迫跨平台换源，避免有片段却完全播不出来。

  // ---------- 3) 触屏（iPhone 与 iPad 共用） ----------
  // 原版的「账号胶囊自动隐藏」「DIY 按钮自动隐藏」靠鼠标移到右上 / 右下角才出现；触屏没有悬停，
  // iPad 上表现为右上角头像和按钮消失、不知道怎么点开。触屏一律常显。
  var touchOnly = window.matchMedia ? window.matchMedia('(hover: none)') : {matches: false};
  function keepChromeVisible() {
    if (!touchOnly.matches || !document.body) return;
    ['user-capsule-auto-hide', 'fx-fab-auto-hide'].forEach(function (c) { if (document.body.classList.contains(c)) document.body.classList.remove(c); });
  }
  keepChromeVisible();
  if (typeof MutationObserver !== 'undefined' && document.body) {
    new MutationObserver(keepChromeVisible).observe(document.body, {attributes: true, attributeFilter: ['class']});
  }
  // 面板外点一下即关闭（iPad 上歌单 / 视觉控制台原来只能靠鼠标移开收起）。
  document.addEventListener('pointerdown', function (e) {
    if (!touchOnly.matches || (e.pointerType !== 'touch' && e.pointerType !== 'pen')) return;
    var t = e.target;
    if (!t || !t.closest || t.closest('#playlist-panel, #fx-panel, #apple-library-btn, #fx-fab, .modal-mask, #bottom-bar')) return;
    var pl = document.getElementById('playlist-panel'), fx = document.getElementById('fx-panel');
    if (pl && (pl.classList.contains('show') || pl.classList.contains('peek')) && typeof togglePlaylistPanel === 'function') {
      if (typeof playlistPanelPinned !== 'undefined') playlistPanelPinned = false;
      togglePlaylistPanel(false); pl.classList.remove('show', 'peek');
    }
    if (fx && (fx.classList.contains('show') || fx.classList.contains('peek')) && typeof toggleFxPanel === 'function') toggleFxPanel(false);
  }, true);
  // 「歌单」按钮再点一次即收起。
  var libBtn = document.getElementById('apple-library-btn');
  if (libBtn) libBtn.addEventListener('click', function (e) {
    var pl = document.getElementById('playlist-panel');
    if (!pl || !(pl.classList.contains('show') || pl.classList.contains('peek')) || pl.__appleJustOpened) return;
    e.stopImmediatePropagation();
    if (typeof playlistPanelPinned !== 'undefined') playlistPanelPinned = false;
    if (typeof togglePlaylistPanel === 'function') togglePlaylistPanel(false);
    pl.classList.remove('show', 'peek');
  }, true);
  var style = document.createElement('style');
  style.textContent = [
    '@media (hover: none) {',
    '  body.apple-client .apple-panel-close { display: block !important; }',
    '  body.apple-client #user-capsule-hide-btn, body.apple-client #fx-fab-hide-btn { display: none !important; }',
    '  body.apple-client #apple-library-btn { display: inline-flex !important; align-items: center; justify-content: center; flex: 0 0 auto;',
    '    min-width: 44px; height: 44px; padding: 0 12px; border-radius: 22px; color: inherit; background: rgba(20,20,24,.8); border: 1px solid rgba(255,255,255,.22); }',
    '  body.apple-client #hotkey-settings-btn, body.apple-client [data-fx-console-entry][id="hotkey-settings-btn"] { display: none !important; }',
    '}'
  ].join('\n');
  document.head.appendChild(style);
})();
