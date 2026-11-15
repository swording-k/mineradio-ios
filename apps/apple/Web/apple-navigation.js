// A touch library over the existing provider contracts and single playback queue.
(function () {
  if (window.__mineradioNavigation || !document.body) return;
  var body=document.body, screen='library', tab='library', selected=null, tracks=[], page=null;
  var detailTracks=[],detailPage=null,searchTracks=[],rowOffsets={};
  var filter='all', query='', generation=0, loading=false, scroll=0, searchPages=null, shown=60;
  var root=document.createElement('section');root.id='mr-browser';root.setAttribute('aria-label','音乐资料库');
  root.innerHTML='<header><div><small>MINERADIO</small><h1>我的歌单</h1></div><div class="mr-header-actions"><button data-act="connect" aria-label="连接音乐平台">平台</button><button data-act="stage" id="mr-close" aria-label="关闭歌单，返回播放">返回播放 ⌄</button></div></header><nav aria-label="音乐导航"><button data-view="library">歌单</button><button data-view="search">搜索</button><button data-view="queue">播放队列</button></nav><div id="mr-tools"></div><div id="mr-content" tabindex="-1"></div><footer id="mr-mini" hidden><button data-act="stage" id="mr-mini-info" aria-label="打开播放舞台"><img alt=""><span><b></b><small></small></span></button><button data-act="toggle" aria-label="播放或暂停">播放</button><button data-act="next" aria-label="下一首">下一首</button></footer>';
  body.appendChild(root);
  // One canonical entry; the legacy button has an addEventListener as well as
  // onclick. Remove that node rather than leaving both handlers attached.
  var oldLibrary=document.getElementById('apple-library-btn');if(oldLibrary)oldLibrary.remove();
  var returnButton=document.getElementById('home-btn');
  if(!returnButton){returnButton=document.createElement('button');returnButton.id='home-btn';body.appendChild(returnButton);}
  returnButton.removeAttribute('onclick');
  returnButton.innerHTML='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h10" stroke-linecap="round"/></svg>';
  returnButton.setAttribute('aria-label','返回歌单');returnButton.title='歌单';
  returnButton.onclick=function(e){e.preventDefault();e.stopPropagation();navigate('library');};
  // Narrow landscape: register the original DIY switch as a real toolbar item.
  // Its desktop screen coordinates otherwise sit underneath the account strip.
  var diyZone=document.getElementById('fullscreen-diy-zone'),accountButton=document.getElementById('user-btn');
  if(diyZone&&accountButton){
    var anchor=document.createComment('DIY portrait position');diyZone.before(anchor);
    var shortLandscape=window.matchMedia('(orientation: landscape) and (max-height: 500px) and (max-width: 1024px)');
    function placeDiy(){if(shortLandscape.matches)accountButton.before(diyZone);else anchor.after(diyZone);}
    shortLandscape.addEventListener('change',placeDiy);placeDiy();
  }
  var content=root.querySelector('#mr-content'),tools=root.querySelector('#mr-tools'),mini=root.querySelector('#mr-mini');
  function el(tag,text){var n=document.createElement(tag);if(text)n.textContent=text;return n;}
  function button(text,fn){var n=el('button',text);n.type='button';n.onclick=fn;return n;}
  function note(text,retry){content.replaceChildren(el('p',text));if(retry)content.appendChild(button('重试',retry));}
  function song(){return typeof playQueue!=='undefined'&&playQueue[currentIdx]||null;}
  function openStage(){navigate('stage');}
  function navigate(next){
    if(screen!=='stage')scroll=content.scrollTop;
    screen=next;root.querySelector('h1').textContent=next==='search'?'搜索':next==='queue'?'正在播放':'我的歌单';body.classList.toggle('mr-browsing',screen!=='stage');
    if(next!=='stage'){if(typeof closeVisualGuide==='function')closeVisualGuide(false);if(typeof toggleFxPanel==='function')toggleFxPanel(false);if(typeof togglePlaylistPanel==='function')togglePlaylistPanel(false);tab=next;root.hidden=false;if(next==='queue'){queueUI();}else if(next==='search'){tracks=searchTracks;searchUI();}else if(selected){tracks=detailTracks;page=detailPage;if(selected.provider==='local')localLibrary();else detailUI();}else libraryUI();content.scrollTop=scroll;}
    else {root.hidden=true;if(typeof dismissHomePage==='function')dismissHomePage();if(typeof updateEmptyHomeVisibility==='function')updateEmptyHomeVisibility();if(typeof markRenderInteraction==='function')markRenderInteraction('mobile-stage',900);}
    returnButton.hidden=screen!=='stage';body.classList.toggle('mr-stage',screen==='stage');
    root.querySelectorAll('[data-view]').forEach(function(n){var active=n.dataset.view===screen;n.setAttribute('aria-selected',active?'true':'false');});
    if(typeof window.__mineradioApplePushNativeState==='function')window.__mineradioApplePushNativeState();
    updateMini();
  }
  function picture(url){var wrap=el('span','♪');wrap.className='mr-art';if(url){var im=el('img');im.alt='';im.loading='lazy';im.src=url;im.onerror=function(){im.remove();};wrap.appendChild(im);}return wrap;}
  function row(title,sub,cover,click){var n=button('',click);n.className='mr-row';n.appendChild(picture(cover));var copy=el('span');copy.append(el('b',title),el('small',sub));n.append(copy,el('span','›'));return n;}
  function libraryUI(){
    tools.replaceChildren();var choices=el('div');choices.className='mr-filters';
    ['all'].concat(Array.from(new Set(userPlaylists.map(function(p){return p.provider||'netease';})))).forEach(function(p){var b=button(p==='all'?'全部':playlistProviderName(p),function(){filter=p;shown=60;libraryUI();});b.setAttribute('aria-pressed',String(filter===p));choices.appendChild(b);});tools.appendChild(choices);
    var actions=el('div');actions.className='mr-actions';actions.append(button('导入音乐',function(){triggerUploadInput('audio');}),button('本地曲库',localLibrary),button('新建歌单 ＋',function(){createForm();}),button('刷新',refresh));tools.append(actions);
    content.replaceChildren();var lists=userPlaylists.filter(function(p){return filter==='all'||p.provider===filter;});
    if(!lists.length){var welcome=el('div');welcome.className='mr-welcome-card';welcome.append(el('h2','还没有歌单'),el('p','连接常用的音乐平台，或导入这台设备上的音频。'),button('连接音乐平台',function(){showLoginModal();}),button('导入本地音乐',function(){triggerUploadInput('audio');}));content.append(welcome);return;}
    var heading=el('div');heading.className='mr-section';heading.append(el('h2','歌单'),el('small',lists.length+' 个'));content.append(heading);
    lists.slice(0,shown).forEach(function(p){content.appendChild(row(p.name||'未命名歌单',playlistProviderName(p.provider)+(p.trackCount?' · '+p.trackCount+' 首':''),p.cover,function(){scroll=content.scrollTop;selected=p;loadDetail(false);}));});
    if(lists.length>shown)content.append(button('显示更多歌单',function(){shown+=60;var top=content.scrollTop;libraryUI();content.scrollTop=top;}));
  }
  function queueUI(){tools.replaceChildren();content.replaceChildren(el('h2','当前播放队列'));if(!playQueue.length){content.append(el('p','还没有播放中的歌曲。从歌单或搜索里选一首吧。'));return;}
    trackRows(playQueue.slice(),async function(i){try{await playQueueAt(i);updateMini();}catch(e){showToast('播放未完成，请重试');}});
  }
  function createForm(){
    var form=el('form'),input=el('input'),status=el('p');input.placeholder='给歌单起个名字';input.maxLength=80;input.setAttribute('aria-label','歌单名称');
    var save=button('创建',async function(){if(!input.value.trim()){status.textContent='请先输入歌单名称';return;}save.disabled=true;
      try{var pl=await createBuiltInPlaylist(input.value.trim());if(!pl){status.textContent='创建失败，请重试';return;}selected=Object.assign({},pl,{provider:'mineradio'});await loadDetail(false);}
      catch(e){status.textContent='歌单保存失败，请重试';}finally{save.disabled=false;}
    });form.append(input,save);form.onsubmit=function(e){e.preventDefault();save.click();};tools.replaceChildren(button('‹ 返回歌单',libraryUI),form,status);input.focus();
  }
  async function refresh(){if(loading)return;loading=true;note('正在同步歌单…');try{await refreshUserPlaylists();libraryUI();}catch(e){note('歌单同步失败，请检查网络或重新连接平台。',refresh);}finally{loading=false;}}
  async function loadDetail(more){
    if(loading)return;loading=true;var own=++generation,p=selected;
    if(!more){tracks=[];page=null;detailUI();note('正在加载歌曲…');}
    try{var r=await fetchPlaylistTracksPage(p.provider,p.id,{offset:more&&page?page.nextOffset:0,limit:50});if(own!==generation||p!==selected)return;
      if(r.ok===false||r.error)throw Error(r.message||r.error);
      tracks=more?tracks.concat(r.tracks||[]):r.tracks||[];page=r;detailTracks=tracks;detailPage=r;detailUI();
    }catch(e){if(own===generation)note('歌曲未能载入：'+(e.message||'请检查网络'),function(){loadDetail(more);});}finally{if(own===generation)loading=false;}
  }
  function detailUI(){
    tools.replaceChildren(button('‹ 所有歌单',function(){generation++;loading=false;selected=null;libraryUI();content.scrollTop=scroll;}));
    content.replaceChildren();var hero=el('div');hero.className='mr-detail';hero.append(picture(selected.cover),el('h2',selected.name),el('p',playlistProviderName(selected.provider)));content.append(hero);
    if(tracks.length)content.append(button('播放歌单',function(){playDetail(0);}));
    trackRows(tracks,playDetail);
    if(page&&page.hasMore)content.append(button('载入更多歌曲',function(){loadDetail(true);}));
    if(page&&!tracks.length)content.append(el('p',selected.provider==='mineradio'?'这是你的新歌单。可以添加正在播放的歌曲，也可以在舞台的收藏菜单中选择它。':'这个歌单里还没有可播放的歌曲。'));
    if(selected.provider==='mineradio'&&song())content.append(button('＋ 添加正在播放的歌曲',async function(){if(await addTrackToBuiltInPlaylist(selected.id,song()))loadDetail(false);}));
  }
  function trackRows(items,play){
    var list=el('div'),key=screen==='search'?'search:'+query:'detail:'+(selected&&selected.id),offset=rowOffsets[key]||0;offset=Math.min(offset,Math.max(0,Math.floor((items.length-1)/50)*50));content.append(list);
    function render(){
      rowOffsets[key]=offset;list.replaceChildren();
      items.slice(offset,offset+50).forEach(function(s,i){list.append(row(s.name||s.title||'未知歌曲',(s.artist||'未知歌手')+' · '+songSourceLabel(s)+(s.trial?' · 试听':''),s.cover,function(){play(offset+i);}));});
      if(items.length>50){var pager=el('div');pager.className='mr-actions';var prev=button('上一页',function(){offset=Math.max(0,offset-50);render();content.scrollTop=0;});prev.disabled=offset===0;var next=button('下一页',function(){offset+=50;render();content.scrollTop=0;});next.disabled=offset+50>=items.length;pager.append(prev,el('small',(offset+1)+'–'+Math.min(items.length,offset+50)+' / '+items.length),next);list.append(pager);}
    }
    render();
  }
  async function playDetail(index){
    var list=selected,items=tracks.slice(),r=page;if(!items[index])return;
    try{var ok=await loadPlaylistIntoQueueById(playlistPanelProviderId(list.provider,list.id),false,list.name,{seedTracks:items,total:r&&r.total,nextOffset:r&&r.nextOffset,hasMore:r&&r.hasMore,preserveHomeState:true});if(ok===false)return;
      if(await playQueueAt(index)!==false)updateMini();
    }catch(e){showToast('播放未完成，请重新选择歌曲');}
  }
  async function localLibrary(){try{var host=window.desktopWindow;if(!host||!host.listLocalMusicLibrary)throw Error();var r=await host.listLocalMusicLibrary();selected={provider:'local',id:'local',name:'本地音乐'};tracks=r.tracks||[];detailTracks=tracks;page=null;tools.replaceChildren(button('‹ 所有歌单',function(){selected=null;libraryUI();}));content.replaceChildren(el('h2','本地音乐'));if(!tracks.length)content.append(el('p','还没有音频文件。'),button('导入音乐',function(){triggerUploadInput('audio');}));trackRows(tracks,function(i){playPool(tracks,i);});}catch(e){note('本地曲库读取失败，请重试。',localLibrary);}}
  async function playPool(pool,i){if(!pool[i])return;cancelPlaylistQueueHydration('mobile-search');playQueue=pool.slice();currentIdx=-1;try{await playQueueAt(i);updateMini();}catch(e){showToast('播放未完成，请重试');}}
  function searchUI(){tools.replaceChildren();var form=el('form'),input=el('input');input.type='search';input.placeholder='歌曲、歌手、专辑';input.setAttribute('aria-label','搜索音乐');input.value=query;form.append(input,button('搜索',function(){runSearch(input.value,false);}));form.onsubmit=function(e){e.preventDefault();runSearch(input.value,false);};tools.append(form);if(query&&tracks.length){content.replaceChildren();trackRows(tracks,function(i){playPool(tracks,i);});}else note('搜索已连接平台中的音乐。');}
  async function runSearch(q,more){q=q.trim();if(!q)return;query=q;var prior=more?searchTracks.slice():[];var own=++generation;note('正在搜索…');
    try{var r=await fetchMusicSearchResults(q,'all',more?searchPages:null);if(own!==generation||screen!=='search')return;tracks=more?prior.concat(r.songs||[]):r.songs||[];searchTracks=tracks;searchPages=r.providerPages;content.replaceChildren();trackRows(tracks,function(i){playPool(tracks,i);});if(!tracks.length)note('没有找到歌曲，试试其他歌名，或先连接音乐平台。');if(r.hasMore&&searchPages)content.append(button('更多结果',function(){runSearch(query,true);}));}
    catch(e){if(own===generation)note('搜索失败，请检查网络和平台连接。',function(){runSearch(q,false);});}
  }
  var playIcon='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m8 5 11 7-11 7z"/></svg>',pauseIcon='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 5h4v14H7zm6 0h4v14h-4z"/></svg>';
  mini.querySelector('[data-act="next"]').innerHTML='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 5 10 7L5 19zm12 0h2v14h-2z"/></svg>';
  var miniKey='';function updateMini(){var s=song();mini.hidden=!s;root.classList.toggle('mr-has-song',!!s);body.classList.toggle('mr-has-song',!!s);if(!s)return;var key=[s.id,s.name,s.cover,s.trial,playing].join('|');if(key===miniKey)return;miniKey=key;if(screen==='queue')queueUI();
    var im=mini.querySelector('img');if(s.cover){im.hidden=false;im.src=s.cover;}else{im.hidden=true;im.removeAttribute('src');}im.onerror=function(){im.hidden=true;};mini.querySelector('b').textContent=s.name||s.title||'未知歌曲';mini.querySelector('small').textContent=(s.artist||'')+(s.trial?' · 试听':'');mini.querySelector('[data-act="toggle"]').innerHTML=playing?pauseIcon:playIcon;mini.querySelector('[data-act="toggle"]').setAttribute('aria-label',playing?'暂停':'播放');
  }
  root.addEventListener('click',function(e){var n=e.target.closest('[data-view],[data-act]');if(!n)return;if(n.dataset.view){if(n.dataset.view==='stage')openStage();else{generation++;loading=false;scroll=0;navigate(n.dataset.view);}return;}var a=n.dataset.act;if(a==='connect')showLoginModal();if(a==='stage')openStage();if(a==='toggle')Promise.resolve(togglePlay()).finally(updateMini);if(a==='next')Promise.resolve(nextTrack(true)).finally(updateMini);});
  window.__mineradioNavigationTick=updateMini;
  var originalRebuild=rebuildUserPlaylistsFromCatalog;rebuildUserPlaylistsFromCatalog=function(){var r=originalRebuild.apply(this,arguments);if(screen==='library'&&!selected)libraryUI();return r;};
  var originalRefresh=refreshUserPlaylists;refreshUserPlaylists=async function(){var r=await originalRefresh.apply(this,arguments);if(screen==='library'&&!selected)libraryUI();return r;};
  var command=window.__mineradioAppleCommand;if(command)window.__mineradioAppleCommand=function(name,value){if(name==='library'){selected=null;navigate('library');return true;}return command(name,value);};
  var libraryButton=document.getElementById('apple-library-btn');if(libraryButton)libraryButton.onclick=function(e){e.stopPropagation();selected=null;navigate('library');};
  var homeVisibility=shouldShowEmptyHome;shouldShowEmptyHome=function(){return screen==='stage'?false:homeVisibility.apply(this,arguments);};
  var viewport=window.matchMedia('(max-width: 767px)');function fit(){body.classList.toggle('mr-wide-browser',!viewport.matches);}
  viewport.addEventListener('change',fit);fit();
  var fps=getAdaptiveRenderFps;getAdaptiveRenderFps=function(){return body.classList.contains('mr-browsing')?2:fps.apply(this,arguments);};
  var cadence=resolveAdaptiveRenderCadence;resolveAdaptiveRenderCadence=function(){return body.classList.contains('mr-browsing')?null:cadence.apply(this,arguments);};
  var libUI=renderUserPlaylistsList;renderUserPlaylistsList=function(){var r=libUI.apply(this,arguments);if(screen==='library'&&!selected)libraryUI();return r;};
  setInterval(function(){if(!document.hidden)updateMini();},1000);
  window.__mineradioNavigation={navigate:navigate,state:function(){return{screen:screen,tab:tab,playlist:selected&&selected.id,tracks:tracks.length};}};
  var style=document.createElement('link');style.rel='stylesheet';style.href='/apple-navigation.css';document.head.appendChild(style);
  // A first-run walkthrough of desktop controls would cover this new library.
  if(typeof maybeRunStartupVisualGuide==='function')maybeRunStartupVisualGuide=function(){return false;};
  if(typeof maybeRunStartupLoginGuide==='function')maybeRunStartupLoginGuide=function(){return false;};
  navigate('library');
})();
