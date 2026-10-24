// Local, bounded observations. No media URL, title, lyrics, account, cookies or identifiers.
// Reuse original counters; do not schedule extra render frames or modify playback.
(function installAppleDiagnostics() {
  var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.appleDiagnostics;
  if (!bridge || window.__mineradioAppleDiagnostics) return;
  window.__mineradioAppleDiagnostics = true;
  var attached = new WeakSet(), current = null, lastTime = null, lastSeek = 0, epoch = 0, pending = 0;
  function metrics() {
    var out = {sourceEpoch: epoch, recentSeek: Date.now() - lastSeek < 3000 ? 1 : 0};
    var info = typeof renderer !== 'undefined' && renderer && renderer.info;
    if (info) {
      if (info.memory) { out.textures = info.memory.textures; out.geometries = info.memory.geometries; }
      if (info.programs) out.programs = info.programs.length;
      if (renderer.domElement) { out.canvasWidth = renderer.domElement.width; out.canvasHeight = renderer.domElement.height; }
      if (renderer.getPixelRatio) out.pixelRatio = renderer.getPixelRatio();
    }
    var perf = window.__mineradioPerf;
    if (perf) { out.fps = perf.fps; out.targetFps = perf.targetFps; out.frameCostMs = perf.adaptiveFrameCostMs; out.pressure = perf.adaptivePressure; }
    if (current) {
      out.mediaTime = current.currentTime; out.duration = current.duration;
      out.paused = current.paused ? 1 : 0; out.seeking = current.seeking ? 1 : 0; out.ended = current.ended ? 1 : 0;
      out.readyState = current.readyState; out.networkState = current.networkState;
      if (current.error) out.mediaCode = current.error.code;
    }
    Object.keys(out).forEach(function (key) { if (!Number.isFinite(out[key]) || out[key] < 0) delete out[key]; });
    return out;
  }
  function post(event) {
    if (pending >= 4) return;
    try {
      pending++;
      Promise.resolve(bridge.postMessage({event: event, metrics: metrics()})).catch(function () {}).finally(function () { pending--; });
    } catch (_) { pending--; }
  }
  function bindAudio() {
    var media = typeof audio !== 'undefined' ? audio : null;
    if (!media || !media.addEventListener) return;
    if (current !== media) { current = media; lastTime = media.currentTime; epoch++; }
    if (attached.has(media)) return;
    attached.add(media);
    ['play','pause','playing','waiting','stalled','seeking','seeked','ended','emptied','loadedmetadata','error'].forEach(function (name) {
      media.addEventListener(name, function () {
        if (media !== current) return;
        if (name === 'seeking' || name === 'seeked') lastSeek = Date.now();
        if (name === 'loadedmetadata' || name === 'emptied') { epoch++; lastTime = null; }
        post('media-' + name);
      });
    });
    media.addEventListener('timeupdate', function () {
      if (media !== current) return;
      var now = Number(media.currentTime);
      // An observation, not a crash diagnosis: seek/loop/source events remain in the trace.
      if (lastTime != null && now < lastTime - 2) post('media-time-regressed');
      lastTime = now;
    });
  }
  function sample() { bindAudio(); if (!document.hidden) post('sample'); }
  document.addEventListener('play', bindAudio, true);
  document.addEventListener('loadedmetadata', bindAudio, true);
  document.addEventListener('visibilitychange', function () { if (!document.hidden) sample(); });
  sample();
  setInterval(sample, 10000);
})();
