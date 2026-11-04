// Apple 内存治理：复用原版引擎自己的渲染预算与缓存裁剪路径，不改视觉设计。
// iOS 收到内存警告时逐级降低内部渲染分辨率（效果、粒子、歌词功能保持不变），
// 并调用原版 trimRuntimeCaches 做深度缓存裁剪，避免 WebContent 被系统杀掉导致黑屏。
(function installAppleMemoryPolicy() {
  if (window.__mineradioAppleMemory) return;
  var SCALES = [1, 0.85, 0.72, 0.6];
  var level = 0, lastPressureAt = -Infinity;
  function now() { return (typeof performance !== 'undefined' && performance.now) ? performance.now() : Date.now(); }
  if (typeof renderQualityProfile === 'function') {
    var originalProfile = renderQualityProfile;
    renderQualityProfile = function () {
      var profile = originalProfile.apply(this, arguments);
      if (!level || !profile) return profile;
      var scale = SCALES[level];
      var min = Math.max(0.5, profile.min * scale);
      return { cap: Math.max(min, profile.cap * scale), min: min, budget: Math.round(profile.budget * scale * scale) };
    };
  }
  function pixelRatio() {
    try { return typeof renderer !== 'undefined' && renderer && renderer.getPixelRatio ? renderer.getPixelRatio() : 0; } catch (_) { return 0; }
  }
  function snapshot() { return { level: level, renderPixelRatio: pixelRatio() }; }
  function apply(reason) {
    try { if (typeof trimRuntimeCaches === 'function') trimRuntimeCaches('apple-' + reason, true); } catch (_) {}
    try { if (typeof applyRendererPowerMode === 'function') applyRendererPowerMode(); } catch (_) {}
  }
  // reason: 'warning'（系统内存警告）或 'restore'（WebContent 重启后恢复上次的档位）。
  window.__mineradioAppleMemoryPressure = function (reason, atLeast) {
    reason = String(reason || 'warning');
    if (reason === 'restore') {
      var target = Math.max(0, Math.min(SCALES.length - 1, Number(atLeast) || 0));
      if (target > level) { level = target; apply('restore'); }
      return snapshot();
    }
    var t = now();
    // 系统常在短时间内连发多次警告，合并处理，避免一次降到底。
    if (t - lastPressureAt < 1500) return snapshot();
    lastPressureAt = t;
    if (level < SCALES.length - 1) level++;
    apply('memory-' + reason);
    return snapshot();
  };
  window.__mineradioAppleMemory = { snapshot: snapshot };
})();
