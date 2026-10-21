// Apple-only adapter appended after the unchanged original modules.
(function installAppleRuntimeAdapter() {
  document.body.classList.add('apple-client');
  var style = document.createElement('style');
  style.textContent = `
    body.apple-client:not(.splash-active):not(.immersive-mode) #fullscreen-diy-zone {
      display: flex; top: var(--fullscreen-diy-top, 88px);
      left: var(--fullscreen-diy-left, calc(100vw - 160px)); right: auto;
      width: var(--fullscreen-diy-width, 128px); height: 44px; pointer-events: auto;
    }
    body.apple-client:not(.splash-active):not(.immersive-mode) #fullscreen-diy-btn {
      opacity: 1; pointer-events: auto; transform: none; min-width: 60px; height: 44px;
    }
    body.apple-client.diy-mode:not(.immersive-mode) #fx-fab {
      opacity: 1; visibility: visible; pointer-events: auto; transform: none;
      right: max(32px, env(safe-area-inset-right));
      bottom: max(40px, env(safe-area-inset-bottom));
    }
    body.apple-client.diy-mode.controls-visible #fx-fab {
      bottom: max(126px, calc(env(safe-area-inset-bottom) + 108px));
    }
    body.apple-client #fx-panel { right: max(32px, env(safe-area-inset-right)); max-width: calc(100vw - 64px); }
  `;
  document.head.appendChild(style);
  var diyZone = document.getElementById('fullscreen-diy-zone');
  if (diyZone) diyZone.setAttribute('aria-hidden', 'false');
  // The desktop runway deliberately keeps whole-song text meshes. On Apple,
  // retain the original visible window and its 24-line lookahead, evicting old
  // offscreen rows via the existing disposal path instead of growing forever.
  if (typeof stageLyricPersistentNextTextRunwayRange === 'function') {
    stageLyricPersistentNextTextRunwayRange = function () { return null; };
  }
  if (typeof trimStageLyricPersistentTrackRows === 'function') {
    var trimOriginalRows = trimStageLyricPersistentTrackRows;
    trimStageLyricPersistentTrackRows = function (mesh, targetIndex, options) {
      var changed = trimOriginalRows(mesh, targetIndex, options);
      var data = mesh && mesh.userData && mesh.userData.lyric;
      if (!data || !data.trackPersistent || !Array.isArray(data.rowLayers)) return changed;
      var offsets = lyricDisplayOffsetsForMode(data.displayMode || (fx && fx.lyricDisplayMode));
      var min = Math.min.apply(Math, [0].concat(offsets)), max = Math.max.apply(Math, [0].concat(offsets));
      var target = Number(targetIndex) || 0;
      var preserve = options && options.interactive && Number.isFinite(Number(options.preserveTargetIndex))
        ? Number(options.preserveTargetIndex) : target;
      data.rowLayers = data.rowLayers.filter(function (row) {
        var index = Number(row && row.isTranslation && row.parentIndex != null ? row.parentIndex : row && row.lineIndex);
        var keep = !Number.isFinite(index) || (index >= target + min - 8 && index <= target + max + 26) ||
          (index >= preserve + min - 2 && index <= preserve + max + 2);
        if (!keep) { disposeStageLyricResidentRow(row); changed = true; }
        return keep;
      });
      updateStageLyricPersistentResidentBounds(data);
      return changed;
    };
  }
  if (typeof lyricQualityPoolBudgetBytes === 'function') {
    var originalQualityBudget = lyricQualityPoolBudgetBytes;
    lyricQualityPoolBudgetBytes = function (tier) { return Math.min(24 * 1024 * 1024, originalQualityBudget(tier)); };
  }
  // A full-screen official login covers the player. Reuse the existing sleep
  // path so two WebViews do not render the stage and login page concurrently.
  var accountSheetVisible = false;
  if (typeof isDeepBackgroundMode === 'function') {
    var originalDeepBackground = isDeepBackgroundMode;
    isDeepBackgroundMode = function () { return accountSheetVisible || originalDeepBackground(); };
  }
  if (typeof isHiddenForBackgroundOptimization === 'function') {
    var originalHiddenBackground = isHiddenForBackgroundOptimization;
    isHiddenForBackgroundOptimization = function () { return accountSheetVisible || originalHiddenBackground(); };
  }
  window.__mineradioAppleSetAuthPresentation = function (visible) {
    accountSheetVisible = !!visible;
    if (typeof updateRenderPowerClasses === 'function') updateRenderPowerClasses();
    if (typeof applyRendererPowerMode === 'function') applyRendererPowerMode();
    if (!accountSheetVisible && typeof recoverVisualsAfterBackground === 'function') recoverVisualsAfterBackground('apple-official-login');
  };
  // Whole-track PCM decoding plus four offline bands can exceed a mobile
  // WebContent memory budget. Retain the existing realtime analyser/rendering;
  // full-track MR/DJ cache generation is not offered by this Apple build.
  if (typeof analyzeAudioBeats === 'function') analyzeAudioBeats = async function () { return null; };
  if (typeof analyzePodcastDjBeats === 'function') analyzePodcastDjBeats = async function () { return null; };

  // WebKit's Web Audio ambient policy can obey the iPhone mute switch even
  // when the native app requested playback. Use its supported playback type.
  try {
    if (typeof navigator !== 'undefined' && navigator.audioSession) navigator.audioSession.type = 'playback';
  } catch (_) {}
  function resumeAppleAnalysis() {
    if (typeof audioCtx !== 'undefined' && audioCtx &&
        (audioCtx.state === 'suspended' || audioCtx.state === 'interrupted') && audioCtx.resume) {
      return audioCtx.resume();
    }
    return Promise.resolve();
  }
  // Create/resume the graph synchronously in the actual user gesture, before
  // provider URL fetching loses WebKit's transient activation.
  if (document.addEventListener) document.addEventListener('pointerdown', function () {
    try {
      // The upstream audio element is null until the first song URL resolves.
      // Prime its future context now, while actual user activation still exists.
      if (typeof audioCtx !== 'undefined' && !audioCtx) {
        var Context = window.AudioContext || window.webkitAudioContext;
        if (Context) audioCtx = new Context();
      }
      if (typeof initAudio === 'function') initAudio();
      resumeAppleAnalysis().catch(function () {});
    } catch (_) {}
  }, {capture: true, passive: true});
  if (typeof HTMLMediaElement !== 'undefined') {
    var originalMediaPlay = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function () {
      var media = this;
      if (media.tagName === 'VIDEO') return originalMediaPlay.call(media);
      var native = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.appleAudioActivate;
      return Promise.resolve(native ? native.postMessage({}) : null).then(function () {
        return resumeAppleAnalysis();
      }).then(function () { return originalMediaPlay.call(media); });
    };
  }
  window.__mineradioApplePlaybackReady = true;
  var canvas = renderer.domElement;
  if (typeof raycasterFromPointerEvent === 'function') raycasterFromPointerEvent = function (event) {
    var rect = canvas.getBoundingClientRect();
    var x = (event.clientX - rect.left) / Math.max(1, rect.width) * 2 - 1;
    var y = -(event.clientY - rect.top) / Math.max(1, rect.height) * 2 + 1;
    var ray = new THREE.Raycaster();
    ray.setFromCamera(new THREE.Vector2(x, y), camera);
    return ray;
  };
  var fingers = new Map(), pinching = false, pinchDistance = 0;
  var activePointer = null;
  var touchStart = null;
  var suppressNativeClickUntil = 0;
  canvas.style.touchAction = 'none';
  function mouse(target, type, event) {
    target.dispatchEvent(new MouseEvent(type, {
      bubbles: true, cancelable: true, clientX: event.clientX, clientY: event.clientY,
      button: 0, buttons: type === 'mousedown' || type === 'mousemove' ? 1 : 0
    }));
  }
  canvas.addEventListener('pointerdown', function (event) {
    if (event.pointerType !== 'touch' && event.pointerType !== 'pen') return;
    if (typeof freeCamera !== 'undefined' && freeCamera.active) return;
    fingers.set(event.pointerId, {x: event.clientX, y: event.clientY});
    if (fingers.size >= 2) {
      event.preventDefault(); canvas.setPointerCapture(event.pointerId);
      pinching = true;
      var points = Array.from(fingers.values()); pinchDistance = Math.hypot(points[0].x-points[1].x, points[0].y-points[1].y);
      activePointer = null; touchStart = null;
      if (typeof orbit !== 'undefined') orbit.rotating = false;
      if (typeof particlePointerSpin !== 'undefined') particlePointerSpin.active = false;
      if (typeof idleGuidePointerUp === 'function') idleGuidePointerUp();
      return;
    }
    if (!event.isPrimary || activePointer !== null || pinching) return;
    // Pointer lock has no equivalent for a finger. Do not enter desktop free-camera controls.
    if (typeof freeCamera !== 'undefined' && freeCamera.active) return;
    activePointer = event.pointerId;
    touchStart = {x: event.clientX, y: event.clientY, at: Date.now(), moved: false};
    event.preventDefault();
    canvas.setPointerCapture(event.pointerId);
    mouse(canvas, 'mousedown', event);
  });
  canvas.addEventListener('pointermove', function (event) {
    if (fingers.has(event.pointerId)) fingers.set(event.pointerId, {x: event.clientX, y: event.clientY});
    if (pinching) {
      event.preventDefault();
      if (fingers.size >= 2) {
        var points = Array.from(fingers.values()), distance = Math.hypot(points[0].x-points[1].x, points[0].y-points[1].y);
        if (distance > 0 && pinchDistance > 0 && typeof WheelEvent !== 'undefined') canvas.dispatchEvent(new WheelEvent('wheel', {
          bubbles: true, cancelable: true, clientX:(points[0].x+points[1].x)/2, clientY:(points[0].y+points[1].y)/2,
          deltaY: Math.max(-200, Math.min(200, -Math.log(distance/pinchDistance)*240)), deltaMode: 0
        }));
        pinchDistance = distance;
      }
      return;
    }
    if (event.pointerId !== activePointer) return;
    if (touchStart && Math.hypot(event.clientX - touchStart.x, event.clientY - touchStart.y) > 8) touchStart.moved = true;
    event.preventDefault(); mouse(window, 'mousemove', event);
  });
  canvas.addEventListener('pointerup', function (event) {
    fingers.delete(event.pointerId);
    if (pinching) {
      event.preventDefault(); suppressNativeClickUntil = Date.now() + 800;
      if (!fingers.size) { pinching = false; pinchDistance = 0; }
      return;
    }
    if (event.pointerId !== activePointer) return;
    event.preventDefault(); activePointer = null; mouse(window, 'mouseup', event);
    suppressNativeClickUntil = Date.now() + 800;
    var tapped = touchStart && !touchStart.moved && Date.now() - touchStart.at < 650 &&
      Math.hypot(event.clientX - touchStart.x, event.clientY - touchStart.y) <= 8;
    touchStart = null;
    if (tapped) {
      mouse(canvas, 'click', event);
      if (typeof window.__mineradioAppleRevealControls === 'function') window.__mineradioAppleRevealControls();
    }
  });
  function cancel(event) {
    if (event.pointerId !== activePointer && !fingers.has(event.pointerId)) return;
    fingers.clear(); pinching = false; pinchDistance = 0;
    activePointer = null; touchStart = null; suppressNativeClickUntil = Date.now() + 800;
    if (typeof orbit !== 'undefined') orbit.rotating = false;
    if (typeof particlePointerSpin !== 'undefined') particlePointerSpin.active = false;
    if (typeof idleGuidePointerUp === 'function') idleGuidePointerUp();
  }
  canvas.addEventListener('click', function (event) {
    // WebKit may still emit a trusted touch click despite preventDefault.
    // Ignore that duplicate; the bridge already dispatched the tap exactly once.
    if (event.isTrusted && (event.pointerType === 'touch' || event.pointerType === 'pen') && Date.now() < suppressNativeClickUntil) {
      event.preventDefault(); event.stopImmediatePropagation();
    }
  }, true);
  canvas.addEventListener('pointercancel', cancel);
  canvas.addEventListener('lostpointercapture', cancel);

  // Upstream stops drawing the splash but retains its second WebGL context,
  // buffers and full-size drawing surface throughout playback.
  var released = false;
  function shrinkSplash() {
    if (released && splashCanvas) splashCanvas.width = splashCanvas.height = 1;
  }
  var splash = document.getElementById('splash');
  if (!splash) return;
  var observer = new MutationObserver(function () {
    if (released || !splash.classList.contains('hide')) return;
    released = true; splashAnimating = false;
    if (splashGl) {
      if (splashGlBuffer) splashGl.deleteBuffer(splashGlBuffer);
      if (splashGlProgram) splashGl.deleteProgram(splashGlProgram);
      var extension = splashGl.getExtension('WEBGL_lose_context');
      if (extension) extension.loseContext();
    }
    splashGl = splashGlBuffer = splashGlProgram = splashGlUniforms = splashCtx = null;
    splashDust = []; splashStreaks = []; splashShards = [];
    shrinkSplash(); observer.disconnect();
  });
  observer.observe(splash, {attributes: true, attributeFilter: ['class']});
  // Register after upstream's DOMContentLoaded resize setup.
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { window.addEventListener('resize', shrinkSplash); });
  } else window.addEventListener('resize', shrinkSplash);
})();
