// Apple-only restoration of Spotify's existing library/search contracts.
// System OAuth owns credentials; WebKit receives verified account metadata only.
(function installAppleSpotify() {
  var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.appleAccountLogin;
  if (!bridge || window.__mineradioAppleSpotify) return;
  window.__mineradioAppleSpotify = true;
  [ACCOUNT_PROVIDER_KEYS, LOGIN_WORKFLOW_PROVIDERS, MUSIC_SEARCH_PROVIDER_ORDER, SEARCH_HISTORY_MODES].forEach(function (list) { if (list.indexOf('spotify') < 0) list.push('spotify'); });
  function includeSpotify(original) { return function (provider) { return provider === 'spotify' ? 'spotify' : original.apply(this, arguments); }; }
  normalizeAccountProviderKey = includeSpotify(normalizeAccountProviderKey);
  normalizeLoginProviderKey = includeSpotify(normalizeLoginProviderKey);
  searchModeProvider = includeSpotify(searchModeProvider);
  var anyLogin = hasAnyPlatformLogin, providerCount = loggedProviderCount;
  hasAnyPlatformLogin = function () { return hasPlatformLogin('spotify') || anyLogin.apply(this, arguments); };
  loggedProviderCount = function () { return providerCount.apply(this, arguments) + (hasPlatformLogin('spotify') ? 1 : 0); };
  function button(id, label, parent, handler, className) {
    if (!parent) return null;
    var node = document.createElement('button'); node.id = id; node.type = 'button'; node.textContent = label;
    node.className = className || ''; node.onclick = handler; node.setAttribute('aria-label', label); parent.appendChild(node); return node;
  }
  var login = button('login-provider-spotify', 'Spotify', document.getElementById('login-platform-tabs'), function () { selectLoginProviderNode('spotify'); }, 'spotify workflow-node');
  if (login) {
    login.setAttribute('data-login-provider', 'spotify');
    var port = document.createElement('span'); port.className = 'flow-port out'; port.setAttribute('data-login-provider-output', 'spotify'); login.appendChild(port);
  }
  var search = button('search-mode-spotify', 'SP', document.getElementById('search-mode-tabs'), function () { setSearchMode('spotify'); });
  var userTab = button('user-provider-spotify', 'Spotify', document.querySelector('#user-modal .user-platform-tabs'), function () { setActiveAccountProvider('spotify'); }, 'spotify');
  var addAccount = button('account-add-spotify', '连接 Spotify', document.querySelector('#user-modal .account-modal-actions'), function () { openProviderLogin('spotify'); }, 'modal-btn');
  var panel = document.createElement('div'); panel.id = 'apple-spotify-info';
  panel.textContent = '同步 Spotify 歌单、喜欢的歌曲与搜索。播放时会匹配已授权且可用的其他音乐源；匹配结果可能与原曲版本不同。';
  var drawer = document.getElementById('login-auth-drawer'); if (drawer) drawer.appendChild(panel);
  var style = document.createElement('style');
  style.textContent = 'body.apple-client #login-provider-spotify{color:#1ed760;min-height:52px}body.apple-client #apple-spotify-info{display:none;padding:12px 0;font-size:13px;line-height:1.7;color:rgba(255,255,255,.65)}body.apple-client .apple-spotify-selected #apple-spotify-info{display:block}body.apple-client .apple-spotify-selected > .login-auth-copy{display:block}body.apple-client .apple-spotify-selected > .login-auth-actions{display:flex;flex-wrap:wrap}body.apple-client .apple-spotify-selected .login-auth-body,body.apple-client .apple-spotify-selected #qq-cookie-toggle-btn{display:none!important}body.apple-client #search-mode-tabs{overflow-x:auto;max-width:100%;overscroll-behavior-x:contain}body.apple-client #search-mode-tabs button{flex-shrink:0}';
  document.head.appendChild(style);
  // Desktop's developer setup wizard/loopback check is not an end-user login
  // flow on iOS. The application registration is supplied by the team at build.
  scheduleSpotifySetupAutoCheck = function () {};
  renderSpotifySetupWizard = function () {};
  spotifyLoginStatusText = function (info) {
    info = info || spotifyLoginStatus;
    if (info.loggedIn) return 'Spotify 已连接 · ' + (info.nickname || '账号') + ' · 播放采用匹配源';
    return info.oauthConfigured ? '点击“连接 Spotify”，在系统授权窗口登录。' : '团队尚未配置 Spotify 授权应用；无需用户自行注册。';
  };
  var originalUI = updateLoginProviderUi;
  updateLoginProviderUi = function () {
    var result = originalUI.apply(this, arguments), selected = loginProvider === 'spotify';
    if (drawer) drawer.classList.toggle('apple-spotify-selected', selected);
    if (login) login.classList.toggle('active', selected);
    if (!selected) return result;
    var title = document.getElementById('login-modal-title'), desc = document.getElementById('login-modal-desc'), status = document.getElementById('qr-status'), refresh = document.getElementById('refresh-qr-btn');
    if (title) title.textContent = '连接 Spotify';
    if (desc) desc.textContent = '使用 Spotify 官方授权，无需填写 Client ID 或密码到 Mineradio。';
    if (status) status.textContent = spotifyLoginStatusText();
    if (refresh) { refresh.textContent = spotifyOAuthBusy ? '等待 Spotify 授权…' : '连接 Spotify'; refresh.disabled = spotifyOAuthBusy || !spotifyLoginStatus.oauthConfigured; refresh.onclick = openSpotifyWebLogin; }
    return result;
  };
  var accountUI = updateUserModalUi;
  updateUserModalUi = function () {
    var result = accountUI.apply(this, arguments);
    if (userTab) { userTab.classList.toggle('active', activeAccountProvider === 'spotify'); userTab.style.display = hasPlatformLogin('spotify') ? '' : 'none'; }
    if (addAccount) addAccount.textContent = hasPlatformLogin('spotify') ? '重新连接 Spotify' : '连接 Spotify';
    return result;
  };
  var tabs = updateSearchModeTabs, setMode = setSearchMode;
  updateSearchModeTabs = function () {
    var result = tabs.apply(this, arguments);
    if (search) { search.classList.toggle('active', searchMode === 'spotify'); search.setAttribute('aria-selected', searchMode === 'spotify' ? 'true' : 'false'); }
    if (searchMode === 'spotify' && $input) $input.placeholder = '搜索 Spotify 曲目…';
    return result;
  };
  setSearchMode = function (mode) {
    if (mode !== 'spotify') return setMode.apply(this, arguments);
    if (searchMode === mode) return;
    searchMode = mode; updateSearchModeTabs(); clearSearchResults();
    var area = document.getElementById('search-area'); if (area) setPeek(area, true, 'search');
    var query = $input ? $input.value.trim() : ''; if (query) doSearch(query); else renderSearchHistory();
  };
  openSpotifyWebLogin = async function () {
    if (spotifyOAuthBusy || !spotifyLoginStatus.oauthConfigured) { updateLoginProviderUi(); return; }
    spotifyOAuthBusy = true; updateLoginProviderUi();
    var failure = '';
    if (window.__mineradioAppleSetAuthPresentation) window.__mineradioAppleSetAuthPresentation(true);
    try {
      var result = await bridge.postMessage({provider: 'spotify'});
      if (!result || !result.loggedIn) { failure = result && result.message || 'Spotify 授权未完成，可重试。'; return; }
      spotifyLoginStatus = normalizeSpotifyLoginStatus(result); activeAccountProvider = 'spotify';
      markLoginWorkflowConnected('spotify'); renderUserBtn(); await refreshUserPlaylists(true); await loadHomeDiscover(true);
      closeLoginModal(); showToast('Spotify 已连接');
    } catch (_) { failure = 'Spotify 连接未完成，请稍后重试。'; }
    finally {
      spotifyOAuthBusy = false; updateLoginProviderUi();
      if (window.__mineradioAppleSetAuthPresentation) window.__mineradioAppleSetAuthPresentation(false);
      var status = document.getElementById('qr-status'); if (failure && status) status.textContent = failure;
    }
  };
  async function disconnect() {
    var result = await apiJson('/api/spotify/logout', {method: 'POST'});
    if (!result || result.ok !== true) throw new Error('Spotify 退出未完成');
    spotifyLoginStatus = normalizeSpotifyLoginStatus(null); spotifyPlaylists = [];
    userPlaylists = userPlaylists.filter(function (list) { return list.provider !== 'spotify'; });
    if (typeof playlistCatalogRevision !== 'undefined') playlistCatalogRevision++;
    delete loginWorkflowVerifiedSession.spotify;
  }
  var logout = logoutActiveAccount;
  logoutActiveAccount = async function () {
    if (activeAccountProvider !== 'spotify') return logout.apply(this, arguments);
    try { await disconnect(); renderUserBtn(); updateLikeButtons(); closeUserModal(); await refreshUserPlaylists(true); await loadHomeDiscover(true); showToast('Spotify 已退出'); }
    catch (_) { showToast('Spotify 退出未完成，请重试'); }
  };
  var logoutAll = logoutAllAccountsAndResetEasterEgg;
  logoutAllAccountsAndResetEasterEgg = async function () {
    var confirmed = !logoutAllAccountsResetBusy && Date.now() <= logoutAllAccountsResetConfirmUntil;
    // Start both while the existing confirmation is still valid, and observe
    // all failures. The original routine owns its other four platform sessions.
    var pending = confirmed ? disconnect().then(function () { return true; }, function () { return false; }) : null;
    await logoutAll.apply(this, arguments);
    if (pending && !await pending) showToast('Spotify 退出未完成，请在账号面板重试');
    renderUserBtn();
  };
  refreshSpotifyLoginStatus().then(function () { if (loginProvider === 'spotify') updateLoginProviderUi(); }).catch(function () {});
  startSpotifyLoginStatusAutoRefresh();
})();
