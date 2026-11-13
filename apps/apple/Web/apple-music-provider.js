// Register Apple Music in the same account, playlist and search contracts as every other provider.
(function () {
  var bridge=window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.appleMusic;
  if(!bridge || window.__appleMusicProvider)return;window.__appleMusicProvider=true;
  var account={provider:'applemusic',loggedIn:false,nickname:'Apple Music'}, revision=0, appleLists=[], authorizing=false;
  function request(input){return bridge.postMessage(input).then(function(r){if(r && r.ok===false)throw new Error(r.message||'Apple Music 请求未完成');return r;});}
  function isApple(s){return !!s && (s.provider==='applemusic'||s.source==='applemusic'||s.type==='applemusic');}
  [ACCOUNT_PROVIDER_KEYS,LOGIN_WORKFLOW_PROVIDERS,MUSIC_SEARCH_PROVIDER_ORDER,SEARCH_HISTORY_MODES].forEach(function(a){if(a.indexOf('applemusic')<0)a.push('applemusic');});
  function include(original){return function(p){return p==='applemusic'?p:original.apply(this,arguments);};}
  normalizeAccountProviderKey=include(normalizeAccountProviderKey);normalizeLoginProviderKey=include(normalizeLoginProviderKey);
  normalizePlaybackProvider=include(normalizePlaybackProvider);normalizePlaylistProvider=include(normalizePlaylistProvider);searchModeProvider=include(searchModeProvider);
  var provider=songProviderKey,key=queueItemKey,label=songSourceLabel,meta=platformMeta,status=platformStatus,any=hasAnyPlatformLogin,count=loggedProviderCount;
  songProviderKey=function(s){return isApple(s)?'applemusic':provider.apply(this,arguments);};
  queueItemKey=function(s){return isApple(s)?'applemusic:'+String(s.id):key.apply(this,arguments);};
  songSourceLabel=function(s){return isApple(s)?'Apple Music':label.apply(this,arguments);};
  platformMeta=function(p){return p==='applemusic'?{key:p,short:'AM',label:'Apple Music',app:'Apple Music',dot:'applemusic'}:meta.apply(this,arguments);};
  platformStatus=function(p){return p==='applemusic'?account:status.apply(this,arguments);};
  hasAnyPlatformLogin=function(){return account.loggedIn||any.apply(this,arguments);};
  loggedProviderCount=function(){return count.apply(this,arguments)+(account.loggedIn?1:0);};
  var canSearch=searchProviderCanSearch,searchURL=searchProviderUrl;
  searchProviderCanSearch=function(p){return p==='applemusic'?account.loggedIn:canSearch.apply(this,arguments);};
  searchProviderUrl=function(p,q,limit,offset){return p==='applemusic'?'/api/applemusic/search?keywords='+encodeURIComponent(q)+'&limit='+limit+'&offset='+(offset||0):searchURL.apply(this,arguments);};
  var details=playlistTracksEndpoint,plLabel=playlistProviderLabel,plName=playlistProviderName;
  playlistTracksEndpoint=function(p,id,params){if(p!=='applemusic')return details.apply(this,arguments);return '/api/applemusic/playlist/tracks?'+new URLSearchParams(Object.assign({},params||{},{id:id}));};
  playlistProviderLabel=function(p){return p==='applemusic'?'AM':plLabel.apply(this,arguments);};
  playlistProviderName=function(p){return p==='applemusic'?'Apple Music':plName.apply(this,arguments);};
  var json=apiJson;
  apiJson=async function(url,opts){
    if(typeof url!=='string'||url.indexOf('/api/applemusic/')!==0)return json.apply(this,arguments);
    var parsed=new URL(url,'http://127.0.0.1'),q=parsed.searchParams;
    if(parsed.pathname==='/api/applemusic/lyric'){
      var song=playQueue.find(function(s){return isApple(s)&&String(s.id)===q.get('id');});
      if(!song || typeof findNeteaseLyricFallbackCandidate!=='function')return {lyric:''};
      var candidate=await findNeteaseLyricFallbackCandidate(song);
      // Never apply a vaguely similar song's lyrics. Version/artist and duration must agree.
      if(!candidate || typeof isSameTitleArtist!=='function'||!isSameTitleArtist(song,candidate))return {lyric:''};
      var seconds=Number(candidate.duration||candidate.dt/1000||0);
      if(seconds>10000)seconds/=1000;
      if(song.duration>0&&seconds>0&&Math.abs(song.duration-seconds)>8)return {lyric:''};
      var payload=await json('/api/lyric?id='+encodeURIComponent(candidate.id),opts||{});
      song.lyricMatchedSource='网易云匹配歌词';
      if(typeof showToast==='function')showToast('歌词来自网易云匹配，Apple Music 音源保持不变');
      return payload;
    }
    var action=parsed.pathname.endsWith('/search')?'search':parsed.pathname.endsWith('/playlist/tracks')?'tracks':'library';
    return request({action:action,id:q.get('id'),query:q.get('keywords'),offset:Number(q.get('offset'))||0,limit:Number(q.get('limit'))||50});
  };
  var lyric=lyricEndpointForSong;
  lyricEndpointForSong=function(s){return isApple(s)?'/api/applemusic/lyric?id='+encodeURIComponent(s.id):lyric.apply(this,arguments);};
  function button(id,text,parent,click){if(!parent)return null;var b=document.createElement('button');b.id=id;b.type='button';b.textContent=text;b.onclick=click;parent.appendChild(b);return b;}
  var login=button('login-provider-applemusic','',document.getElementById('login-platform-tabs'),function(){selectLoginProviderNode('applemusic');authorize();});
  if(login){login.className='applemusic workflow-node';login.setAttribute('data-login-provider','applemusic');login.innerHTML='<span class="provider-logo">AM</span><b>Apple Music</b><small>系统授权</small><span class="flow-port out" data-login-provider-output="applemusic" title="连接 Apple Music"></span>';}
  var search=button('search-mode-applemusic','AM',document.getElementById('search-mode-tabs'),function(){setSearchMode('applemusic');});
  var user=button('user-provider-applemusic','Apple Music',document.querySelector('#user-modal .user-platform-tabs'),function(){setActiveAccountProvider('applemusic');});
  button('account-add-applemusic','连接 Apple Music',document.querySelector('#user-modal .account-modal-actions'),function(){openProviderLogin('applemusic');});
  var style=document.createElement('style');style.textContent='body.apple-client .applemusic{color:#fa586a}body.apple-client .applemusic-selected #login-mode-cookie,body.apple-client .applemusic-selected #qr-img,body.apple-client .applemusic-selected #qq-cookie-toggle-btn{display:none!important}body.apple-client .applemusic-selected .login-auth-actions{display:flex!important}body.apple-client .applemusic-selected #refresh-qr-btn{display:block!important;min-height:44px}';document.head.appendChild(style);
  async function library(){
    if(!account.loggedIn)return;var generation=revision,result=await request({action:'library'});
    if(generation!==revision||!account.loggedIn)return;
    if(typeof result.canPlay==='boolean')account.canPlay=result.canPlay;
    appleLists=result.playlists||[];
    userPlaylists=userPlaylists.filter(function(p){return p.provider!=='applemusic';}).concat(appleLists);
    if(typeof playlistCatalogRevision!=='undefined')playlistCatalogRevision++;
    if(typeof renderUserPlaylistsList==='function')renderUserPlaylistsList({preserveScroll:true});
    if(typeof safeShelfRebuild==='function')safeShelfRebuild('applemusic-library');
  }
  if(typeof rebuildUserPlaylistsFromCatalog==='function') {
    var rebuild=rebuildUserPlaylistsFromCatalog;
    rebuildUserPlaylistsFromCatalog=function(){
      var r=rebuild.apply(this,arguments);
      if(account.loggedIn){userPlaylists=userPlaylists.filter(function(p){return p.provider!=='applemusic';}).concat(appleLists);playlistCatalogRevision++;renderUserPlaylistsList({preserveScroll:true});}
      return r;
    };
  }
  async function authorize(){
    if(authorizing)return;authorizing=true;
    try{account=await request({action:'authorize'});if(!account.loggedIn)throw new Error(account.message||'尚未授权');
      activeAccountProvider='applemusic';markLoginWorkflowConnected('applemusic');renderUserBtn();await library();closeLoginModal();showToast('Apple Music 已连接，歌单已同步');
    }catch(e){var n=document.getElementById('qr-status');if(n)n.textContent=e.message;}
    finally{authorizing=false;}
  }
  var update=updateLoginProviderUi,select=selectLoginProviderNode,open=openProviderLogin,connect=connectLoginProviderToMr,mode=connectLoginMode;
  updateLoginProviderUi=function(){var r=update.apply(this,arguments),selected=loginProvider==='applemusic';
    var drawer=document.getElementById('login-auth-drawer');if(drawer)drawer.classList.toggle('applemusic-selected',selected);
    var modal=document.getElementById('login-modal');if(modal)modal.classList.toggle('applemusic-selected',selected);
    var official=document.querySelector('#login-mode-official b');if(official)official.textContent=selected?'系统授权':'扫码';
    if(login)login.classList.toggle('active',selected);
    if(selected){var title=document.getElementById('login-modal-title');if(title)title.textContent='连接 Apple Music';var qr=document.getElementById('qr-status');if(qr)qr.textContent=account.loggedIn?'Apple Music 已授权，歌单在“我的歌单”中显示':'使用系统 Apple Music 授权，无需扫码。';var refresh=document.getElementById('refresh-qr-btn');if(refresh){refresh.disabled=false;refresh.textContent='授权 Apple Music';refresh.onclick=authorize;}}
    return r;
  };
  selectLoginProviderNode=function(p){if(p!=='applemusic')return select.apply(this,arguments);loginProvider=p;setLoginAuthDrawerOpen(true);updateLoginProviderUi();};
  connectLoginProviderToMr=function(p){if(p!=='applemusic')return connect.apply(this,arguments);selectLoginProviderNode(p);return authorize();};
  connectLoginMode=function(m){if(loginProvider!=='applemusic')return mode.apply(this,arguments);return authorize();};
  openProviderLogin=async function(p){if(p!=='applemusic')return open.apply(this,arguments);if(typeof closeUserModal==='function')closeUserModal();await showLoginModal({provider:'applemusic'});selectLoginProviderNode(p);};
  var setMode=setSearchMode,tabs=updateSearchModeTabs;
  setSearchMode=function(p){if(p!=='applemusic')return setMode.apply(this,arguments);searchMode=p;updateSearchModeTabs();clearSearchResults();if(typeof $input!=='undefined'&&$input.value.trim())doSearch($input.value.trim());};
  updateSearchModeTabs=function(){var r=tabs.apply(this,arguments);if(search){search.classList.toggle('active',searchMode==='applemusic');search.setAttribute('aria-selected',searchMode==='applemusic'?'true':'false');}return r;};
  var refresh=refreshUserPlaylists;
  refreshUserPlaylists=async function(){var r=await refresh.apply(this,arguments);await library();return r;};
  var logout=logoutActiveAccount;
  logoutActiveAccount=async function(){if(activeAccountProvider!=='applemusic')return logout.apply(this,arguments);await request({action:'logout'});revision++;account={provider:'applemusic',loggedIn:false,nickname:'Apple Music'};userPlaylists=userPlaylists.filter(function(p){return p.provider!=='applemusic';});renderUserBtn();closeUserModal();showToast('已断开 Apple Music；系统授权可在设置中撤销');};
  var selectAccount=setActiveAccountProvider;
  setActiveAccountProvider=function(p){if(p!=='applemusic')return selectAccount.apply(this,arguments);activeAccountProvider=p;updateUserModalUi();};
  var allLogout=logoutAllAccountsAndResetEasterEgg;
  logoutAllAccountsAndResetEasterEgg=async function(){
    var confirmed=typeof logoutAllAccountsResetBusy!=='undefined'&&!logoutAllAccountsResetBusy&&Date.now()<=logoutAllAccountsResetConfirmUntil;
    if(confirmed){await request({action:'logout'});revision++;account={provider:'applemusic',loggedIn:false,nickname:'Apple Music'};userPlaylists=userPlaylists.filter(function(p){return p.provider!=='applemusic';});}
    return allLogout.apply(this,arguments);
  };
  var userUI=updateUserModalUi;
  updateUserModalUi=function(){var r=userUI.apply(this,arguments);if(user)user.style.display=account.loggedIn?'':'none';if(activeAccountProvider==='applemusic'){var n=document.getElementById('user-modal-vip');if(n)n.textContent=account.canPlay?'Apple Music 订阅可用':'Apple Music 已授权';}return r;};
  request({action:'status'}).then(function(r){account=r;renderUserBtn();return library();}).catch(function(){});
})();
