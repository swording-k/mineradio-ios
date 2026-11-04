// 手机 / 平板设置（视觉控制台）：
// 1) 用原版自带的平台能力机制（data-desktop-feature + desktopFeatureAvailable）隐藏电脑专属项：
//    完整桌面模式、Wallpaper Engine、桌面歌词、摄像头手势、关闭窗口 / 托盘、输出设备、系统内存释放、缓存目录、热键。
// 2) 增加移动端专属项（参考安卓端：屏幕常亮、横屏锁定、震动），再加睡眠定时。
// 3) 页面进程被系统回收后自动续播：从上次保存的进度继续，而不是从头开始。
(function installAppleMobileSettings() {
  if (window.__mineradioAppleMobile) return;
  window.__mineradioAppleMobile = true;
  var handlers = window.webkit && window.webkit.messageHandlers;

  // ---------- 1) 隐藏电脑专属项 ----------
  var DESKTOP_ONLY = /^(fullDesktopMode|wallpaperEngine|desktopLyricsGlobalMouseToggle|systemMemoryPurge|appleDesktopOnly)$/;
  if (typeof desktopFeatureAvailable === 'function') {
    var originalFeature = desktopFeatureAvailable;
    desktopFeatureAvailable = function (feature) { return DESKTOP_ONLY.test(String(feature)) ? false : originalFeature.apply(this, arguments); };
  }
  function tag(node) { if (node && node.setAttribute) node.setAttribute('data-desktop-feature', 'appleDesktopOnly'); }
  function tagWithLabel(node) {
    if (!node) return;
    tag(node);
    var prev = node.previousElementSibling;
    if (prev && prev.classList && prev.classList.contains('fx-section-label')) tag(prev);
  }
  function byId(id) { return document.getElementById(id); }
  ['t-desktopLyricsClickThrough', 't-desktopLyricsCinema', 't-desktopLyricsHighlight', 't-wallpaperMode', 'hotkey-settings-btn'].forEach(function (id) { tag(byId(id)); });
  ['fx-desktoplyricssize', 'fx-desktoplyricsopacity', 'fx-desktoplyricsy', 'fx-wallpaperopacity'].forEach(function (id) {
    var input = byId(id); tag(input && input.closest('.fx-slider'));
  });
  ['desktop-lyrics-fps-seg', 'wallpaper-fps-seg', 'cam-seg', 'performance-background-seg', 'close-behavior-seg', 'audio-output-panel',
   'memory-status-chip', 'cache-storage-panel'].forEach(function (id) { tagWithLabel(byId(id)); });
  tag(byId('gesture-settings-card')); tag(byId('memory-status-sub'));
  var memoryChip = byId('memory-status-chip');
  if (memoryChip) {
    var n = memoryChip.nextElementSibling;
    while (n && !(n.classList && n.classList.contains('fx-section-label'))) { tag(n); n = n.nextElementSibling; }
  }
  document.querySelectorAll('.fx-section-label').forEach(function (label) {
    if (/^(桌面 \/ 壁纸|桌面帧数)$/.test((label.textContent || '').trim())) tag(label);
  });
  // 桌面歌词开关所在的整组如果全是桌面项，整组隐藏。
  document.querySelectorAll('#fx-panel .fx-toggle-grid').forEach(function (grid) {
    var items = Array.prototype.slice.call(grid.children);
    if (items.length && items.every(function (c) { return c.getAttribute('data-desktop-feature'); })) tag(grid);
  });
  if (typeof applyDesktopPlatformUi === 'function') { try { applyDesktopPlatformUi(); } catch (_) {} }
  var hideStyle = document.createElement('style');
  hideStyle.textContent = 'body.apple-client [data-desktop-feature="appleDesktopOnly"], body.apple-client .desktop-feature-unavailable { display: none !important; }';
  document.head.appendChild(hideStyle);

  // ---------- 2) 移动端专属项 ----------
  var KEY = 'mineradio-apple-device-v1';
  var prefs = {keepAwake: true, haptics: true, orientation: 'auto', sleepMinutes: 0};
  try { Object.assign(prefs, JSON.parse(localStorage.getItem(KEY) || '{}')); } catch (_) {}
  prefs.sleepMinutes = 0; // 睡眠定时每次启动都关闭
  function save() { try { localStorage.setItem(KEY, JSON.stringify({keepAwake: prefs.keepAwake, haptics: prefs.haptics, orientation: prefs.orientation})); } catch (_) {} }
  var tempOrientation = '';
  function pushNative() {
    if (handlers && handlers.appleDevice) {
      try { handlers.appleDevice.postMessage({keepAwake: !!prefs.keepAwake && typeof playing !== 'undefined' && !!playing, haptics: !!prefs.haptics, orientation: tempOrientation || prefs.orientation}); } catch (_) {}
    }
  }
  // 临时方向（如登录时转横屏）；传空字符串恢复用户设置。
  window.__mineradioAppleTempOrientation = function (value) { tempOrientation = value || ''; pushNative(); };
  window.__mineradioAppleHaptic = function () { return !!prefs.haptics; };
  var sleepTimer = 0, sleepAt = 0;
  function setSleep(minutes) {
    prefs.sleepMinutes = minutes;
    if (sleepTimer) clearTimeout(sleepTimer);
    sleepTimer = 0; sleepAt = 0;
    if (minutes > 0) {
      sleepAt = Date.now() + minutes * 60000;
      sleepTimer = setTimeout(function () {
        sleepTimer = 0; sleepAt = 0; prefs.sleepMinutes = 0; render();
        if (typeof playing !== 'undefined' && playing && typeof togglePlay === 'function') togglePlay();
        if (typeof showToast === 'function') showToast('睡眠定时已到，已暂停播放');
      }, minutes * 60000);
      if (typeof showToast === 'function') showToast(minutes + ' 分钟后暂停播放');
    }
    render();
  }

  var section = document.createElement('div');
  section.id = 'apple-mobile-settings';
  section.innerHTML =
    '<div class="fx-section-label">手机 / 平板</div>' +
    '<div class="fx-toggle-grid">' +
      '<div class="fx-toggle" id="t-appleKeepAwake"><span>播放时屏幕常亮</span><span class="dot"></span></div>' +
      '<div class="fx-toggle" id="t-appleHaptics"><span>按键震动反馈</span><span class="dot"></span></div>' +
    '</div>' +
    '<div class="fx-section-label">屏幕方向</div>' +
    '<div class="fx-seg" id="apple-orientation-seg">' +
      '<button data-apple-orientation="auto">跟随系统</button><button data-apple-orientation="portrait">锁定竖屏</button><button data-apple-orientation="landscape">锁定横屏</button>' +
    '</div>' +
    '<div class="fx-section-label">睡眠定时</div>' +
    '<div class="fx-seg" id="apple-sleep-seg">' +
      '<button data-apple-sleep="0">关闭</button><button data-apple-sleep="15">15 分</button><button data-apple-sleep="30">30 分</button><button data-apple-sleep="60">60 分</button><button data-apple-sleep="90">90 分</button>' +
    '</div>';
  function render() {
    var a = byId('t-appleKeepAwake'), h = byId('t-appleHaptics');
    if (a) a.classList.toggle('on', !!prefs.keepAwake);
    if (h) h.classList.toggle('on', !!prefs.haptics);
    section.querySelectorAll('[data-apple-orientation]').forEach(function (b) { b.classList.toggle('active', b.getAttribute('data-apple-orientation') === prefs.orientation); });
    section.querySelectorAll('[data-apple-sleep]').forEach(function (b) { b.classList.toggle('active', Number(b.getAttribute('data-apple-sleep')) === prefs.sleepMinutes); });
  }
  section.addEventListener('click', function (e) {
    var t = e.target && e.target.closest ? e.target.closest('#t-appleKeepAwake, #t-appleHaptics, [data-apple-orientation], [data-apple-sleep]') : null;
    if (!t) return;
    e.preventDefault(); e.stopPropagation();
    if (t.id === 't-appleKeepAwake') prefs.keepAwake = !prefs.keepAwake;
    else if (t.id === 't-appleHaptics') prefs.haptics = !prefs.haptics;
    else if (t.hasAttribute('data-apple-orientation')) prefs.orientation = t.getAttribute('data-apple-orientation');
    else { setSleep(Number(t.getAttribute('data-apple-sleep')) || 0); return; }
    save(); render(); pushNative();
  });
  var advanced = document.querySelector('#fx-advanced .fx-advanced-body');
  var anchor = byId('fx-advanced');
  if (advanced) advanced.insertBefore(section, advanced.firstChild);
  else if (anchor && anchor.parentNode) anchor.parentNode.insertBefore(section, anchor);
  render();
  var wasPlaying = null;
  setInterval(function () {
    var now = typeof playing !== 'undefined' && !!playing;
    if (now !== wasPlaying) { wasPlaying = now; pushNative(); }
  }, 1000);
  pushNative();

  // ---------- 3) 页面进程被回收后续播 ----------
  var recovering = /[?&]apple-recover=1/.test(location.search);
  if (recovering) {
    // 回收不是用户点了播放：只有回收前正在播放才自动续播，暂停状态保持暂停。
    var recoverySnapshot = typeof restoredLastPlaybackSnapshot !== 'undefined' ? restoredLastPlaybackSnapshot : null;
    if (!recoverySnapshot && typeof readLastPlaybackSnapshot === 'function') recoverySnapshot = readLastPlaybackSnapshot();
    var resumeAfterRecovery = !!(recoverySnapshot && recoverySnapshot.playing === true);
    if (typeof startupAutoplayPreference !== 'undefined') startupAutoplayPreference = resumeAfterRecovery;
    if (typeof startupResumeModePreference !== 'undefined') startupResumeModePreference = 'resume';
    // 原版启动模块可能已按“从头播放”算过一次位置；切换临时恢复模式后必须重算。
    if (recoverySnapshot && typeof pendingPlaybackResumeAt !== 'undefined' && typeof startupResumeSecondsFromSnapshot === 'function') {
      pendingPlaybackResumeAt = startupResumeSecondsFromSnapshot(recoverySnapshot);
    }
    try { history.replaceState(null, '', location.pathname); } catch (_) {}
    var tries = 0;
    var skip = setInterval(function () {
      if (++tries > 40) { clearInterval(skip); return; }
      if (document.body && document.body.classList.contains('splash-active') && typeof dismissSplash === 'function') {
        try { dismissSplash({}); } catch (_) {}
      } else if (document.body && !document.body.classList.contains('splash-active')) {
        clearInterval(skip);
        // 原版启动续播可能已在本适配加载前判定过「未开启」，这里显式触发一次。
        setTimeout(function () {
          try {
            if (typeof restoreLastPlaybackSnapshot === 'function' && typeof restoredLastPlaybackSnapshot !== 'undefined' && !restoredLastPlaybackSnapshot) restoreLastPlaybackSnapshot();
            if (resumeAfterRecovery && typeof playing !== 'undefined' && !playing && typeof scheduleStartupAutoplayFromSnapshot === 'function') scheduleStartupAutoplayFromSnapshot('apple-recover');
          } catch (_) {}
        }, 600);
      }
    }, 250);
  }
})();
