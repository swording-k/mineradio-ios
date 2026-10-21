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
        style.textContent = '#splash,#empty-home{display:none!important}#bottom-bar{opacity:1!important;visibility:visible!important;pointer-events:auto!important}';
        document.head.appendChild(style);
        document.body.classList.remove('splash-active');
        if (typeof applyDiyMode === 'function') applyDiyMode(true, {persist:false});
        document.getElementById('bottom-bar').classList.add('visible');
        const button = document.createElement('button');
        button.textContent = '检查手机布局';
        button.style.cssText = 'position:fixed;top:190px;left:16px;z-index:2147483647;height:44px;background:white;color:black';
        const status = document.createElement('p');
        status.style.cssText = 'position:fixed;top:235px;left:16px;z-index:2147483647;background:white;color:black';
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
              if (!inside(element) || r.width < 43.9 || r.height < 43.9) failures.push(element.id || 'fullscreen');
            });
            if (!inside(document.getElementById('bottom-bar'))) failures.push('bar');
            if (document.getElementById('volume-control').classList.contains('open') && !inside(document.querySelector('.volume-popover'))) failures.push('volume');
            status.textContent = failures.length ? '布局检查失败：'+failures.join(',') : '布局检查通过';
          }, 400);
        };
        document.body.append(button,status);
      }, 50);
    })();
    """
}
#endif
