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
  var callback = 'com.swordingk.mineradio.apple://spotify/callback';
  var setup = document.createElement('div'); setup.id = 'apple-spotify-setup';
  var help = document.createElement('p'); help.textContent = '与安卓端相同：先在 Spotify Developer Dashboard 创建应用，将下方回调登记到该应用，再填写公开 Client ID。不要填写密码或 Client Secret。';
  var dashboard = document.createElement('a'); dashboard.href = 'https://developer.spotify.com/dashboard'; dashboard.textContent = '打开 Spotify 开发者后台'; dashboard.target = '_blank';
  var input = document.createElement('input'); input.id = 'apple-spotify-client-id'; input.type = 'text'; input.placeholder = 'Spotify Client ID（32 位公开编号）'; input.maxLength = 32; input.autocomplete = 'off'; input.setAttribute('aria-label', 'Spotify Client ID');
  var uri = document.createElement('code'); uri.textContent = callback;
  var copy = document.createElement('button'); copy.type = 'button'; copy.textContent = '复制 iOS 回调地址';
  copy.onclick = async function () { try { await window.navigator.clipboard.writeText(callback); showToast('回调地址已复制'); } catch (_) { showToast('请长按上方回调地址复制'); } };
  var save = document.createElement('button'); save.type = 'button'; save.textContent = '保存并授权';
  [help,dashboard,input,uri,copy,save].forEach(function(n){setup.appendChild(n);}); panel.appendChild(setup);
  var configBusy = false;
  window.__mineradioAppleSaveSpotifyConfig = async function (value) {
    var id = String(value || '').trim();
    if (!/^[0-9a-f]{32}$/i.test(id)) throw new Error('请输入 32 位 Spotify Client ID，不是账号或密码。');
    var result = await apiJson('/api/spotify/config', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({clientId:id})});
    if (!result || result.ok !== true) throw new Error(result && result.message || '配置未能保存，请重试。');
    spotifyLoginStatus = Object.assign({}, spotifyLoginStatus, result);
    input.value = result.clientId || id;
    updateLoginProviderUi();
    return result;
  };
  save.onclick = async function () {
    if (configBusy || spotifyOAuthBusy) return;
    configBusy = true; save.disabled = true;
    try { await window.__mineradioAppleSaveSpotifyConfig(input.value); await openSpotifyWebLogin(); }
    catch (e) { var status = document.getElementById('qr-status'); if (status) status.textContent = e.message || '配置保存失败'; }
    finally { configBusy = false; save.disabled = false; }
  };
  var style = document.createElement('style');
  style.textContent = 'body.apple-client #apple-spotify-setup{display:grid;gap:12px}body.apple-client #apple-spotify-setup input{box-sizing:border-box;width:100%;min-height:44px;padding:10px;border:1px solid #ffffff40;border-radius:10px;background:#ffffff10;color:inherit;font-size:16px}body.apple-client #apple-spotify-setup button{min-height:44px}body.apple-client #apple-spotify-setup code{overflow-wrap:anywhere;user-select:text}body.apple-client #apple-spotify-setup a{color:#1ed760;min-height:44px} body.apple-client #login-provider-spotify{color:#1ed760;min-height:52px}body.apple-client #apple-spotify-info{display:none;padding:12px 0;font-size:13px;line-height:1.7;color:rgba(255,255,255,.65)}body.apple-client .apple-spotify-selected #apple-spotify-info{display:block}body.apple-client .apple-spotify-selected > .login-auth-copy{display:block}body.apple-client .apple-spotify-selected > .login-auth-actions{display:flex;flex-wrap:wrap}body.apple-client .apple-spotify-selected .login-auth-body,body.apple-client .apple-spotify-selected #qq-cookie-toggle-btn{display:none!important}body.apple-client #search-mode-tabs{overflow-x:auto;max-width:100%;overscroll-behavior-x:contain}body.apple-client #search-mode-tabs button{flex-shrink:0}';
  document.head.appendChild(style);
  // Desktop's developer setup wizard/loopback check is not an end-user login
  // flow on iOS. The application registration is supplied by the team at build.
  scheduleSpotifySetupAutoCheck = function () {};
  renderSpotifySetupWizard = function () {};
  spotifyLoginStatusText = function (info) {
    info = info || spotifyLoginStatus;
    if (info.loggedIn) return 'Spotify 已连接 · ' + (info.nickname || '账号') + ' · 播放采用匹配源';
    return info.oauthConfigured ? '点击“连接 Spotify”，在系统授权窗口登录。' : '请填写自己的 Spotify Client ID，保存后即可打开官方授权。';
  };
  var originalUI = updateLoginProviderUi;
  updateLoginProviderUi = function () {
    var result = originalUI.apply(this, arguments), selected = loginProvider === 'spotify';
    if (drawer) drawer.classList.toggle('apple-spotify-selected', selected);
    if (login) login.classList.toggle('active', selected);
    if (!selected) return result;
    var title = document.getElementById('login-modal-title'), desc = document.getElementById('login-modal-desc'), status = document.getElementById('qr-status'), refresh = document.getElementById('refresh-qr-btn');
    if (title) title.textContent = '连接 Spotify';
    if (desc) desc.textContent = '填写自己的 Client ID 后使用 Spotify 官方页面登录；账号密码只在 Spotify 输入。';
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
  apiJson('/api/spotify/config').then(function(c){if(c && c.clientId)input.value=c.clientId;}).catch(function(){});
  refreshSpotifyLoginStatus().then(function () { if (loginProvider === 'spotify') updateLoginProviderUi(); }).catch(function () {});
  startSpotifyLoginStatusAutoRefresh();
})();
