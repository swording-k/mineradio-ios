// Apple scheduling policy layered over the original renderer. Keep playback,
// transitions and touch responsive; sleep only after the paused stage settles.
(function installApplePowerPolicy() {
  if (window.__mineradioApplePower) return;
  var lastWorkAt = performance.now(), pending = 0, lastPanelScrollAt = -Infinity;
  function scrollingPanel() { return performance.now() - lastPanelScrollAt < 180; }
  function wake() {
    lastWorkAt = performance.now();
    if (typeof wakeMainLoopFromBackground === 'function') wakeMainLoopFromBackground();
  }
  function lyricsStillVisible() {
    if (typeof stageLyrics === 'undefined' || !stageLyrics) return false;
    if (stageLyrics.outgoing && stageLyrics.outgoing.length) return true;
    var mesh = stageLyrics.current;
    if (!mesh || mesh.visible === false) return false;
    var data = mesh.userData && mesh.userData.lyric;
    if (data && Number.isFinite(Number(data.globalOpacity))) return Number(data.globalOpacity) > 0.005;
    var material = mesh.material;
    if (material && material.uniforms && material.uniforms.uOpacity) return Number(material.uniforms.uOpacity.value) > 0.005;
    if (material && Number.isFinite(Number(material.opacity))) return Number(material.opacity) > 0.005;
    // An unknown live lyric representation is not evidence of a settled stage.
    return true;
  }
  function idle() {
    var now = performance.now();
    var busy = pending > 0 || (typeof playing !== 'undefined' && playing) ||
      (typeof audio !== 'undefined' && audio && !audio.paused && !audio.ended) ||
      (typeof playToggleBusy !== 'undefined' && playToggleBusy) ||
      (typeof isMainSceneCoveredBySplash === 'function' && isMainSceneCoveredBySplash()) ||
      (typeof mainLoopInteractionActive === 'function' && mainLoopInteractionActive(now)) ||
      (typeof playbackResumeRecovery !== 'undefined' && playbackResumeRecovery && playbackResumeRecovery.pending) ||
      (typeof albumGaplessState !== 'undefined' && albumGaplessState && albumGaplessState.handoff) ||
      (typeof loginGuideAnimating !== 'undefined' && loginGuideAnimating) ||
      (typeof isProgressDragPreviewActive === 'function' && isProgressDragPreviewActive()) ||
      (typeof shelfManager !== 'undefined' && shelfManager && shelfManager.hasOpenContent && shelfManager.hasOpenContent()) || lyricsStillVisible();
    if (busy) { lastWorkAt = now; return false; }
    return now - lastWorkAt >= 3000;
  }
  if (typeof mainLoopBackgroundDelayMs === 'function') {
    var backgroundDelay = mainLoopBackgroundDelayMs;
    mainLoopBackgroundDelayMs = function () {
      var original = backgroundDelay.apply(this, arguments);
      return original > 0 ? original : (idle() ? 500 : original);
    };
  }
  // Use the original FPS sampler/gate as well as the timer: no extra rAF loop.
  if (typeof getAdaptiveRenderFps === 'function') {
    var renderFps = getAdaptiveRenderFps;
    getAdaptiveRenderFps = function () {
      if (idle()) return 2;
      var original = renderFps.apply(this, arguments);
      return scrollingPanel() ? Math.min(original || 60, 20) : original;
    };
  }
  if (typeof resolveAdaptiveRenderCadence === 'function') {
    var cadence = resolveAdaptiveRenderCadence;
    resolveAdaptiveRenderCadence = function () { return scrollingPanel() || idle() ? null : cadence.apply(this, arguments); };
  }
  if (typeof markRenderInteraction === 'function') {
    var interaction = markRenderInteraction;
    markRenderInteraction = function () { var value = interaction.apply(this, arguments); wake(); return value; };
  }
  function trackLoading(original) {
    return function () {
      pending++; wake();
      function settled() { pending--; wake(); }
      try {
        var result = original.apply(this, arguments);
        if (result && typeof result.finally === 'function') return result.finally(settled);
        settled(); return result;
      } catch (error) { settled(); throw error; }
    };
  }
  // The original track switch clears playToggleBusy before awaiting a URL.
  // Keep explicit ownership across that await, including failures/cancellation.
  if (typeof playQueueAt === 'function') playQueueAt = trackLoading(playQueueAt);
  if (typeof togglePlay === 'function') togglePlay = trackLoading(togglePlay);
  ['pointerdown','pointermove','pointerup','pointercancel','keydown','wheel','scroll','input'].forEach(function (name) {
    document.addEventListener(name, wake, {capture: true, passive: true});
  });
  ['wheel','scroll'].forEach(function (name) {
    document.addEventListener(name, function (event) {
      // Native scene pinch emits wheel events on the canvas; keep that camera
      // gesture at its original cadence. Only list/panel scrolling gets a cap.
      var target = event.target;
      if (target && target.closest && target.closest('#canvas-container')) return;
      lastPanelScrollAt = performance.now();
    }, {capture: true, passive: true});
  });
  document.addEventListener('visibilitychange', wake);
  window.addEventListener('focus', wake);
  if (typeof showToast === 'function') {
    var toast = showToast, lastMessage = null, lastMessageAt = -Infinity;
    showToast = function (message) {
      var now = performance.now(), text = String(message);
      if (text === lastMessage && now - lastMessageAt < 800) return;
      lastMessage = text; lastMessageAt = now;
      return toast.apply(this, arguments);
    };
  }
  window.__mineradioApplePower = {snapshot: function () { return {idle: idle(), pendingOperations: pending}; }};
})();
