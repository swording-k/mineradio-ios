// Apple-only responsive HUD. Preserve original controls, visual materials and handlers.
(function installAppleLayout() {
  var viewport = document.querySelector('meta[name="viewport"]');
  if (viewport) {
    // WKWebView respects viewport scale limits. Pinch belongs to the stage,
    // never to the complete player HUD (system accessibility Zoom is separate).
    var viewportParts = viewport.content.split(',').filter(function (part) {
      return !/^\s*(initial-scale|minimum-scale|maximum-scale|user-scalable|viewport-fit)\s*=/i.test(part);
    });
    viewport.content = viewportParts.concat(['initial-scale=1', 'minimum-scale=1', 'maximum-scale=1', 'user-scalable=no', 'viewport-fit=cover']).join(', ');
  }
  var style = document.createElement('style');
  style.dataset.appleLayout = 'phone';
  style.textContent = `
  .apple-panel-backdrop { display: none; }
  .apple-panel-close, #apple-controls-more, #apple-controls-collapse, #apple-library-btn { display: none; }
  body.apple-client #bottom-bar.apple-controls-collapsed {
    opacity: 0 !important; pointer-events: none !important;
    transform: translateY(calc(100% + 48px)) !important; visibility: hidden;
  }
  body.apple-client.apple-controls-folded #bottom-handle { opacity: .7; pointer-events: auto; z-index: 1300; }
  body.apple-client:has(#volume-control.open, #quality-control.open, #lyric-timing-control.open) #fx-fab {
    visibility: hidden !important; pointer-events: none !important;
  }

  @media (hover: none) {
    body.apple-client #volume-control:not(.open) .volume-popover { opacity: 0 !important; pointer-events: none !important; visibility: hidden; }
    body.apple-client #volume-control::before { display: none !important; }
  }

  @media (max-width: 767px), (max-height: 500px) and (max-width: 1024px) {
    body.apple-client {
      --apple-safe-top: env(safe-area-inset-top, 0px);
      --apple-safe-right: env(safe-area-inset-right, 0px);
      --apple-safe-bottom: env(safe-area-inset-bottom, 0px);
      --apple-safe-left: env(safe-area-inset-left, 0px);
      --apple-header-top: calc(var(--apple-safe-top) + 12px);
      --apple-search-top: calc(var(--apple-safe-top) + 64px);
    }
    body.apple-client .apple-panel-backdrop:not([hidden]) { display: block; position: fixed; inset: 0; z-index: 1500; border: 0; padding: 0; background: transparent; touch-action: none; }
    body.apple-client #bottom-bar.apple-touch-controls-open {
      opacity: 1 !important; visibility: visible !important; pointer-events: auto !important; transform: none !important;
      background: rgba(8, 8, 12, .72) !important; backdrop-filter: blur(12px) !important; -webkit-backdrop-filter: blur(12px) !important; filter: none !important;
    }
    body.apple-client #bottom-bar.apple-touch-controls-open .ctrl-btn { pointer-events: auto; }
    body.apple-client .apple-panel-close { z-index: 50 !important; }
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
      display: grid !important; grid-template-columns: minmax(0, 1fr) auto !important;
      grid-template-rows: auto auto; gap: 4px; width: 100%; position: static;
    }
    body.apple-client #controls .control-cluster {
      min-width: 0; width: 100%; margin: 0;
      height: auto; min-height: 44px; gap: 4px; align-items: center; position: static;
    }
    body.apple-client #controls .actions { grid-column: 1; grid-row: 1; justify-content: flex-start; }
    body.apple-client #controls .transport { grid-column: 2; grid-row: 1; width: auto; gap: 2px; justify-content: flex-end; }
    body.apple-client #controls .modes { display: none !important; grid-column: 1 / -1; grid-row: 2; flex-wrap: wrap; justify-content: flex-start; gap: 4px; }
    body.apple-client #bottom-bar.apple-controls-expanded #controls .modes { display: flex !important; }
    body.apple-client #apple-controls-more { display: inline-flex; font-size: 18px; }
    body.apple-client #controls #apple-controls-collapse { padding: 0; font-size: 12px; }
    body.apple-client #apple-library-btn { display: inline-flex; align-items: center; justify-content: center; flex: 0 0 44px; min-width: 44px; height: 44px; border-radius: 50%; color: inherit; background: rgba(20,20,24,.8); border: 1px solid rgba(255,255,255,.22); }
    body.apple-client #controls #play-btn { flex-basis: 48px; width: 48px; height: 48px; }
    body.apple-client #bottom-bar.soft-hidden { transform: translateY(calc(100% + 48px)) !important; }
    body.apple-client #playlist-panel .qi-name { white-space: normal; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; font-size: 14px; line-height: 1.4; }
    body.apple-client #playlist-panel .queue-item { min-height: 60px; gap: 8px; }
    body.apple-client #playlist-panel .qi-info { flex: 1 1 0; min-width: 0; }
    body.apple-client #playlist-panel .qi-act { opacity: 1; flex-direction: column; }
    body.apple-client #playlist-panel .panel-tab { min-height: 44px; }

    body.apple-client #controls .ctrl-btn {
      display: inline-flex !important; box-sizing: border-box; flex: 0 0 44px;
      min-width: 44px; width: 44px; min-height: 44px; height: 44px; padding: 10px;
      align-items: center; justify-content: center; touch-action: manipulation;
    }
    body.apple-client #controls #play-btn { flex-basis: 48px; width: 48px; height: 48px; }
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
    body.apple-client:has(#bottom-bar.visible:not(.soft-hidden):not(.apple-controls-collapsed)) #fx-fab {
      bottom: calc(var(--apple-safe-bottom) + var(--apple-bar-height, 190px) + 24px) !important;
    }
    body.apple-client:has(#bottom-bar.apple-touch-controls-open) #fx-fab {
      bottom: calc(var(--apple-safe-bottom) + var(--apple-bar-height, 100px) + 24px) !important;
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
      max-height: calc(var(--apple-visible-height, 100dvh) - var(--apple-bar-height, 100px) - var(--apple-safe-top) - var(--apple-safe-bottom) - 36px); overflow-y: auto; overscroll-behavior: contain;
    }
    body.apple-client #fx-panel input[type="range"], body.apple-client .volume-popover input[type="range"] { min-height: 36px; touch-action: pan-y; }
    body.apple-client #fx-panel .fx-seg, body.apple-client #fx-panel .lyric-font-grid { flex-wrap: wrap; }
  }
  @media (max-width: 360px) {
    body.apple-client #controls .transport { gap: 0; }
    body.apple-client #controls .control-cover { display: none; }
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
    @media (orientation: landscape) and (max-height: 500px) and (max-width: 1024px) {
      body.apple-client #playlist-panel { left: calc(var(--apple-safe-left) + 12px) !important; right: auto !important; width: min(420px, calc(55vw - var(--apple-safe-left) - 12px)) !important; }
    }
  `;
  document.head.appendChild(style);
  [['fx-panel', function () { if (typeof toggleFxPanel === 'function') toggleFxPanel(false); }],
   ['playlist-panel', function () { if (typeof togglePlaylistPanel === 'function') togglePlaylistPanel(false); cleanupPanel('playlist-panel'); }]].forEach(function (entry) {
    var panel = document.getElementById(entry[0]);
    if (!panel) return;
    var close = document.createElement('button');
    close.type = 'button'; close.className = 'apple-panel-close'; close.textContent = '关闭';
    close.setAttribute('aria-label', entry[0] === 'fx-panel' ? '关闭视觉控制台' : '关闭歌单面板');
    close.addEventListener('click', entry[1]); panel.prepend(close);
  });
  // WebKit emits compatibility mouse movement after a finger tap. A desktop
  // left-edge hover must not open a second panel over the user's touch target.
  var hoverPointer = window.matchMedia('(hover: hover) and (pointer: fine)');
  if (typeof setPeek === 'function' && typeof toggleFxPanel === 'function') {
    var originalPeek = setPeek, originalFxToggle = toggleFxPanel, explicitFxToggle = false;
    setPeek = function (element, on, key) {
      // Desktop tests a geometric bridge around the FAB, even when CSS hides
      // it. Compatibility mousemove after a touch must not open/close that UI.
      var guided = typeof visualGuideActive !== 'undefined' && visualGuideActive;
      if (key === 'fx' && !hoverPointer.matches && !explicitFxToggle && !guided) return;
      return originalPeek.apply(this, arguments);
    };
    toggleFxPanel = function () {
      explicitFxToggle = true;
      try { return originalFxToggle.apply(this, arguments); }
      finally { explicitFxToggle = false; }
    };
  }
  if (typeof isPlaylistEdgeTrigger === 'function') {
    var originalPlaylistEdgeTrigger = isPlaylistEdgeTrigger;
    isPlaylistEdgeTrigger = function () {
      return hoverPointer.matches && originalPlaylistEdgeTrigger.apply(this, arguments);
    };
  }
  var quality = document.getElementById('quality-control');
  var qualityParent = quality && quality.parentNode;
  var qualityNext = quality && quality.nextSibling;
  var modes = document.querySelector('#controls .modes');
  var mix = document.getElementById('cuefield-automix-btn');
  var mixParent = mix && mix.parentNode;
  var mixNext = mix && mix.nextSibling;
  var actions = document.querySelector('#controls .actions');
  var phone = window.matchMedia('(max-width: 767px), (max-height: 500px) and (max-width: 1024px)');
  if (typeof updateControlsAutoHideFromPointer === 'function') {
    var desktopControlsPointer = updateControlsAutoHideFromPointer;
    updateControlsAutoHideFromPointer = function () {
      if (phone.matches && !hoverPointer.matches) return;
      return desktopControlsPointer.apply(this, arguments);
    };
  }
  var backdrop;
  function syncBackdrop() {
    if (!backdrop) return;
    var panel = document.getElementById('playlist-panel');
    backdrop.hidden = !(phone.matches && panel && (panel.classList.contains('peek') || panel.classList.contains('show')));
  }
  function cleanupPanel(id) {
    var panel = document.getElementById(id);
    if (!panel || !phone || !phone.matches) return;
    var key = id === 'playlist-panel' ? 'pl' : 'fx';
    if (typeof peekTimers !== 'undefined' && peekTimers[key]) { clearTimeout(peekTimers[key]); peekTimers[key] = null; }
    panel.classList.remove('show', 'peek', 'pinned');
    if (id === 'playlist-panel' && typeof playlistPanelPinned !== 'undefined') playlistPanelPinned = false;
    syncBackdrop();
  }
  if (typeof togglePlaylistPanel === 'function') {
    var originalTogglePlaylistPanel = togglePlaylistPanel;
    togglePlaylistPanel = function (force) {
      if (!phone.matches) return originalTogglePlaylistPanel.apply(this, arguments);
      var panel = document.getElementById('playlist-panel');
      var wasOpen = panel && (panel.classList.contains('show') || panel.classList.contains('peek'));
      if (force === false || (force == null && wasOpen)) { cleanupPanel('playlist-panel'); return; }
      var result = originalTogglePlaylistPanel.call(this, true); syncBackdrop(); return result;
    };
  }
  if (document.body && document.body.appendChild) {
    backdrop = document.createElement('button'); backdrop.type = 'button'; backdrop.className = 'apple-panel-backdrop'; backdrop.hidden = true;
    backdrop.setAttribute('aria-label', '关闭歌单并返回播放器');
    backdrop.addEventListener('pointerdown', function (event) { event.preventDefault(); });
    backdrop.addEventListener('pointerup', function (event) { event.preventDefault(); event.stopPropagation(); cleanupPanel('playlist-panel'); });
    backdrop.addEventListener('click', function (event) { event.preventDefault(); event.stopPropagation(); cleanupPanel('playlist-panel'); });
    document.body.appendChild(backdrop);
  }

  function arrangeQuality() {
    if (quality && modes && qualityParent) {
      if (phone.matches && quality.parentNode !== modes) modes.appendChild(quality);
      else if (!phone.matches && quality.parentNode !== qualityParent) qualityParent.insertBefore(quality, qualityNext);
    }
    if (mix && actions && mixParent) {
      if (phone.matches && mix.parentNode !== modes) modes.appendChild(mix);
      else if (!phone.matches && mix.parentNode !== mixParent) mixParent.insertBefore(mix, mixNext);
    }
  }
  var relocated = ['heart-btn','collect-btn','play-mode-btn','mini-queue-btn'].map(function (id) {
    var element = document.getElementById(id);
    return element && {element: element, parent: element.parentNode, next: element.nextSibling};
  }).filter(Boolean);
  var arrangeOriginal = arrangeQuality;
  arrangeQuality = function () {
    arrangeOriginal();
    relocated.forEach(function (item) {
      if (phone.matches && modes && item.element.parentNode !== modes) modes.appendChild(item.element);
      else if (!phone.matches && item.element.parentNode !== item.parent) item.parent.insertBefore(item.element, item.next && item.next.parentNode === item.parent ? item.next : null);
    });
  };
  arrangeQuality();
  phone.addEventListener('change', arrangeQuality);
  var root = document.documentElement;
  var bar = document.getElementById('bottom-bar');
  var handle = document.getElementById('bottom-handle');
  var transport = document.querySelector('#controls .transport');
  var more;
  if (bar && transport) {
    more = document.createElement('button'); more.id = 'apple-controls-more'; more.className = 'ctrl-btn'; more.type = 'button';
    more.textContent = '•••'; more.setAttribute('aria-label', '更多播放控制'); more.setAttribute('aria-expanded', 'false');
    more.addEventListener('click', function () {
      var expanded = bar.classList.toggle('apple-controls-expanded');
      more.setAttribute('aria-expanded', String(expanded));
      if (typeof holdBottomControlsVisible === 'function') holdBottomControlsVisible(6000);
    });
    transport.appendChild(more);
    if (modes) {
      var collapse = document.createElement('button'); collapse.id = 'apple-controls-collapse'; collapse.type = 'button'; collapse.className = 'ctrl-btn'; collapse.textContent = '收起';
      collapse.setAttribute('aria-label', '收起播放控制条'); collapse.addEventListener('click', foldControls); modes.appendChild(collapse);
    }
  }
  var header = document.getElementById('top-right');
  var user = document.getElementById('user-btn');
  if (header && user) {
    var library = document.createElement('button'); library.id = 'apple-library-btn'; library.type = 'button'; library.textContent = '歌单';
    library.setAttribute('aria-label', '打开歌单与播放队列');
    library.addEventListener('click', function () {
      if (typeof toggleFxPanel === 'function') toggleFxPanel(false);
      if (typeof togglePlaylistPanel === 'function') togglePlaylistPanel(true);
    });
    header.insertBefore(library, user);
  }
  var touchHideTimer;
  function unfoldControls() {
    if (!bar) return;
    bar.classList.remove('apple-controls-collapsed');
    if (phone.matches) {
      if (document.body) document.body.classList.remove('home-controls-locked');
      bar.classList.add('visible', 'apple-touch-controls-open');
      bar.classList.remove('soft-hidden');
      if (touchHideTimer) clearTimeout(touchHideTimer);
      if (typeof controlsAutoHide === 'undefined' || controlsAutoHide) touchHideTimer = setTimeout(function idle() {
        // Do not dismiss a slider/popover while it is in use.
        if (down || (document.querySelector && document.querySelector('#volume-control.open, #quality-control.open, #lyric-timing-control.open'))) {
          touchHideTimer = setTimeout(idle, 8000); return;
        }
        foldControls();
      }, 8000);
    }
    if (document.body) document.body.classList.remove('apple-controls-folded');
    if (typeof controlsHovering !== 'undefined' && !hoverPointer.matches) controlsHovering = false;
    if (typeof holdBottomControlsVisible === 'function') holdBottomControlsVisible(4000);
  }
  function foldControls() {
    if (!bar) return;
    if (touchHideTimer) clearTimeout(touchHideTimer);
    bar.classList.remove('apple-touch-controls-open');
    if (typeof closeMiniQueue === 'function') closeMiniQueue();
    if (typeof controlsRevealHoldUntil !== 'undefined') controlsRevealHoldUntil = 0;
    if (typeof controlsHovering !== 'undefined') controlsHovering = false;
    bar.classList.add('apple-controls-collapsed'); bar.classList.remove('apple-controls-expanded');
    if (more) more.setAttribute('aria-expanded', 'false');
    if (document.body) document.body.classList.add('apple-controls-folded');
  }
  var down = null, suppressClickUntil = 0;
  var volumeWrap = document.getElementById('volume-control');
  if (volumeWrap) {
    // Desktop closes this surface 520ms after mouseleave or slider blur.
    // iOS synthesizes those events between taps, while focus/hover CSS can
    // leave an invisible popover hit layer behind. Touch uses explicit open /
    // outside-tap close instead of a mouse journey between the small controls.
    ['mouseenter','mouseleave','blur'].forEach(function (name) {
      volumeWrap.addEventListener(name, function (event) {
        if (hoverPointer.matches) return;
        if (typeof volumeCloseTimer !== 'undefined' && volumeCloseTimer) clearTimeout(volumeCloseTimer);
        if (typeof volumeCloseTimer !== 'undefined') volumeCloseTimer = null;
        event.stopImmediatePropagation();
      }, true);
    });
  }
  if (bar) {
    [bar, handle].filter(Boolean).forEach(function (target) {
      target.addEventListener('mouseenter', function (event) {
        if (!hoverPointer.matches) event.stopImmediatePropagation();
      }, true);
    });
    bar.addEventListener('pointerdown', function (event) {
      if (event.pointerType !== 'touch' && event.pointerType !== 'pen') return;
      var excluded = event.target.closest && event.target.closest('input, #progress-bar, .volume-popover, .quality-popover');
      down = excluded ? null : {id: event.pointerId, x: event.clientX, y: event.clientY};
      if (typeof holdBottomControlsVisible === 'function') holdBottomControlsVisible(6000);
    }, {passive: true});
    var finishedTouchEvent;
    function finishTouch(event) {
      if (event === finishedTouchEvent) return;
      finishedTouchEvent = event;
      if (event.pointerType !== 'touch' && event.pointerType !== 'pen') return;
      var swipe = down && down.id === event.pointerId && event.clientY - down.y > 40 && Math.abs(event.clientX - down.x) < 40;
      down = null;
      if (swipe) { suppressClickUntil = Date.now() + 600; foldControls(); return; }
      setTimeout(function () {
        if (typeof controlsHovering !== 'undefined') controlsHovering = false;
        unfoldControls();
      }, 0);
    }
    bar.addEventListener('pointerup', finishTouch, {passive: true});
    window.addEventListener('pointerup', function (event) { if (down) finishTouch(event); }, {passive: true, capture: true});
    bar.addEventListener('pointercancel', function () { down = null; if (typeof controlsHovering !== 'undefined') controlsHovering = false; });
    bar.addEventListener('click', function (event) {
      if (Date.now() < suppressClickUntil) { event.preventDefault(); event.stopImmediatePropagation(); }
    }, true);
  }
  if (handle) {
    handle.setAttribute('aria-label', '展开播放控制条');
    handle.addEventListener('pointerup', function (event) { if (event.pointerType === 'touch' || event.pointerType === 'pen') unfoldControls(); }, true);
    handle.addEventListener('click', unfoldControls, true);
  }
  window.__mineradioAppleRevealControls = function () { if (phone.matches) unfoldControls(); };
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
