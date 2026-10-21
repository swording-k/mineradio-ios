// Apple native official-login sheets, with verified status as the only reply.
(function installAppleAccountLogin() {
  if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.appleAccountLogin) return;
  // The desktop flow opens its own MFA window. Apple must not silently turn
  // a missing challenge UI into an endless "waiting for scan" loop.
  if (typeof pollQishuiQr === 'function' && typeof window.fetch === 'function') {
    var originalFetch = window.fetch.bind(window), lastQRState = null;
    window.fetch = async function (input, options) {
      var response = await originalFetch(input, options);
      try {
        var url = new URL(input && input.url || input, window.location.href);
        if (url.origin === new URL(window.location.href).origin && url.pathname === '/api/qishui/login/check') {
          var body = await response.clone().json();
          lastQRState = {status: body.status, code: body.errorCode || body.error_code, message: body.message};
        }
      } catch (_) {}
      return response;
    };
    var originalQishuiPoll = pollQishuiQr;
    pollQishuiQr = async function (generation) {
      await originalQishuiPoll(generation);
      if (generation !== qishuiQrPollGeneration || loginProvider !== 'qishui' || !lastQRState) return;
      if (lastQRState.status === 'mfa_required' || Number(lastQRState.code) === 2046) {
        stopQrPoll();
        var status = document.getElementById('qr-status');
        if (status) { status.textContent = lastQRState.message || '此账号需要额外安全验证，该验证流程尚未接通。'; status.className = 'fail'; }
      }
    };
  }
  async function open(provider) {
    if (provider === 'qq' ? qqWebLoginBusy : kugouWebLoginBusy) return;
    if (provider === 'qq') qqWebLoginBusy = true; else kugouWebLoginBusy = true;
    updateLoginProviderUi();
    var status = document.getElementById('qr-status');
    if (status) { status.textContent = '请在官方登录页面授权；完成后会验证账号。'; status.className = 'preview'; }
    if (window.__mineradioAppleSetAuthPresentation) window.__mineradioAppleSetAuthPresentation(true);
    try {
      var result = await window.webkit.messageHandlers.appleAccountLogin.postMessage({provider: provider});
      if (!result || result.loggedIn !== true) {
        if (status) { status.textContent = result && result.message || '尚未完成官方登录。'; status.className = 'preview'; }
        return;
      }
      if (provider === 'qq') qqLoginStatus = normalizeQQLoginStatus(result);
      else kugouLoginStatus = normalizeKugouLoginStatus(result);
      activeAccountProvider = provider;
      renderUserBtn(); await refreshUserPlaylists(true); await loadHomeDiscover(true);
      if (result.playbackKeyReady === false) {
        if (status) { status.textContent = '账号已验证，但播放授权尚未齐全，请继续在官方页面授权。'; status.className = 'preview'; }
      } else { closeLoginModal(); showToast((provider === 'qq' ? 'QQ 音乐' : '酷狗音乐') + '账号已连接'); }
    } catch (_) {
      if (status) { status.textContent = '官方登录或账号验证未完成，请重试。'; status.className = 'fail'; }
    } finally {
      if (window.__mineradioAppleSetAuthPresentation) window.__mineradioAppleSetAuthPresentation(false);
      if (provider === 'qq') qqWebLoginBusy = false; else kugouWebLoginBusy = false;
      updateLoginProviderUi();
    }
  }
  openQQWebLogin = function () { return open('qq'); };
  openKugouWebLogin = function () { return open('kugou'); };
})();
