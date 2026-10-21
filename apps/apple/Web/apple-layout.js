// Apple-only responsive HUD. Preserve original controls, visual materials and handlers.
(function installAppleLayout() {
  var viewport = document.querySelector('meta[name="viewport"]');
  if (viewport && !/viewport-fit\s*=/.test(viewport.content)) viewport.content += ', viewport-fit=cover';
  var style = document.createElement('style');
  style.dataset.appleLayout = 'phone';
  style.textContent = `
  .apple-panel-close { display: none; }
  @media (max-width: 767px), (max-height: 500px) and (max-width: 1024px) {
    body.apple-client {
      --apple-safe-top: env(safe-area-inset-top, 0px);
      --apple-safe-right: env(safe-area-inset-right, 0px);
      --apple-safe-bottom: env(safe-area-inset-bottom, 0px);
      --apple-safe-left: env(safe-area-inset-left, 0px);
      --apple-header-top: calc(var(--apple-safe-top) + 12px);
      --apple-search-top: calc(var(--apple-safe-top) + 64px);
    }
    body.apple-client #top-right {
      top: var(--apple-header-top) !important;
      left: calc(var(--apple-safe-left) + 12px) !important;
      right: calc(var(--apple-safe-right) + 12px) !important;
      width: auto; height: 44px; gap: 8px; align-items: center;
      z-index: 1200;
    }
    body.apple-client #home-btn { flex: 0 0 44px; width: 44px; height: 44px; }
    body.apple-client #user-btn {
      min-width: 44px; min-height: 44px; max-width: calc(100% - 52px);
      margin-left: auto;
    }
    body.apple-client #user-btn.multi-account.external-account-pills {
      flex-direction: row; align-items: center; flex-wrap: nowrap; gap: 6px;
      display: flex !important; flex: 1 1 0; width: 0; max-width: none;
      max-height: 44px; overflow-x: auto; overflow-y: hidden;
      scrollbar-width: none; overscroll-behavior-x: contain; touch-action: pan-x;
    }
    body.apple-client #user-btn.multi-account.external-account-pills .top-account-pill {
      box-sizing: border-box; flex: 0 0 auto; width: 126px; min-width: 126px;
      height: 44px; min-height: 44px; padding: 6px 10px;
    }
    body.apple-client #user-btn.multi-account.external-account-pills .top-account-pill:first-child { margin-left: auto; }
    body.apple-client #user-btn .top-account-name { min-width: 0; max-width: 86px; overflow: hidden; text-overflow: ellipsis; }
    body.apple-client #user-capsule-hide-btn { display: none; }
    body.apple-client #fullscreen-diy-zone {
      top: var(--apple-search-top) !important;
      left: auto !important; right: calc(var(--apple-safe-right) + 12px) !important;
      width: 56px !important; height: 44px;
    }
    body.apple-client #fullscreen-diy-btn { min-width: 56px; height: 44px; }
    body.apple-client #search-area {
      top: var(--apple-search-top) !important;
      left: calc(var(--apple-safe-left) + 12px) !important;
      right: calc(var(--apple-safe-right) + 80px) !important;
      width: auto !important; max-width: none; transform: none !important;
      gap: 6px; z-index: 1100;
    }
    body.apple-client #search-stack { flex: 1; min-width: 0; width: 100%; transform: none; }
    body.apple-client #search-box { box-sizing: border-box; min-width: 0; width: 100%; height: 44px; }
    body.apple-client #search-input { min-width: 0; width: 100%; font-size: 16px; }
    body.apple-client #search-mode-tabs {
      position: static; inset: auto; transform: none; margin: 4px 0 0;
      display: flex; gap: 2px; max-width: 100%; overflow-x: auto;
      scrollbar-width: none; touch-action: pan-x;
    }
    body.apple-client #search-mode-tabs button { flex: 0 0 auto; min-width: 44px; min-height: 44px; padding: 4px 8px; }
    body.apple-client #search-results {
      box-sizing: border-box; width: 100%; left: 0; right: 0;
      max-height: max(100px, calc(var(--apple-visible-height, 100dvh) - 180px));
      overflow-y: auto; overscroll-behavior: contain;
    }
    body.apple-client #bottom-bar,
    body.apple-client #bottom-bar.stage-mode {
      box-sizing: border-box; left: calc(var(--apple-safe-left) + 12px) !important;
      right: calc(var(--apple-safe-right) + 12px) !important;
      bottom: calc(var(--apple-safe-bottom) + 12px) !important;
      width: auto !important; max-width: none; transform: none !important;
      padding: 12px; gap: 6px; border-radius: 28px;
    }
    body.apple-client #controls {
      display: grid !important; grid-template-columns: minmax(0, 1fr) !important;
      grid-template-rows: auto auto auto; gap: 4px; width: 100%; position: static;
    }
    body.apple-client #controls .control-cluster {
      grid-column: 1 !important; min-width: 0; width: 100%; margin: 0;
      height: auto; min-height: 44px; gap: 4px; align-items: center; position: static;
    }
    body.apple-client #controls .actions { grid-row: 1; justify-content: flex-start; }
    body.apple-client #controls .transport { grid-row: 2; justify-content: space-between; }
    body.apple-client #controls .modes { display: flex !important; grid-row: 3; justify-content: space-between; gap: 0; }
    body.apple-client #controls .ctrl-btn {
      display: inline-flex !important; box-sizing: border-box; flex: 0 0 44px;
      min-width: 44px; width: 44px; min-height: 44px; height: 44px; padding: 10px;
      align-items: center; justify-content: center; touch-action: manipulation;
    }
    body.apple-client #controls #play-btn { flex-basis: 56px; width: 56px; height: 56px; }
    body.apple-client #controls .control-track { display: flex !important; min-width: 0; flex: 1 1 0; gap: 8px; }
    body.apple-client #controls .control-cover { flex: 0 0 44px; width: 44px; height: 44px; }
    body.apple-client #controls .control-meta { min-width: 0; max-width: none; flex: 1 1 0; }
    body.apple-client #controls .control-title { min-width: 0; max-width: 100%; gap: 4px; }
    body.apple-client #control-title-text { min-width: 0; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; }
    body.apple-client #control-artist { overflow: hidden; white-space: nowrap; text-overflow: ellipsis; }
    body.apple-client #quality-control { flex: 0 0 auto; }
    body.apple-client #controls #quality-btn { flex-basis: 44px; min-width: 44px; width: 44px; min-height: 44px; height: 44px; padding: 6px; }
    body.apple-client #controls #volume-control { display: flex !important; }
    body.apple-client #time-display { display: none; }
    body.apple-client #progress-bar { flex: 0 0 12px; height: 12px; width: 100%; touch-action: none; }
    body.apple-client #bottom-handle { bottom: calc(var(--apple-safe-bottom) + 8px); min-width: 44px; min-height: 44px; }
    body.apple-client.diy-mode #fx-fab {
      right: calc(var(--apple-safe-right) + 12px) !important;
      bottom: calc(var(--apple-safe-bottom) + 64px) !important;
      width: 48px; height: 48px;
    }
    body.apple-client:has(#bottom-bar.visible:not(.soft-hidden)) #fx-fab {
      bottom: calc(var(--apple-safe-bottom) + var(--apple-bar-height, 190px) + 24px) !important;
    }
    body.apple-client #fx-fab-hide-btn { display: none; }
    body.apple-client #fx-panel, body.apple-client #playlist-panel {
      box-sizing: border-box; position: fixed; left: calc(var(--apple-safe-left) + 12px) !important;
      right: calc(var(--apple-safe-right) + 12px) !important;
      top: calc(var(--apple-safe-top) + 112px) !important;
      bottom: calc(var(--apple-safe-bottom) + 12px) !important;
      width: auto !important; min-width: 0; max-width: none !important;
      max-height: calc(var(--apple-visible-height, 100dvh) - var(--apple-safe-top) - var(--apple-safe-bottom) - 124px);
      overflow-y: auto; overscroll-behavior: contain; z-index: 1600;
    }
    body.apple-client .apple-panel-close { display: block; position: sticky; top: 0; margin-left: auto; z-index: 2; min-width: 64px; min-height: 44px; color: inherit; background: #222; border: 1px solid #555; border-radius: 12px; }
    body.apple-client #fx-panel.peek, body.apple-client #playlist-panel.peek, body.apple-client #fx-panel.show, body.apple-client #playlist-panel.show { transform: none; }
    body.apple-client .modal-mask { box-sizing: border-box; padding: calc(var(--apple-safe-top) + 12px) calc(var(--apple-safe-right) + 12px) calc(var(--apple-safe-bottom) + 12px) calc(var(--apple-safe-left) + 12px); z-index: 2000; }
    body.apple-client .modal-mask > .modal {
      box-sizing: border-box; width: 100% !important; min-width: 0 !important; max-width: 620px !important;
      max-height: calc(var(--apple-visible-height, 100dvh) - var(--apple-safe-top) - var(--apple-safe-bottom) - 24px);
      padding: 20px; overflow-y: auto; overscroll-behavior: contain;
    }
    body.apple-client .modal input:not([type="range"]):not([type="color"]), body.apple-client .modal textarea { font-size: 16px; max-width: 100%; box-sizing: border-box; }
    body.apple-client .user-platform-tabs, body.apple-client .login-platform-tabs { flex-wrap: wrap; min-width: 0; }
    body.apple-client .user-platform-tabs button { min-height: 44px; }
    body.apple-client .dual-account-grid { grid-template-columns: minmax(0, 1fr); }
    body.apple-client #mini-queue-popover { transform: none !important; box-sizing: border-box; left: 0 !important; right: 0 !important; width: 100% !important; max-width: none; bottom: calc(100% + 12px) !important; max-height: max(100px, calc(var(--apple-visible-height, 100dvh) - var(--apple-bar-height, 190px) - 180px)); }
    body.apple-client #volume-control, body.apple-client #lyric-timing-control, body.apple-client #quality-control, body.apple-client .control-title { position: static; }
    body.apple-client .volume-popover, body.apple-client .quality-popover, body.apple-client .lyric-timing-popover {
      box-sizing: border-box; left: 0 !important; right: 0 !important; width: 100% !important; max-width: none;
      bottom: calc(100% + 12px) !important; top: auto !important; transform: none !important;
    }
    body.apple-client #fx-panel input[type="range"], body.apple-client .volume-popover input[type="range"] { min-height: 36px; touch-action: pan-y; }
    body.apple-client #fx-panel .fx-seg, body.apple-client #fx-panel .lyric-font-grid { flex-wrap: wrap; }
  }
  @media (max-width: 360px) {
    body.apple-client #controls .transport { gap: 0; }
    body.apple-client #controls #play-btn { flex-basis: 52px; width: 52px; height: 52px; }
  }
  @media (orientation: landscape) and (max-height: 500px) and (max-width: 1024px) {
    body.apple-client { --apple-search-top: calc(var(--apple-safe-top) + 8px); --apple-header-top: calc(var(--apple-safe-top) + 8px); --apple-search-width: min(35vw, 280px); }
    body.apple-client #search-area { width: var(--apple-search-width) !important; right: auto !important; }
    body.apple-client #fullscreen-diy-zone { left: calc(var(--apple-safe-left) + var(--apple-search-width) + 20px) !important; right: auto !important; }
    body.apple-client #top-right { left: calc(var(--apple-safe-left) + var(--apple-search-width) + 88px) !important; }
    body.apple-client #bottom-bar, body.apple-client #bottom-bar.stage-mode { padding: 8px 12px; gap: 2px; }
    body.apple-client #controls { grid-template-columns: minmax(0, 1fr) auto !important; grid-template-rows: auto auto; gap: 0 12px; }
    body.apple-client #controls .actions { grid-column: 1 !important; grid-row: 1; }
    body.apple-client #controls .transport { grid-column: 2 !important; grid-row: 1; width: auto; gap: 4px; }
    body.apple-client #controls .modes { grid-column: 1 / -1 !important; grid-row: 2; justify-content: flex-end; gap: 4px; }
    body.apple-client #controls #play-btn { flex-basis: 48px; width: 48px; height: 48px; }
    body.apple-client #fx-panel, body.apple-client #playlist-panel { top: calc(var(--apple-safe-top) + 60px) !important; left: auto !important; width: min(420px, calc(100vw - var(--apple-safe-left) - var(--apple-safe-right) - 24px)) !important; max-height: calc(var(--apple-visible-height, 100dvh) - var(--apple-safe-top) - var(--apple-safe-bottom) - 72px); }
  }
  `;
  document.head.appendChild(style);
  [['fx-panel', function () { if (typeof toggleFxPanel === 'function') toggleFxPanel(false); }],
   ['playlist-panel', function () { if (typeof togglePlaylistPanel === 'function') togglePlaylistPanel(false); }]].forEach(function (entry) {
    var panel = document.getElementById(entry[0]);
    if (!panel) return;
    var close = document.createElement('button');
    close.type = 'button'; close.className = 'apple-panel-close'; close.textContent = '关闭';
    close.setAttribute('aria-label', entry[0] === 'fx-panel' ? '关闭视觉控制台' : '关闭歌单面板');
    close.addEventListener('click', entry[1]); panel.prepend(close);
  });
  var quality = document.getElementById('quality-control');
  var qualityParent = quality && quality.parentNode;
  var qualityNext = quality && quality.nextSibling;
  var modes = document.querySelector('#controls .modes');
  var mix = document.getElementById('cuefield-automix-btn');
  var mixParent = mix && mix.parentNode;
  var mixNext = mix && mix.nextSibling;
  var actions = document.querySelector('#controls .actions');
  var phone = window.matchMedia('(max-width: 767px), (max-height: 500px) and (max-width: 1024px)');
  function arrangeQuality() {
    if (quality && modes && qualityParent) {
      if (phone.matches && quality.parentNode !== modes) modes.appendChild(quality);
      else if (!phone.matches && quality.parentNode !== qualityParent) qualityParent.insertBefore(quality, qualityNext);
    }
    if (mix && actions && mixParent) {
      if (phone.matches && mix.parentNode !== actions) actions.appendChild(mix);
      else if (!phone.matches && mix.parentNode !== mixParent) mixParent.insertBefore(mix, mixNext);
    }
  }
  arrangeQuality();
  phone.addEventListener('change', arrangeQuality);
  var root = document.documentElement;
  var bar = document.getElementById('bottom-bar');
  function updateViewport() {
    var height = window.visualViewport ? window.visualViewport.height : window.innerHeight;
    root.style.setProperty('--apple-visible-height', Math.round(height) + 'px');
  }
  function updateBar() {
    if (bar) root.style.setProperty('--apple-bar-height', Math.ceil(bar.getBoundingClientRect().height) + 'px');
  }
  updateViewport(); updateBar();
  window.addEventListener('resize', updateViewport, {passive: true});
  if (window.visualViewport) window.visualViewport.addEventListener('resize', updateViewport, {passive: true});
  if (bar && typeof ResizeObserver !== 'undefined') new ResizeObserver(updateBar).observe(bar);
})();
