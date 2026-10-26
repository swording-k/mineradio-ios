const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
function fixture(result, configured=true) {
  const nodes={}, calls=[];
  function element(){return {style:{},children:[],classList:{toggle(){},add(){},remove(){}},setAttribute(k,v){this[k]=v;},appendChild(child){child.parentNode=this;this.children.push(child);if(child.id)nodes[child.id]=child;},querySelector(){return null;},addEventListener(){}};}
  ['login-platform-tabs','search-mode-tabs','qr-status','login-modal-title','login-modal-desc','refresh-qr-btn','login-auth-drawer'].forEach(id=>nodes[id]=element());
  const ctx={window:{webkit:{messageHandlers:{appleAccountLogin:{postMessage:async input=>{calls.push(input);return result;}}}},__mineradioAppleSetAuthPresentation(){}},document:{getElementById:id=>nodes[id],querySelector:()=>null,createElement:element,head:element(),body:element()},
    normalizeAccountProviderKey:p=>p==='spotify'?'netease':p,normalizeLoginProviderKey:p=>p==='spotify'?'netease':p,
    hasAnyPlatformLogin:()=>false,loggedProviderCount:()=>0,hasPlatformLogin:p=>p==='spotify'&&ctx.spotifyLoginStatus.loggedIn,
    ACCOUNT_PROVIDER_KEYS:['netease','qq','kugou','qishui'],LOGIN_WORKFLOW_PROVIDERS:['netease','qq','kugou','qishui'],MUSIC_SEARCH_PROVIDER_ORDER:['netease','qq','kugou','qishui'],SEARCH_HISTORY_MODES:[],
    spotifyLoginStatus:{oauthConfigured:configured,loggedIn:false},spotifyOAuthBusy:false,loginProvider:'spotify',activeAccountProvider:'netease',
    updateLoginProviderUi(){},updateUserModalUi(){},updateSearchModeTabs(){},setSearchMode:p=>calls.push(p),searchModeProvider:()=>'',
    normalizeSpotifyLoginStatus:x=>x||{loggedIn:false},refreshSpotifyLoginStatus:async()=>ctx.spotifyLoginStatus,
    startSpotifyLoginStatusAutoRefresh(){},scheduleSpotifySetupAutoCheck(){},renderSpotifySetupWizard(){},renderUserBtn(){},
    refreshUserPlaylists:async()=>calls.push('library'),loadHomeDiscover:async()=>{},closeLoginModal:()=>calls.push('closed'),showToast(){},
    markLoginWorkflowConnected:p=>calls.push(p),apiJson:async()=>({ok:true}),logoutActiveAccount:async()=>calls.push('otherLogout'),
    logoutAllAccountsResetBusy:false,logoutAllAccountsResetConfirmUntil:0,logoutAllAccountsAndResetEasterEgg:async()=>{},
    spotifyPlaylists:[],userPlaylists:[],loginWorkflowVerifiedSession:{},closeUserModal(){},updateLikeButtons(){},
    setTimeout(){},clearSearchResults(){},renderSearchHistory(){},doSearch(){},setPeek(){},$input:{value:''},searchMode:'song'};
  if(fs.existsSync('apps/apple/Web/apple-spotify.js'))vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-spotify.js','utf8'),ctx);
  return {ctx,nodes,calls};
}
test('Spotify is a real fifth provider in login/search/account routing, without replacing existing providers',async()=>{
  const f=fixture({loggedIn:true,nickname:'Fixture'});
  assert.equal(f.ctx.normalizeLoginProviderKey('spotify'),'spotify');
  assert.equal(f.ctx.normalizeAccountProviderKey('spotify'),'spotify');
  assert.deepEqual(Array.from(f.ctx.ACCOUNT_PROVIDER_KEYS),['netease','qq','kugou','qishui','spotify']);
  assert(f.nodes['login-provider-spotify']);assert(f.nodes['search-mode-spotify']);
  await f.ctx.openSpotifyWebLogin();
  assert.equal(f.calls[0].provider,'spotify');assert(f.calls.includes('library'));assert(f.calls.includes('closed'));
  assert.equal(f.ctx.activeAccountProvider,'spotify');assert(f.ctx.hasAnyPlatformLogin());assert.equal(f.ctx.loggedProviderCount(),1);
  f.ctx.setSearchMode('spotify');assert.equal(f.ctx.searchMode,'spotify');assert.equal(f.ctx.searchModeProvider('spotify'),'spotify');
  await f.ctx.logoutActiveAccount();assert.equal(f.ctx.spotifyLoginStatus.loggedIn,false);assert(!f.calls.includes('otherLogout'));
});
test('missing app configuration and cancelled authentication never pretend a connected account',async()=>{
  const missing=fixture({loggedIn:true},false);await missing.ctx.openSpotifyWebLogin();
  assert.equal(missing.calls.length,0);assert.equal(missing.ctx.activeAccountProvider,'netease');
  const f=fixture({loggedIn:false,message:'已取消'});await f.ctx.openSpotifyWebLogin();
  assert(!f.calls.includes('library'));assert(!f.calls.includes('closed'));assert.equal(f.ctx.spotifyOAuthBusy,false);
  assert.equal(f.nodes['qr-status'].textContent,'已取消');
});
