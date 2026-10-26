// Mobile playback speed uses the existing volume surface and original media
// graph. AutoMix owns deck timing while enabled; never overwrite its rates.
(function installAppleSpeed() {
  if (window.__mineradioAppleSpeed) return;
  var key = 'mineradio-apple-speed-v1', rate = 1;
  function normalized(value) { value = Number(value); return Number.isFinite(value) && value > 0 ? Math.round(Math.max(0.5, Math.min(3, value)) * 20) / 20 : 1; }
  try { rate = normalized(localStorage.getItem(key)); } catch (_) {}
  function engineOwnsTempo() { return typeof cuefieldAutoMixEnabled !== 'undefined' && cuefieldAutoMixEnabled; }
  function apply(media) {
    if (!media || engineOwnsTempo()) return;
    media.preservesPitch = true;
    if ('webkitPreservesPitch' in media) media.webkitPreservesPitch = true;
    media.defaultPlaybackRate = rate;
    media.playbackRate = rate;
  }
  var popover = document.querySelector('#volume-control .volume-popover');
  if (!popover) return;
  var row = document.createElement('div'); row.className = 'apple-speed-row';
  var label = document.createElement('label'); label.textContent = '倍速'; label.setAttribute('for', 'apple-speed-slider');
  var slider = document.createElement('input'); slider.id = 'apple-speed-slider'; slider.type = 'range';
  slider.min = '0.5'; slider.max = '3'; slider.step = '0.05'; slider.setAttribute('aria-label', '播放速度');
  var reset = document.createElement('button'); reset.id = 'apple-speed-reset'; reset.type = 'button'; reset.setAttribute('aria-label', '恢复正常播放速度');
  row.appendChild(label); row.appendChild(slider); row.appendChild(reset); popover.appendChild(row);
  var note = document.createElement('div'); note.className = 'apple-speed-note'; note.textContent = '保留音高'; popover.appendChild(note);
  function refresh() {
    slider.value = String(rate); slider.setAttribute('aria-valuetext', rate + ' 倍'); reset.textContent = rate + '×';
    slider.disabled = reset.disabled = !!engineOwnsTempo();
    note.textContent = engineOwnsTempo() ? 'AutoMix 正在管理速度' : '保留音高 · 点击数值恢复 1×';
  }
  function set(value) { rate = normalized(value); try { localStorage.setItem(key, String(rate)); } catch (_) {} apply(typeof audio !== 'undefined' ? audio : null); refresh(); }
  slider.addEventListener('input', function () { set(slider.value); });
  reset.addEventListener('click', function () { set(1); });
  // Audio elements are not necessarily in the DOM, so document play events
  // cannot reliably observe them. Chain the existing Apple activation wrapper.
  if (typeof HTMLMediaElement !== 'undefined') {
    var play = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function () {
      if (typeof audio !== 'undefined' && this === audio) apply(this);
      return play.apply(this, arguments);
    };
  }
  function after(original) { return function () { var result = original.apply(this, arguments); apply(typeof audio !== 'undefined' ? audio : null); refresh(); return result; }; }
  if (typeof initAudio === 'function') initAudio = after(initAudio);
  if (typeof replaceAudioElementForGraphRecovery === 'function') replaceAudioElementForGraphRecovery = after(replaceAudioElementForGraphRecovery);
  if (typeof bindPlaybackProgressEvents === 'function') {
    var bind = bindPlaybackProgressEvents;
    bindPlaybackProgressEvents = function (media) { if (typeof audio !== 'undefined' && media === audio) apply(media); return bind.apply(this, arguments); };
  }
  function prepareGapless(original) { return function (preload) { if (preload) apply(preload.media); return original.apply(this, arguments); }; }
  if (typeof startAlbumGaplessPreroll === 'function') startAlbumGaplessPreroll = prepareGapless(startAlbumGaplessPreroll);
  if (typeof startAlbumGaplessMix === 'function') startAlbumGaplessMix = prepareGapless(startAlbumGaplessMix);
  if (typeof updateCuefieldAutoMixUi === 'function') updateCuefieldAutoMixUi = after(updateCuefieldAutoMixUi);
  var style = document.createElement('style');
  style.textContent = 'body.apple-client .apple-speed-row{display:flex;align-items:center;gap:8px;border-top:1px solid rgba(255,255,255,.12);margin-top:8px;padding-top:6px}body.apple-client .apple-speed-row label{font-size:12px;flex:0 0 28px}body.apple-client .volume-popover .apple-speed-row input{flex:1;min-width:0;min-height:44px;touch-action:pan-y}body.apple-client .apple-speed-row button{min-width:44px;min-height:44px;border:0;border-radius:10px;background:rgba(255,255,255,.08);color:inherit}body.apple-client .apple-speed-note{font-size:10px;opacity:.65;line-height:1.5;padding-bottom:4px}';
  document.head.appendChild(style);
  apply(typeof audio !== 'undefined' ? audio : null); refresh();
  window.__mineradioAppleSpeed = {getRate: function () { return rate; }};
})();
