// 头像 / 封面稳定化：原版 avatarSrc 每次渲染都追加 Date.now() 强制重载，
// 账号胶囊每次刷新都会先变空再出现（手机上表现为头像闪烁）。
// 这里改成每个会话固定的版本号：同一张头像在本次启动内命中缓存，重启或换号仍会刷新。
(function installAppleMediaStability() {
  if (window.__mineradioAppleMedia) return;
  window.__mineradioAppleMedia = true;
  var sessionStamp = Date.now();
  // 原版只在 Chrome 系内核启用 SVG 位移玻璃（backdrop-filter: url(#...)），并刻意排除 Safari。
  // App 内 WKWebView 的 UA 没有 "Safari" 字样，于是误判为支持，WebKit 渲染出错位的暗色圆块
  // （首页按钮、搜索框、账号胶囊旁的“幽灵圆”）。这里回到原版为 Safari 准备的模糊玻璃路径。
  if (typeof supportsControlGlassSvgFilter === 'function') supportsControlGlassSvgFilter = function () { return false; };
  var root = document.documentElement;
  function dropSvgGlass() {
    if (root.classList.contains('control-glass-svg-ok')) root.classList.remove('control-glass-svg-ok');
  }
  dropSvgGlass();
  if (typeof MutationObserver !== 'undefined') new MutationObserver(dropSvgGlass).observe(root, {attributes: true, attributeFilter: ['class']});
  if (typeof avatarSrc === 'function' && typeof coverProxySrc === 'function') {
    avatarSrc = function (url) {
      if (!url) return '';
      var src = coverProxySrc(url, false);
      if (!src || src.indexOf('/api/cover?') !== 0) return src;
      return src + '&v=' + sessionStamp;
    };
  }
})();
