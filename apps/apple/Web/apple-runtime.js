// Apple-only adapter appended after the unchanged original modules.
(function installAppleRuntimeAdapter() {
  document.body.classList.add('apple-client');
  var style = document.createElement('style');
  style.textContent = `
    body.apple-client:not(.splash-active):not(.immersive-mode) #fullscreen-diy-zone {
      display: flex; top: max(12px, env(safe-area-inset-top));
      right: max(12px, env(safe-area-inset-right)); left: auto;
      width: 68px; height: 44px; pointer-events: auto;
    }
    body.apple-client:not(.splash-active):not(.immersive-mode) #fullscreen-diy-btn {
      opacity: 1; pointer-events: auto; transform: none; min-width: 60px; height: 44px;
    }
    body.apple-client.diy-mode:not(.immersive-mode) #fx-fab {
      opacity: 1; visibility: visible; pointer-events: auto; transform: none;
      right: max(16px, env(safe-area-inset-right));
      bottom: max(20px, env(safe-area-inset-bottom));
    }
  `;
  document.head.appendChild(style);
  var diyZone = document.getElementById('fullscreen-diy-zone');
  if (diyZone) diyZone.setAttribute('aria-hidden', 'false');
  var canvas = renderer.domElement;
  var activePointer = null;
  canvas.style.touchAction = 'none';
  function mouse(target, type, event) {
    target.dispatchEvent(new MouseEvent(type, {
      bubbles: true, cancelable: true, clientX: event.clientX, clientY: event.clientY,
      button: 0, buttons: type === 'mouseup' ? 0 : 1
    }));
  }
  canvas.addEventListener('pointerdown', function (event) {
    if (event.pointerType !== 'touch' && event.pointerType !== 'pen') return;
    if (!event.isPrimary || activePointer !== null) return;
    // Pointer lock has no equivalent for a finger. Do not enter desktop free-camera controls.
    if (typeof freeCamera !== 'undefined' && freeCamera.active) return;
    activePointer = event.pointerId;
    event.preventDefault();
    canvas.setPointerCapture(event.pointerId);
    mouse(canvas, 'mousedown', event);
  });
  canvas.addEventListener('pointermove', function (event) {
    if (event.pointerId !== activePointer) return;
    event.preventDefault(); mouse(window, 'mousemove', event);
  });
  canvas.addEventListener('pointerup', function (event) {
    if (event.pointerId !== activePointer) return;
    event.preventDefault(); activePointer = null; mouse(window, 'mouseup', event);
  });
  function cancel(event) {
    if (event.pointerId !== activePointer) return;
    activePointer = null;
    if (typeof orbit !== 'undefined') orbit.rotating = false;
    if (typeof particlePointerSpin !== 'undefined') particlePointerSpin.active = false;
    if (typeof idleGuidePointerUp === 'function') idleGuidePointerUp();
  }
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
