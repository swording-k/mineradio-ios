const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
function fixture(){
 const requests=[],nodes={};const node=()=>({children:[],attributes:{},classList:{add(){},toggle(){}},appendChild(n){this.children.push(n);},setAttribute(k,v){this.attributes[k]=v;},style:{},querySelector:()=>null});
 const c={URL,URLSearchParams,window:{webkit:{messageHandlers:{appleMusic:{postMessage:async p=>{requests.push(p);if(p.action==='status')return {loggedIn:false};if(p.action==='authorize')return {provider:'applemusic',loggedIn:true};if(p.action==='library')return {playlists:[{id:'am-list',provider:'applemusic',name:'AM List'}]};return {ok:true,tracks:[{id:'am-song',provider:'applemusic'}]};}}}}},document:{createElement:node,getElementById:id=>nodes[id]||(nodes[id]=node()),querySelector:()=>node(),head:node()},
 ACCOUNT_PROVIDER_KEYS:[],LOGIN_WORKFLOW_PROVIDERS:[],MUSIC_SEARCH_PROVIDER_ORDER:[],SEARCH_HISTORY_MODES:[],userPlaylists:[{id:'ne',provider:'netease'}],loginProvider:'netease',activeAccountProvider:'netease',searchMode:'all',playQueue:[],
 apiJson:async(url)=>{requests.push(url);return {lyric:'[00:01.00]Lyrics'};},setTimeout:()=>1,clearTimeout(){},console};
 for(const k of ['normalizeAccountProviderKey','normalizeLoginProviderKey','searchModeProvider','normalizePlaybackProvider','normalizePlaylistProvider'])c[k]=()=> 'netease';
 for(const k of ['songProviderKey','queueItemKey','songSourceLabel','playlistProviderLabel','playlistProviderName','platformMeta','platformStatus','hasAnyPlatformLogin','loggedProviderCount','searchProviderCanSearch','searchProviderUrl','playlistTracksEndpoint','lyricEndpointForSong','openProviderLogin','selectLoginProviderNode','connectLoginProviderToMr','connectLoginMode','closeLoginModal','updateLoginProviderUi','setSearchMode','updateSearchModeTabs','refreshUserPlaylists','logoutActiveAccount','updateUserModalUi','setActiveAccountProvider','renderUserBtn','setLoginAuthDrawerOpen','markLoginWorkflowConnected','showToast','logoutAllAccountsAndResetEasterEgg'])c[k]=()=>'';
 vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-music-provider.js','utf8'),c);return {c,requests,nodes};
}
test('Apple Music uses the same workflow card, provider identity and playlist route',()=>{const {c,nodes}=fixture();const card=nodes['login-platform-tabs'].children.find(n=>n.id==='login-provider-applemusic');assert.equal(card.attributes['data-login-provider'],'applemusic');assert.match(card.innerHTML,/flow-port out/);assert.equal(c.normalizePlaylistProvider('applemusic'),'applemusic');assert.equal(c.songProviderKey({provider:'applemusic'}),'applemusic');assert.match(c.playlistTracksEndpoint('applemusic','p',{}),/\/api\/applemusic\/playlist\/tracks\?/);});
test('system authorization merges Apple Music playlists into existing collection',async()=>{const {c,requests}=fixture();await Promise.resolve();await Promise.resolve();c.selectLoginProviderNode('applemusic');await c.connectLoginMode('official');assert(c.userPlaylists.some(p=>p.provider==='netease'));assert(c.userPlaylists.some(p=>p.provider==='applemusic'));assert(requests.some(p=>p.action==='authorize'));assert.equal(c.activeAccountProvider,'applemusic');});
test('playlist requests and search requests stay on MusicKit, not NetEase IDs',async()=>{const {c,requests}=fixture();await c.apiJson('/api/applemusic/playlist/tracks?id=list&offset=50&limit=50');assert.equal(requests.at(-1).action,'tracks');assert.equal(requests.at(-1).offset,50);await c.apiJson('/api/applemusic/search?keywords=Song');assert.equal(requests.at(-1).action,'search');});
test('lyrics reject nonmatching candidates instead of borrowing an unrelated song',async()=>{const {c,requests}=fixture();c.playQueue=[{id:'a',provider:'applemusic',name:'Song'}];c.findNeteaseLyricFallbackCandidate=async()=>({id:99});c.isSameTitleArtist=()=>false;const r=await c.apiJson('/api/applemusic/lyric?id=a');assert.equal(r.lyric,'');assert(!requests.some(p=>typeof p==='string'&&p.startsWith('/api/lyric')));});
test('actual virtual playlist renderer includes extension providers in visible entries',()=>{
 const source=fs.readFileSync('public/js/modules/06-lyrics/02-playlist-detail.js','utf8');
 const fn=source.slice(source.indexOf('function playlistPanelBuildVirtualEntries()'),source.indexOf('function playlistPanelOffsetIndex('));
 const c={playlistPanelDetailState:{key:'',tracks:[]},playlistPanelVirtualCache:{revision:-1},playlistCatalogRevision:1,userPlaylists:[{provider:'netease',id:'n'},{provider:'applemusic',id:'a'}],playlistPanelGroupKey:p=>p.provider,playlistCardPriority:()=>0,normalizePlaylistProvider:p=>p,playlistPanelKey:(p,id)=>p+':'+id,playlistPanelDetailShellHeight:()=>0,playlistProviderName:p=>p==='applemusic'?'Apple Music':p};
 vm.runInNewContext(fn,c);const rows=c.playlistPanelBuildVirtualEntries().entries;
 assert(rows.some(e=>e.type==='card'&&e.pl.provider==='applemusic'));
 assert.equal(rows.filter(e=>e.type==='card').length,2);
});
test('actual aggregated search retains Apple Music results instead of dropping unknown providers',async()=>{
 const {c}=fixture(),source=fs.readFileSync('public/js/modules/05-playback/07-search.js','utf8');
 c.MUSIC_SEARCH_MAX_RESULTS=100;c.activeSearchProvidersForMode=()=>['applemusic'];c.scoreSongSearchResult=()=>100;c.searchCanonicalSongKey=s=>s.name;
 c.apiJson=async()=>({songs:[{id:'a',name:'Apple song',provider:'applemusic'}],hasMore:false});
 vm.runInNewContext(source.slice(source.indexOf('function mergeSongSearchResults('),source.indexOf('function mergeUniqueSearchSongPools(')),c);
 vm.runInNewContext(source.slice(source.indexOf('async function fetchMusicSearchResults('),source.indexOf('function searchSongResultHtml(')),c);
 const result=await c.fetchMusicSearchResults('Apple song','applemusic');assert.equal(result.songs[0].provider,'applemusic');
});
