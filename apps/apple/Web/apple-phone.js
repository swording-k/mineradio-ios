// 手机排版层（IOS_PLAN 阶段 C）：在原版界面之上按手机尺寸重排，不改原版 DOM 与功能。
// 原则：同样的元素、同样的视觉语言，只调整尺寸、间距、行高与占位，让手指操作舒服。
(function installApplePhoneLayout() {
  if (window.__mineradioApplePhone) return;
  window.__mineradioApplePhone = true;
  var PHONE = '(max-width: 767px), (max-height: 500px) and (max-width: 1024px)';
  var LAND = '(orientation: landscape) and (max-height: 500px) and (max-width: 1024px)';
  var style = document.createElement('style');
  style.setAttribute('data-apple-phone', '');
  style.textContent = `
  @media ${PHONE} {
    /* 首页：原版为网页底部栏预留了 128px，改为只给原生控制条留位，并让首页铺满可滚动 */
    body.apple-client #empty-home {
      bottom: calc(max(var(--apple-native-reserved, 0px), env(safe-area-inset-bottom)) + 8px) !important;
      height: auto !important;
    }
    body.apple-client #empty-home .empty-home-shell {
      height: 100% !important; max-height: none !important;
      -webkit-overflow-scrolling: touch; overscroll-behavior: contain; scroll-padding-bottom: 12px;
    }

    /* 歌单 / 队列：桌面版把 4 个操作按钮竖排，导致每行 126px 高、一屏只能看到 3 首。改为单行 56px。 */
    body.apple-client #playlist-panel .queue-item {
      min-height: 56px !important; padding: 6px 6px 6px 10px !important; gap: 10px !important; align-items: center !important;
    }
    body.apple-client #playlist-panel .queue-item > img { flex: 0 0 44px; width: 44px !important; height: 44px !important; border-radius: 8px; }
    body.apple-client #playlist-panel .qi-name { -webkit-line-clamp: 1 !important; font-size: 15px !important; line-height: 1.3 !important; }
    body.apple-client #playlist-panel .qi-sub { font-size: 12px; line-height: 1.3; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; }
    body.apple-client #playlist-panel .qi-act {
      flex-direction: row !important; flex: 0 0 auto; gap: 0 !important; align-items: center; opacity: 1 !important;
    }
    body.apple-client #playlist-panel .qi-act > button {
      display: inline-flex !important; align-items: center; justify-content: center;
      width: 34px !important; min-width: 34px; height: 44px !important; padding: 0 !important;
      background: transparent !important; border: 0 !important;
    }
    /* 面板头部更紧凑，给列表留出空间 */
    body.apple-client #playlist-panel .playlist-panel-sticky { padding-top: 4px; padding-bottom: 6px; }
    body.apple-client #playlist-panel .queue-head { margin-bottom: 6px; }
    body.apple-client #playlist-panel .panel-tabs { gap: 6px; }
    body.apple-client #playlist-panel .panel-tab { min-height: 40px !important; padding: 0 14px; }
    body.apple-client #playlist-panel, body.apple-client #fx-panel {
      bottom: calc(max(var(--apple-native-reserved, 0px), env(safe-area-inset-bottom)) + 8px) !important;
      max-height: none !important;
    }
  }
  @media ${PHONE} {
    /* 原版工具条吸顶在 82px（桌面头部高度），手机头部更高，导致工具条压住头部、歌曲从缝里透出来。
       手机上工具条随列表滚动，头部改为不透明。 */
    body.apple-client #playlist-panel .queue-toolbar { position: static !important; top: auto !important; margin-bottom: 6px; }
    body.apple-client #playlist-panel .playlist-panel-sticky {
      top: 0 !important; z-index: 3;
      background: rgba(12, 14, 18, .97) !important;
    }
  }
  @media ${LAND} {
    /* 横屏：打开歌单时原生控制条让位，面板从顶部铺到底部；标题行收起，只留标签与操作。 */
    body.apple-client #playlist-panel, body.apple-client #fx-panel {
      bottom: calc(env(safe-area-inset-bottom) + 8px) !important;
    }
    body.apple-client #playlist-panel .queue-head > div:first-child { display: none; }
    body.apple-client #playlist-panel .queue-head { min-height: 0; margin: 0 !important; justify-content: flex-start; }
    body.apple-client #playlist-panel .playlist-panel-sticky { display: flex; flex-direction: row-reverse; align-items: center; justify-content: flex-end; gap: 8px; }
    body.apple-client #playlist-panel .playlist-panel-sticky.apple-has-close > .apple-panel-close { top: 50%; transform: translateY(-50%); }
    body.apple-client #playlist-panel .playlist-panel-sticky.apple-has-close { padding-right: 70px !important; }
    body.apple-client #playlist-panel .playlist-panel-sticky.apple-has-close .queue-head { padding-right: 0; }
    /* 横屏：面板从顶部铺到底部，宽度按屏幕比例，列表至少能看到 4~5 首 */
    body.apple-client #playlist-panel {
      top: max(env(safe-area-inset-top), 8px) !important;
      left: calc(env(safe-area-inset-left) + 8px) !important; right: auto !important;
      width: min(480px, calc(58vw - env(safe-area-inset-left))) !important;
    }
    body.apple-client #fx-panel { top: max(env(safe-area-inset-top), 8px) !important; }
    body.apple-client #playlist-panel .queue-head .fx-sub { display: none; }
    body.apple-client #playlist-panel .queue-head { margin-bottom: 2px; }
    body.apple-client #playlist-panel .panel-tab { min-height: 36px !important; }
  }`;
  document.head.appendChild(style);
  // “关闭”放进歌单面板的吸顶头部右上角，避免压住“常开 / 随机”按钮，并且列表滚动时仍可点到。
  var panel = document.getElementById('playlist-panel');
  var sticky = panel && panel.querySelector('.playlist-panel-sticky');
  var close = panel && panel.querySelector(':scope > .apple-panel-close');
  if (sticky && close) {
    sticky.classList.add('apple-has-close');
    sticky.appendChild(close);
  }
  var extra = document.createElement('style');
  extra.textContent = `
    body.apple-client #playlist-panel .playlist-panel-sticky.apple-has-close { position: sticky; }
    body.apple-client #playlist-panel .playlist-panel-sticky.apple-has-close > .apple-panel-close {
      position: absolute; top: 6px; right: 6px; margin: 0; min-width: 56px; min-height: 40px; border-radius: 12px;
    }
    body.apple-client #playlist-panel .playlist-panel-sticky.apple-has-close .queue-head { padding-right: 64px; }`;
  document.head.appendChild(extra);
  // 登录节点连线（手机）：
  // 1) 竖屏时 MR 节点在平台列表下方偏左，原版只按「左→右」画曲线，线会绕出面板。目标不在右侧时改用竖向 S 形曲线。
  // 2) 登录弹窗在手机上可滚动，手指拖线会被系统当成滚动而取消。端口与排序把手禁止触摸滚动。
  // 3) 再给一个更顺手的方式：手指点一下平台右侧的圆点，直接连接到 MR（与拖线到 MR 等效）。
  if (typeof workflowBezierPath === 'function') {
    var originalBezier = workflowBezierPath;
    workflowBezierPath = function (a, b) {
      if (!a || !b || b.x >= a.x - 8) return originalBezier.apply(this, arguments);
      var dy = b.y - a.y, bend = Math.max(24, Math.min(90, Math.abs(dy) * 0.45));
      return 'M ' + a.x.toFixed(1) + ' ' + a.y.toFixed(1) +
        ' C ' + a.x.toFixed(1) + ' ' + (a.y + Math.sign(dy || 1) * bend).toFixed(1) +
        ', ' + b.x.toFixed(1) + ' ' + (b.y - Math.sign(dy || 1) * bend).toFixed(1) +
        ', ' + b.x.toFixed(1) + ' ' + b.y.toFixed(1);
    };
  }
  var hoverPointer = window.matchMedia ? window.matchMedia('(hover: hover) and (pointer: fine)') : {matches: true};
  document.addEventListener('pointerup', function (event) {
    if (hoverPointer.matches || (event.pointerType !== 'touch' && event.pointerType !== 'pen')) return;
    var port = event.target && event.target.closest ? event.target.closest('#login-node-graph .flow-port.out') : null;
    if (!port || typeof connectLoginProviderToMr !== 'function') return;
    var node = port.closest('[data-login-provider]');
    var provider = port.getAttribute('data-login-provider-output') || (node && node.getAttribute('data-login-provider')) || '';
    if (!provider) return;
    // 原版 pointerup 先结束拖线；拖线本身已连上就不重复。
    setTimeout(function () {
      if (typeof hasLoginWorkflowConnection === 'function' && hasLoginWorkflowConnection(provider)) return;
      if (typeof loginWorkflowPendingProvider !== 'undefined' && loginWorkflowPendingProvider === provider) return;
      connectLoginProviderToMr(provider);
    }, 30);
  }, true);
  var loginStyle = document.createElement('style');
  loginStyle.textContent = `
    body.apple-client #login-node-graph .flow-port, body.apple-client #login-node-graph [data-login-provider-sort] { touch-action: none; }
    body.apple-client #login-node-graph .flow-port.out { position: relative; }
    body.apple-client #login-node-graph .flow-port.out::after { content: ''; position: absolute; inset: -14px; }
    body.apple-client #login-node-graph.dragging-line { touch-action: none; }`;
  document.head.appendChild(loginStyle);
  // 触屏没有“鼠标移开”，去掉这句桌面提示。
  var sub = document.querySelector('#playlist-panel .queue-head .fx-sub');
  if (sub && /鼠标/.test(sub.textContent || '')) sub.textContent = 'QUEUE';
})();
