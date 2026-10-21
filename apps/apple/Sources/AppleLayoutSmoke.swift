#if DEBUG && targetEnvironment(simulator)
import Foundation
/// Layout fixture in the actual bundled WebKit document, never shipped in Release.
enum AppleLayoutSmoke {
    static let script = """
    (() => {
      let tries = 0;
      const wait = setInterval(() => {
        if (!document.querySelector('style[data-apple-layout]')) { if (++tries > 600) clearInterval(wait); return; }
        clearInterval(wait);
        if (window.__mineradioAppleSetAuthPresentation) window.__mineradioAppleSetAuthPresentation(true);
        const style = document.createElement('style');
        // Keep rendering asleep but expose the real canvas to native pointer hit testing.
        style.textContent = 'body.render-deep-sleep #canvas-container{visibility:visible!important;opacity:1!important}#splash,#empty-home{display:none!important}#bottom-bar.visible:not(.soft-hidden):not(.apple-controls-collapsed){opacity:1!important;visibility:visible!important;pointer-events:auto!important}';
        style.textContent += '@media(orientation:landscape){#apple-layout-probe,#apple-layout-status,#apple-layout-zoom{left:auto!important;right:16px!important}#apple-layout-probe{top:100px!important}#apple-layout-status{top:145px!important}#apple-layout-zoom{top:180px!important}}';
        document.head.appendChild(style);
        document.body.classList.remove('splash-active', 'home-controls-locked');
        controlsAutoHide = window.__appleSmokeAutoHide === true;
        if (typeof applyDiyMode === 'function') applyDiyMode(true, {persist:false});
        document.getElementById('bottom-bar').classList.add('visible');
        const button = document.createElement('button'); button.id='apple-layout-probe';
        button.textContent = '检查手机布局';
        button.style.cssText = 'position:fixed;top:190px;left:16px;z-index:2147483647;height:44px;background:white;color:black';
        const status = document.createElement('p'); status.id='apple-layout-status';
        status.style.cssText = 'position:fixed;top:235px;left:16px;z-index:2147483647;background:white;color:black;pointer-events:none';
        button.onclick = () => {
          status.textContent = '布局检查中';
          setTimeout(() => {
            const failures = [];
            const inside = (element) => {
              const r = element.getBoundingClientRect();
              return r.left >= -1 && r.top >= -1 && r.right <= innerWidth+1 && r.bottom <= innerHeight+1;
            };
            document.querySelectorAll('#controls .ctrl-btn').forEach(element => {
              const r = element.getBoundingClientRect();
              if (r.width === 0 || r.height === 0) return;
              if (!inside(element) || r.width < 43.9 || r.height < 43.9) failures.push(element.id || 'fullscreen');
            });
            if (!inside(document.getElementById('bottom-bar'))) failures.push('bar');
            if (document.getElementById('volume-control').classList.contains('open') && !inside(document.querySelector('.volume-popover'))) failures.push('volume');
            status.textContent = failures.length ? '布局检查失败：'+failures.join(',') : '布局检查通过';
          }, 400);
        };
        const zoom = document.createElement('p'); zoom.id='apple-layout-zoom';
        zoom.style.cssText = 'position:fixed;top:280px;left:16px;z-index:2147483647;background:white;color:black;pointer-events:none';
        // Avoid a persisted camera already sitting on its zoom limit.
        orbit.userRadius = (orbit.minRadius + orbit.maxRadius) / 2;
        const beforeZoom = orbit.userRadius;
        renderer.domElement.addEventListener('wheel', () => { if (Math.abs(orbit.userRadius-beforeZoom)>0.001) zoom.textContent='双指缩放已触发'; });
        const visibility = document.createElement('p');
        visibility.style.cssText='position:fixed;top:330px;left:16px;z-index:2147483647;background:white;color:black;pointer-events:none';
        const handle=document.getElementById('bottom-handle');
        handle.addEventListener('pointerup', () => {
          visibility.textContent='正在检查持续展示';
          setTimeout(() => {
            const bar=document.getElementById('bottom-bar'), play=document.getElementById('play-btn');
            const r=play.getBoundingClientRect(), hit=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);
            visibility.textContent=bar.classList.contains('apple-touch-controls-open') && Number(getComputedStyle(bar).opacity)>0.5 && hit && hit.closest('#play-btn') ? '控制条持续可用' : '控制条持续展示失败';
          },1500);
        });
        document.body.append(button,status,zoom,visibility);
        if (controlsAutoHide) holdBottomControlsVisible(4000);
      }, 50);
    })();
    """
}
#endif
