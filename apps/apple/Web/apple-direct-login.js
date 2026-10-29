// QQ 音乐 / 酷狗：App 内直接显示二维码并轮询结果（与网易云同一种方式，平行参考安卓 / folia）。
// 替换原版桌面「打开官方网页窗口 + 截取 Cookie」的做法：手机上那条路会出现
// 「QQ 显示登录成功但 App 没反应」「酷狗已登录但一直待同步、没有歌单」。
(function installAppleDirectLogin() {
  if (window.__mineradioAppleDirectLogin) return;
  var handlers = window.webkit && window.webkit.messageHandlers;
  if (!handlers || typeof apiJson !== 'function') return;
  window.__mineradioAppleDirectLogin = true;
  var active = null, generation = 0;
  var TEXT = {
    qq: {name: 'QQ 音乐', scan: '请用手机 QQ 扫码登录',
      desc: '使用 <b>手机 QQ</b> 扫码。本机登录：点「保存二维码」，打开手机 QQ → 扫一扫 → 相册，选这张图即可。'},
    kugou: {name: '酷狗音乐', scan: '请用酷狗 App 扫码登录',
      desc: '使用 <b>酷狗 App</b> 扫码。本机登录：点「在酷狗 App 中打开」确认，或保存二维码后在酷狗扫一扫里从相册识别。'}
  };
  function el(id) { return document.getElementById(id); }
  var lastStatus = null;
  function setStatus(text, cls) { lastStatus = [text, cls || '']; var s = el('qr-status'); if (s) { s.textContent = text; s.className = cls || ''; } }

  // 二维码下方的操作按钮（沿用原版 fx-mini-btn 样式）
  function actions(provider, data) {
    var shell = el('qr-shell');
    if (!shell) return;
    var row = el('apple-qr-actions');
    if (!row) {
      row = document.createElement('div'); row.id = 'apple-qr-actions';
      shell.parentNode.insertBefore(row, shell.nextSibling);
    }
    row.innerHTML = '';
    if (!provider) { row.style.display = 'none'; return; }
    row.style.display = '';
    function button(label, fn) {
      var b = document.createElement('button'); b.type = 'button'; b.className = 'fx-mini-btn ghost'; b.textContent = label;
      b.addEventListener('click', function (e) { e.preventDefault(); e.stopPropagation(); fn(); }); row.appendChild(b);
    }
    button('保存二维码', function () {
      if (!data || !data.img || !handlers.appleSaveImage) return;
      handlers.appleSaveImage.postMessage({dataURL: data.img}).then(function () {
        if (typeof showToast === 'function') showToast('二维码已保存到相册');
      }).catch(function () { if (typeof showToast === 'function') showToast('保存失败，请在系统设置中允许添加照片'); });
    });
    if (provider === 'kugou' && data && data.url) button('在酷狗 App 中打开', function () { window.open(data.url, '_blank'); });
    button('刷新二维码', function () { start(provider); });
  }
  function showQr(provider, data) {
    var shell = el('qr-shell'), img = el('qr-img');
    if (shell) shell.classList.remove('web-login-preview', 'qq-preview', 'netease-preview');
    if (img) { img.src = data.img || ''; img.alt = TEXT[provider].name + '登录二维码'; }
    var desc = el('login-modal-desc');
    if (desc) desc.innerHTML = TEXT[provider].desc;
    actions(provider, data);
  }

  // 每次出码 / 轮询都绑定一个可取消的请求组：切平台、重新出码、关闭弹窗时立即取消旧请求。
  // 否则旧的酷狗长轮询会占住 WebKit 对本机服务的连接（每个主机最多 6 条），新二维码请求排队卡在「正在生成」。
  var inflight = null;
  function cancelInflight() { if (inflight) { try { inflight.abort(); } catch (_) {} inflight = null; } }
  function request(url, timeoutMs) {
    var controller = inflight || (inflight = new AbortController());
    var timer = new AbortController(), t = setTimeout(function () { timer.abort(); }, timeoutMs);
    var signal = controller.signal;
    if (typeof AbortSignal !== 'undefined' && AbortSignal.any) signal = AbortSignal.any([controller.signal, timer.signal]);
    else timer.signal.addEventListener('abort', function () { controller.abort(); });
    return fetch(url, {signal: signal}).then(function (r) { return r.json(); }).finally(function () { clearTimeout(t); });
  }
  async function start(provider) {
    var gen = ++generation;
    cancelInflight();
    active = {provider: provider};
    if (typeof stopQrPoll === 'function') stopQrPoll();
    setStatus('正在生成二维码…', 'preview');
    actions(provider, null);
    try {
      var data = null;
      for (var attempt = 0; attempt < 2 && !(data && data.img); attempt++) {
        try { data = await request('/api/apple/qr/' + provider + '/create?t=' + Date.now(), 10000); }
        catch (err) { if (gen !== generation) return; if (attempt === 1) throw err; }
      }
      if (gen !== generation) return;
      if (!data || !data.img) throw new Error((data && (data.message || data.error)) || '生成二维码失败');
      active.data = data;
      showQr(provider, data);
      setStatus(TEXT[provider].scan, '');
      poll(provider, gen);
    } catch (e) {
      if (gen !== generation) return;
      var msg = e && e.name === 'AbortError' ? '网络较慢，二维码生成超时' : (e && e.message || e);
      setStatus('出错：' + msg + '，点「刷新二维码」重试', 'fail');
      actions(provider, null);
    }
  }
  async function poll(provider, gen) {
    if (gen !== generation || !active || active.provider !== provider) return;
    if (typeof loginProvider !== 'undefined' && loginProvider !== provider) { generation++; cancelInflight(); active = null; actions(null); return; }
    var modal = el('login-modal');
    if (modal && !modal.classList.contains('show')) { generation++; cancelInflight(); return; }
    var d = active.data, url = provider === 'qq'
      ? '/api/apple/qr/qq/check?qrsig=' + encodeURIComponent(d.qrsig) + '&ptqrtoken=' + encodeURIComponent(d.ptqrtoken)
      : '/api/apple/qr/kugou/check?key=' + encodeURIComponent(d.key);
    var result = null;
    try { result = await request(url + '&t=' + Date.now(), provider === 'kugou' ? 20000 : 15000); } catch (_) {}
    if (gen !== generation) return;
    var status = result && result.status;
    if (status === 'ok' && result.loggedIn) return finish(provider, result);
    if (status === 'ok') {
      var why = result.message && result.message !== '登录成功' ? result.message : '请刷新二维码重试';
      setStatus('扫码已确认，但账号校验未通过：' + why + (result.reason ? '（' + result.reason + '）' : ''), 'fail'); return;
    }
    if (status === 'expired') { setStatus('二维码已过期，点「刷新二维码」', 'fail'); return; }
    if (status === 'error') { setStatus(result.message || '登录失败，请刷新二维码', 'fail'); return; }
    if (status === 'scanned') setStatus(result.message || '已扫码，请在手机上确认', 'scan');
    setTimeout(function () { poll(provider, gen); }, provider === 'kugou' ? 1200 : 2000);
  }
  function finish(provider, info) {
    generation++;
    cancelInflight();
    actions(null);
    if (provider === 'qq') {
      qqLoginStatus = normalizeQQLoginStatus(info);
      if (typeof auditProviderVipState === 'function') auditProviderVipState('qq', qqLoginStatus);
      if (typeof qqManualCookieOpen !== 'undefined') qqManualCookieOpen = false;
    } else {
      kugouLoginStatus = normalizeKugouLoginStatus(info);
      if (typeof kugouManualCookieOpen !== 'undefined') kugouManualCookieOpen = false;
    }
    activeAccountProvider = provider;
    if (typeof markLoginWorkflowConnected === 'function') markLoginWorkflowConnected(provider);
    renderUserBtn();
    setStatus('登录成功！', 'scan');
    if (typeof refreshUserPlaylists === 'function') refreshUserPlaylists(true);
    if (typeof loadHomeDiscover === 'function') loadHomeDiscover(true);
    setTimeout(function () {
      if (typeof closeLoginModal === 'function') closeLoginModal();
      if (typeof showToast === 'function') showToast(TEXT[provider].name + '已登录：' + (info.nickname || info.userId || info.uin || ''));
    }, 450);
  }

  openQQWebLogin = function () { return start('qq'); };
  openKugouWebLogin = function () { return start('kugou'); };
  // 切到其它平台时收起按钮并停止轮询；切回 QQ / 酷狗时自动出码。
  if (typeof updateLoginProviderUi === 'function') {
    var originalUi = updateLoginProviderUi;
    updateLoginProviderUi = function () {
      var r = originalUi.apply(this, arguments);
      var p = typeof loginProvider !== 'undefined' ? loginProvider : '';
      if (active && active.provider === p && active.data) {
        showQr(p, active.data);
        var s = el('qr-status'); if (s && lastStatus) { s.textContent = lastStatus[0]; s.className = lastStatus[1]; }
      }
      else if (p !== 'qq' && p !== 'kugou') { actions(null); if (active) { generation++; cancelInflight(); active = null; } }
      var card = el('qq-web-login-card'), label = card && card.querySelector('span');
      if (p === 'qq' || p === 'kugou') {
        if (card) card.disabled = false;
        if (label) label.textContent = '显示登录二维码';
        // 已登录时原版「刷新状态」只查状态、不出码，导致无法重新扫码。统一改为直接出码。
        var refresh = el('refresh-qr-btn');
        if (refresh) {
          refresh.disabled = false;
          refresh.textContent = active && active.provider === p ? '刷新二维码' : '扫码登录';
          refresh.onclick = function () { start(p); };
        }
      }
      return r;
    };
  }

  // Spotify 由独立 Apple 适配器处理用户配置与系统授权。
  var style = document.createElement('style');
  style.textContent = [
    // 按钮放在二维码下方独占一行：横向排列、文字不换行，窄时自动换到下一行而不是被挤成竖排。
    'body.apple-client #apple-qr-actions { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; align-items: center;',
    '  width: max-content; max-width: min(340px, 86vw); justify-self: center; box-sizing: border-box; margin: 10px 0 4px; }',
    'body.apple-client #apple-qr-actions .fx-mini-btn { flex: 0 0 auto; width: auto !important; min-width: 0; height: 34px; padding: 0 14px;',
    '  white-space: nowrap; writing-mode: horizontal-tb; font-size: 12px; line-height: 34px; }'
  ].join('\n');
  document.head.appendChild(style);
})();
