// Apple-only 波点目录与播放桥；凭据留在 Swift，网页只接收账号和歌曲元数据。
(function installAppleBodian() {
  if (window.__mineradioAppleBodian) return;
  window.__mineradioAppleBodian = true;
  var account = {provider:'bodian',loggedIn:false,publicCatalog:true,nickname:'波点音乐'}, generation=0, timer=0;
  var isBodian = function(s) { return !!s && (s.provider==='bodian'||s.source==='bodian'||s.type==='bodian'); };
  [ACCOUNT_PROVIDER_KEYS,LOGIN_WORKFLOW_PROVIDERS,MUSIC_SEARCH_PROVIDER_ORDER,SEARCH_HISTORY_MODES].forEach(function(a){if(a.indexOf('bodian')<0)a.push('bodian');});
  function include(original){return function(p){return p==='bodian'?'bodian':original.apply(this,arguments);};}
  normalizeAccountProviderKey=include(normalizeAccountProviderKey); normalizeLoginProviderKey=include(normalizeLoginProviderKey);
  normalizePlaybackProvider=include(normalizePlaybackProvider); normalizePlaylistProvider=include(normalizePlaylistProvider); searchModeProvider=include(searchModeProvider);
  var playbackLabel=typeof playbackProviderLabel==='function'?playbackProviderLabel:null;
  if(playbackLabel)playbackProviderLabel=function(s){return isBodian(s)?'波点音乐':playbackLabel.apply(this,arguments);};
  var provider=songProviderKey,key=queueItemKey,label=songSourceLabel,meta=platformMeta,status=platformStatus,any=hasAnyPlatformLogin,count=loggedProviderCount;
  songProviderKey=function(s){return isBodian(s)?'bodian':provider.apply(this,arguments);};
  queueItemKey=function(s){return isBodian(s)?'bodian:'+String(s.id||s.mediaId||''):key.apply(this,arguments);};
  songSourceLabel=function(s){return isBodian(s)?'波点音乐':label.apply(this,arguments);};
  platformMeta=function(p){return p==='bodian'?{key:p,short:'BD',label:'波点音乐',app:'波点音乐 App',dot:'bodian'}:meta.apply(this,arguments);};
  platformStatus=function(p){return p==='bodian'?account:status.apply(this,arguments);};
  hasAnyPlatformLogin=function(){return account.loggedIn||any.apply(this,arguments);};
  loggedProviderCount=function(){return count.apply(this,arguments)+(account.loggedIn?1:0);};
  var canSearch=searchProviderCanSearch,searchURL=searchProviderUrl;
  searchProviderCanSearch=function(p){return p==='bodian'?true:canSearch.apply(this,arguments);};
  searchProviderUrl=function(p,q,limit,offset){return p==='bodian'?'/api/bodian/search?keywords='+encodeURIComponent(q)+'&limit='+limit+'&offset='+(offset||0):searchURL.apply(this,arguments);};
  var lyricURL=lyricEndpointForSong,detailURL=playlistTracksEndpoint,playlistLabel=playlistProviderLabel,playlistName=playlistProviderName;
  lyricEndpointForSong=function(s){return isBodian(s)?'/api/bodian/lyric?id='+encodeURIComponent(s.id||s.mediaId):lyricURL.apply(this,arguments);};
  playlistTracksEndpoint=function(p,id,params){if(p!=='bodian')return detailURL.apply(this,arguments);var q=new URLSearchParams(Object.assign({},params||{},{id:id}));return '/api/bodian/playlist/tracks?'+q;};
  playlistProviderLabel=function(p){return p==='bodian'?'BD':playlistLabel.apply(this,arguments);};
  playlistProviderName=function(p){return p==='bodian'?'波点音乐':playlistName.apply(this,arguments);};
  // 原版的普通播放和 gapless 两条路径都会用此歌曲专属 query。标记随请求传递，
  // 不用“当前队列”的全局状态猜来源，避免预取下一首时把网易同 ID 歌曲误路由。
  var matchQuery=neteasePlaybackMatchQuery,json=apiJson;
  neteasePlaybackMatchQuery=function(s){return isBodian(s)?'&apple_provider=bodian':matchQuery.apply(this,arguments);};
  apiJson=function(url,opts){
    if(typeof url==='string'&&url.indexOf('/api/song/url?')===0){
      var q=new URLSearchParams(url.slice(url.indexOf('?')+1));
      if(q.get('apple_provider')==='bodian'){q.delete('apple_provider');url='/api/bodian/song/url?'+q.toString();}
    }
    return json.call(this,url,opts);
  };
  function button(id,text,parent,click){if(!parent)return null;var b=document.createElement('button');b.id=id;b.type='button';b.textContent=text;b.className='bodian workflow-node';b.onclick=click;parent.appendChild(b);return b;}
  var loginButton=button('login-provider-bodian','波点音乐',document.getElementById('login-platform-tabs'),function(){openProviderLogin('bodian');});
  if(loginButton)loginButton.setAttribute('data-login-provider','bodian');
  var searchButton=button('search-mode-bodian','BD',document.getElementById('search-mode-tabs'),function(){searchMode='bodian';if(typeof updateSearchModeTabs==='function')updateSearchModeTabs();if(typeof clearSearchResults==='function')clearSearchResults();if(typeof $input!=='undefined'&&$input.value.trim())doSearch($input.value.trim());});
  var originalSearchUI=typeof updateSearchModeTabs==='function'?updateSearchModeTabs:null;
  if(originalSearchUI)updateSearchModeTabs=function(){var r=originalSearchUI.apply(this,arguments);if(searchButton){searchButton.classList.toggle('active',searchMode==='bodian');searchButton.setAttribute('aria-selected',searchMode==='bodian'?'true':'false');}if(searchMode==='bodian'&&typeof $input!=='undefined')$input.placeholder='搜索波点音乐…';return r;};
  button('account-add-bodian','连接波点音乐',document.querySelector('#user-modal .account-modal-actions'),function(){openProviderLogin('bodian');});
  function text(id,value){var n=document.getElementById(id);if(n)n.textContent=value;}
  function cancel(){generation++;if(timer)clearTimeout(timer);timer=0;}
  async function refresh(){var gen=generation;try{var result=await apiJson('/api/bodian/login/status');if(gen!==generation)return account;account=Object.assign({provider:'bodian',loggedIn:false,publicCatalog:true},result);if(typeof renderUserBtn==='function')renderUserBtn();}catch(_){}return account;}
  async function library(){
    if(!account.loggedIn)return;
    var gen=generation,result=await apiJson('/api/bodian/user/playlists');
    if(gen!==generation||!account.loggedIn)return;
    var rows=(result.playlists||[]).map(function(p){return Object.assign({},p,{provider:'bodian'});});
    userPlaylists=userPlaylists.filter(function(p){return p.provider!=='bodian';}).concat(rows);
    if(typeof playlistCatalogRevision!=='undefined')playlistCatalogRevision++;
    if(typeof renderUserPlaylistsList==='function')renderUserPlaylistsList({preserveScroll:true});
  }
  async function start(){
    cancel();var gen=generation; text('qr-status','正在生成波点二维码…');
    try{
      var qr=await apiJson('/api/bodian/login/qr/key');if(gen!==generation)return;
      if(!qr.key||!qr.qrimg)throw new Error(qr.message||'二维码暂不可用，请重试');
      var img=document.getElementById('qr-img');if(img){img.src=qr.qrimg;img.alt='波点音乐登录二维码';}
      async function poll(){
        if(gen!==generation)return;
        try{
          var r=await apiJson('/api/bodian/login/qr/check?key='+encodeURIComponent(qr.key));if(gen!==generation)return;
          text('qr-status',r.message||'请用波点音乐 App 扫码');
          if(r.code===803||r.status==='confirmed'){
            await refresh();if(!account.loggedIn)throw new Error('账号校验未完成，请重新扫码');
            await library();cancel();closeLoginModal();if(typeof showToast==='function')showToast('波点音乐已连接');return;
          }
          if(r.code===800||r.status==='expired')return;
          timer=setTimeout(poll,2000);
        }catch(e){if(gen===generation)text('qr-status',e.message||'扫码状态获取失败，请重试');}
      }
      text('qr-status','请使用波点音乐 App 扫码');timer=setTimeout(poll,1500);
    }catch(e){if(gen===generation)text('qr-status',e.message||'二维码生成失败，请重试');}
  }
  var open=openProviderLogin,update=updateLoginProviderUi,close=closeLoginModal,select=selectLoginProviderNode;
  selectLoginProviderNode=function(p){cancel();if(p!=='bodian')return select.apply(this,arguments);loginProvider='bodian';if(typeof setLoginAuthDrawerOpen==='function')setLoginAuthDrawerOpen(true);updateLoginProviderUi();start();};
  openProviderLogin=async function(p){if(p!=='bodian'){cancel();return open.apply(this,arguments);}if(typeof closeUserModal==='function')closeUserModal();await showLoginModal({provider:'bodian'});if(typeof loginEasterEggState!=='undefined'&&(!loginEasterEggState.ready||!loginEasterEggState.unlocked))return;loginProvider='bodian';if(typeof setLoginAuthDrawerOpen==='function')setLoginAuthDrawerOpen(true);updateLoginProviderUi();start();};
  updateLoginProviderUi=function(){var r=update.apply(this,arguments);if(loginButton)loginButton.classList.toggle('active',loginProvider==='bodian');if(loginProvider==='bodian'){text('login-modal-title','连接波点音乐');text('login-modal-desc','请使用波点音乐 App 扫码登录');var b=document.getElementById('refresh-qr-btn');if(b){b.disabled=false;b.textContent='刷新二维码';b.onclick=start;}}return r;};
  closeLoginModal=function(){cancel();return close.apply(this,arguments);};
  var playlists=refreshUserPlaylists;
  refreshUserPlaylists=async function(){var r=await playlists.apply(this,arguments);await library();return r;};
  var logout=logoutActiveAccount;
  logoutActiveAccount=async function(){if(activeAccountProvider!=='bodian')return logout.apply(this,arguments);cancel();await apiJson('/api/bodian/logout',{method:'POST'});account={provider:'bodian',loggedIn:false,publicCatalog:true};userPlaylists=userPlaylists.filter(function(p){return p.provider!=='bodian';});renderUserBtn();};
  button('account-logout-bodian','退出波点音乐',document.querySelector('#user-modal .account-modal-actions'),function(){activeAccountProvider='bodian';logoutActiveAccount();});
  var logoutAll=logoutAllAccountsAndResetEasterEgg;
  logoutAllAccountsAndResetEasterEgg=async function(){var confirmed=typeof logoutAllAccountsResetBusy!=='undefined'&&!logoutAllAccountsResetBusy&&Date.now()<=logoutAllAccountsResetConfirmUntil;var pending=confirmed?apiJson('/api/bodian/logout',{method:'POST'}).then(function(){cancel();account={provider:'bodian',loggedIn:false,publicCatalog:true};return true;},function(){return false;}):null;await logoutAll.apply(this,arguments);if(pending&&!await pending&&typeof showToast==='function')showToast('波点音乐退出未完成，请重试');};
  refresh().then(library).catch(function(){});
})();
