// 原生播放 UI 桥（IOS_PLAN 阶段 C）：网页只负责视觉，播放 UI 与系统集成交给原生。
// - 向原生推送当前播放状态（锁屏 / 控制中心 / iPhone 原生控制条共用）。
// - 接收原生命令，调用原版 togglePlay / nextTrack / commitProgressSeek 等函数，不改原版逻辑。
// - iPhone 上（原生注入 __mineradioAppleNativeControls）隐藏网页底部控制条，改由原生控制条承载。
(function installAppleNativeControls() {
  if (window.__mineradioAppleNativeControlsInstalled) return;
  var handlers = window.webkit && window.webkit.messageHandlers;
  var bridge = handlers && handlers.appleNowPlaying;
  if (!bridge) return;
  window.__mineradioAppleNativeControlsInstalled = true;
  var nativeBar = !!window.__mineradioAppleNativeControls;
  var webBarRequested = false, lastPayload = '', barHeight = 96;
  var body = document.body;

  if (nativeBar && body) {
    body.classList.add('apple-native-controls');
    var style = document.createElement('style');
    style.textContent = [
      'body.apple-native-controls:not(.apple-native-web-bar) #bottom-bar,',
      'body.apple-native-controls:not(.apple-native-web-bar) #bottom-handle,',
      'body.apple-native-controls #thumb-wrap { display: none !important; }',
      'body.apple-native-controls #fx-panel, body.apple-native-controls #playlist-panel {',
      '  max-height: calc(var(--apple-visible-height, 100dvh) - env(safe-area-inset-top) - var(--apple-native-bar-height, 96px) - 76px) !important; }'
    ].join('\n');
    document.head.appendChild(style);
  }

  function positionFab() {
    if (!nativeBar) return;
    var fab = document.getElementById('fx-fab');
    // 行内 !important 优先级最高，避免与旧的网页控制条定位规则冲突。
    if (!fab) return;
    if (webBarRequested) fab.style.removeProperty('bottom');
    else fab.style.setProperty('bottom', 'calc(' + barHeight + 'px + 16px)', 'important');
  }

  function currentSong() {
    if (typeof playQueue === 'undefined' || !playQueue || typeof currentIdx === 'undefined') return null;
    return currentIdx >= 0 && currentIdx < playQueue.length ? playQueue[currentIdx] : null;
  }
  function seconds(fn) {
    try { var v = typeof fn === 'function' ? Number(fn()) : 0; return isFinite(v) && v > 0 ? v : 0; } catch (_) { return 0; }
  }
  function coverOf(song) {
    var raw = song && (song.customCover || song.cover || song.picUrl || (song.al && song.al.picUrl) || (song.album && song.album.picUrl)) || '';
    raw = String(raw || '');
    // 前端常把封面写成本地代理地址 /api/cover?url=…，或只在左下角缩略图里有地址：都还原成真实图片地址。
    if (!/^https?:\/\//i.test(raw)) {
      var thumb = document.getElementById('thumb-cover');
      if (!raw && thumb && thumb.getAttribute('src')) raw = thumb.getAttribute('src');
      var m = /[?&]url=([^&]+)/.exec(raw);
      if (m) { try { raw = decodeURIComponent(m[1]); } catch (_) {} }
    }
    if (!/^https?:\/\//i.test(raw)) return '';
    return raw.replace(/^http:\/\//i, 'https://').slice(0, 2048);
  }
  function artistOf(song) {
    if (!song) return '';
    if (typeof song.artist === 'string' && song.artist) return song.artist;
    var list = song.artists || song.ar;
    return Array.isArray(list) ? list.map(function (a) { return a && a.name; }).filter(Boolean).join(' / ') : '';
  }
  var landscape = window.matchMedia ? window.matchMedia('(orientation: landscape) and (max-height: 500px) and (max-width: 1024px)') : {matches: false};
  function panelOpen() {
    return ['playlist-panel', 'fx-panel'].some(function (id) {
      var el = document.getElementById(id);
      return !!el && (el.classList.contains('show') || el.classList.contains('peek'));
    });
  }
  function state() {
    var song = currentSong(), heart = document.getElementById('heart-btn');
    return {
      hasSong: !!song,
      title: song ? String(song.name || song.title || '') : '',
      artist: artistOf(song),
      cover: coverOf(song),
      playing: typeof playing !== 'undefined' && !!playing,
      current: Math.round(seconds(typeof getPlaybackCurrentSeconds === 'function' ? getPlaybackCurrentSeconds : null) * 10) / 10,
      duration: Math.round(seconds(typeof getPlaybackDurationSeconds === 'function' ? getPlaybackDurationSeconds : null) * 10) / 10,
      liked: !!(heart && heart.classList.contains('liked')),
      trial: !!(song && song.trial),
      immersive: typeof immersiveMode !== 'undefined' && !!immersiveMode,
      splash: !!(body && body.classList.contains('splash-active')),
      modal: !!document.querySelector('.modal-mask.show,.modal.show,.login-easter-overlay.show'),
      autoHide: typeof controlsAutoHide === 'undefined' ? true : !!controlsAutoHide,
      webBar: webBarRequested,
      // 横屏打开歌单 / 视觉控制台时，原生控制条让出底部空间。
      panel: landscape.matches && panelOpen()
    };
  }
  var lastReserved = -1;
  function reserve(s) {
    // 原生控制条出现时，首页与面板底部给它留位；没歌或切到原版控制条时归零。
    var value = nativeBar && s.hasSong && !s.webBar && !s.immersive && !s.panel ? barHeight : 0;
    if (value === lastReserved) return;
    lastReserved = value;
    document.documentElement.style.setProperty('--apple-native-reserved', value + 'px');
  }
  function push(force) {
    var payload, s;
    try { s = state(); reserve(s); payload = JSON.stringify(s); } catch (_) { return; }
    if (!force && payload === lastPayload) return;
    lastPayload = payload;
    try { bridge.postMessage({type: 'state', state: JSON.parse(payload)}); } catch (_) {}
  }
  function event(type) { try { bridge.postMessage({type: type}); } catch (_) {} }

  function setWebBar(on) {
    webBarRequested = !!on;
    if (body) body.classList.toggle('apple-native-web-bar', webBarRequested);
    if (webBarRequested && typeof window.__mineradioAppleUnfoldWebControls === 'function') window.__mineradioAppleUnfoldWebControls();
    positionFab(); push(true);
  }

  window.__mineradioAppleCommand = function (name, value) {
    try {
      switch (String(name)) {
        case 'toggle': if (typeof togglePlay === 'function') togglePlay(); break;
        case 'play': if (typeof playing !== 'undefined' && !playing && typeof togglePlay === 'function') togglePlay(); break;
        case 'pause': if (typeof playing !== 'undefined' && playing && typeof togglePlay === 'function') togglePlay(); break;
        case 'next': if (typeof nextTrack === 'function') nextTrack(true); break;
        case 'prev': if (typeof prevTrack === 'function') prevTrack(true); break;
        case 'seek':
          if (typeof commitProgressSeek === 'function') commitProgressSeek(Math.max(0, Number(value) || 0), typeof playing !== 'undefined' && !!playing);
          break;
        case 'like': if (typeof toggleLikeCurrent === 'function') toggleLikeCurrent(); break;
        case 'library':
          if (typeof toggleFxPanel === 'function') toggleFxPanel(false);
          if (typeof togglePlaylistPanel === 'function') togglePlaylistPanel(true);
          break;
        case 'lyrics': if (typeof toggleLyricsPanel === 'function') toggleLyricsPanel(); break;
        case 'mode': if (typeof cyclePlayMode === 'function') cyclePlayMode(); break;
        case 'immersive': if (typeof toggleImmersiveMode === 'function') toggleImmersiveMode(); break;
        case 'detail': if (typeof openTrackDetailModal === 'function') openTrackDetailModal('song'); break;
        case 'webBar': setWebBar(!!value); break;
        case 'barHeight':
          barHeight = Math.max(0, Math.min(400, Number(value) || 0));
          document.documentElement.style.setProperty('--apple-native-bar-height', barHeight + 'px');
          lastReserved = -1;
          positionFab();
          break;
        default: return false;
      }
    } catch (_) { return false; }
    setTimeout(function () { push(true); }, 60);
    return true;
  };

  if (nativeBar) {
    // 舞台点按：原来唤出网页控制条，现在唤出原生控制条。
    window.__mineradioAppleRevealControls = function () { event('reveal'); };
    // 网页控制条被手动收起时，回到原生控制条。
    if (body && typeof MutationObserver !== 'undefined') {
      new MutationObserver(function () {
        if (webBarRequested && body.classList.contains('apple-controls-folded')) setWebBar(false);
      }).observe(body, {attributes: true, attributeFilter: ['class']});
    }
  }
  setInterval(function () { push(false); }, 500);
  document.addEventListener('visibilitychange', function () { push(true); });
  positionFab(); push(true);
})();
