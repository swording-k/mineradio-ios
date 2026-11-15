import AppKit
import WebKit
let app=NSApplication.shared
app.setActivationPolicy(.accessory)
let address=CommandLine.arguments[1], out=CommandLine.arguments[2]
let conf=WKWebViewConfiguration()
conf.mediaTypesRequiringUserActionForPlayback=[]
conf.websiteDataStore = .nonPersistent()
let bootstrap = """
window.__errors=[];window.addEventListener('error',e=>window.__errors.push(String(e.message||'')));
window.__fixtureLoggedIn=false;
window.webkit.messageHandlers.appleMusic = {postMessage:async p => p.action==='status'||p.action==='authorize'?{ok:true,provider:'applemusic',loggedIn:window.__fixtureLoggedIn,nickname:'Apple Music'}:{ok:true,playlists:[]}};
"""
class Handler:NSObject, WKScriptMessageHandlerWithReply {
 func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage,replyHandler:@escaping(Any?,String?)->Void){replyHandler(["ok":true,"loggedIn":false,"playlists":[]],nil)}
}
conf.userContentController.addScriptMessageHandler(Handler(),contentWorld:.page,name:"appleMusic")
conf.userContentController.addUserScript(WKUserScript(source:bootstrap,injectionTime:.atDocumentStart,forMainFrameOnly:true))
let win=NSWindow(contentRect:NSRect(x:-7000,y:0,width:393,height:852),styleMask:[.borderless],backing:.buffered,defer:false)
let web=WKWebView(frame:win.contentView!.bounds,configuration:conf)
web.autoresizingMask=[.width,.height];win.contentView!.addSubview(web);win.orderBack(nil)
@MainActor func wait(_ ms:Int) async{try? await Task.sleep(nanoseconds:UInt64(ms)*1000000)}
@MainActor func js(_ s:String)async throws->Any?{try await web.evaluateJavaScript(s)}
@MainActor func image(_ name:String) async throws {
 let snap=try await web.takeSnapshot(configuration:nil)
 let png=NSBitmapImageRep(data:snap.tiffRepresentation!)!.representation(using:.png,properties:[:])!
 try png.write(to:URL(fileURLWithPath:out+"/"+name+".png"))
}
@MainActor func run() async throws {
 web.load(URLRequest(url:URL(string:address)!))
 for _ in 0..<90 { await wait(150);if (try? await js("!!window.__mineradioNavigation") as? Bool)==true{break} }
 _=try await js("dismissSplash({instant:true});void 0");await wait(300)
 for (name,w,h) in [("first-portrait",393,852),("first-short",320,568),("first-large",430,932),("first-split",507,768),("first-wide",1398,800),("first-landscape",852,393),("first-ipad",1024,768)] {
   win.setContentSize(NSSize(width:w,height:h));await wait(160)
   print(name,try await js("(()=>{let b=document.querySelector('.mr-welcome-card button'),r=b.getBoundingClientRect();return JSON.stringify({hit:document.elementFromPoint(r.x+10,r.y+10)===b,width:document.getElementById('mr-browser').scrollWidth,viewport:innerWidth})})()") ?? "")
   let hit=try await js("(()=>{let b=document.querySelector('.mr-welcome-card button'),r=b.getBoundingClientRect();return document.elementFromPoint(r.x+10,r.y+10)===b})()")
   guard hit as? Bool==true else{exit(7)}
   try await image(name)
 }
 win.setContentSize(NSSize(width:393,height:852));await wait(100)
 _=try await js("document.querySelector('.mr-welcome-card button').click();void 0");await wait(200)
 let gate=try await js("(()=>{let b=document.querySelector('#apple-welcome-gate button'),r=b.getBoundingClientRect();return document.elementFromPoint(r.x+8,r.y+8)===b})()");guard gate as? Bool==true else {try await image("gate-failure");print(try await js("JSON.stringify({gate:document.getElementById('apple-welcome-gate').getBoundingClientRect().toJSON(),modal:getComputedStyle(document.getElementById('login-modal')).display})") ?? "");exit(3)}
 _=try await js("document.querySelector('#apple-welcome-gate button').click();void 0");await wait(200);try await image("platforms")
 _=try await js("closeLoginModal();document.getElementById('login-modal').classList.remove('show');userPlaylists=[{id:'fixture',provider:'netease',name:'晨间的留白',trackCount:2,cover:'/api/cover?url=fixture'}];renderUserPlaylistsList();window.__mineradioNavigation.navigate('library');void 0");await wait(150);try await image("library")
 _=try await js("window.__realFetchPlaylistTracksPage=fetchPlaylistTracksPage;fetchPlaylistTracksPage=async()=>({tracks:[{id:1,name:'清晨',artist:'演示数据',provider:'netease',cover:'/api/cover?url=fixture'},{id:2,name:'余光',artist:'演示数据',provider:'netease'}],nextOffset:2,hasMore:false});document.querySelector('#mr-content .mr-row').click();void 0");await wait(150);try await image("detail")
 _=try await js("playQueue=[{id:1,name:'清晨',artist:'演示数据',provider:'netease'}];currentIdx=0;window.__mineradioNavigationTick();void 0");await wait(100)
 _=try await js("document.querySelector('#mr-mini-info').click();void 0");await wait(100)
 guard (try await js("window.__mineradioNavigation.state().screen==='stage'") as? Bool)==true else{exit(4)}
 _=try await js("document.getElementById('home-btn').click();void 0");await wait(100)
 guard (try await js("window.__mineradioNavigation.state().playlist==='fixture'") as? Bool)==true else{exit(5)}
 guard (try await js("!document.getElementById('mr-return')&&!document.getElementById('apple-library-btn')") as? Bool)==true else{exit(13)}
 print("return-preserves-playlist, single entry PASS")
 _=try await js("document.querySelector('[data-view=search]').click();void 0");await wait(100);try await image("search")
 _=try await js("fetchMusicSearchResults=async()=>({songs:[{id:'found',name:'找到的歌',artist:'演示数据',provider:'netease'}],providerPages:{netease:{nextOffset:1,hasMore:false}},hasMore:false});document.querySelector('#mr-tools input').value='演示';document.querySelector('#mr-tools form button').click();void 0");await wait(100)
 guard (try await js("document.querySelector('#mr-content .mr-row').textContent.includes('找到的歌')") as? Bool)==true else{exit(8)}
 _=try await js("document.querySelector('[data-view=library]').click();void 0");await wait(100)
 guard (try await js("window.__mineradioNavigation.state().playlist==='fixture' && document.querySelector('#mr-content .mr-row').textContent.includes('清晨')") as? Bool)==true else{exit(9)}
 // A pending search response must not replace the library after changing tabs.
 _=try await js("document.querySelector('[data-view=search]').click();fetchMusicSearchResults=()=>new Promise(r=>window.__finishSearch=r);document.querySelector('#mr-tools form button').click();document.querySelector('[data-view=library]').click();window.__finishSearch({songs:[{name:'STALE'}],hasMore:false});void 0");await wait(100)
 guard (try await js("!document.getElementById('mr-content').textContent.includes('STALE')") as? Bool)==true else{exit(10)}
 print("search, detail restoration, stale response rejection PASS")
 // Actual original local-audio route. This is a synthetic 12s sine, not a music account.
 _=try await js("window.desktopWindow.listLocalMusicLibrary=async()=>({tracks:[{type:'local',provider:'local',source:'local',localKey:'qa-tone',name:'本地测试音频',artist:'QA',localUrl:location.origin+'/fixture.wav'}]});document.querySelector('[data-view=library]').click();document.querySelector('#mr-tools button').click();[...document.querySelectorAll('#mr-tools button')].find(b=>b.textContent==='本地曲库').click();void 0");await wait(200)
 _=try await js("document.querySelector('#mr-content .mr-row').click();void 0");await wait(1600)
 let position=try await js("audio.currentTime");print("local-audio-clock",position ?? "")
 guard let t=position as? Double,t>0 else{exit(11)}
 _=try await js("closeLocalBeatModal();if(window.gsap)gsap.globalTimeline.time(gsap.globalTimeline.time()+1);document.querySelector('#mr-mini [data-act=toggle]').click();void 0");await wait(100)

 await wait(500);guard (try await js("audio.paused") as? Bool)==true else{exit(12)}
 try await image("local-mini")
 print("local playback and mini pause PASS")
 _=try await js("fetchPlaylistTracksPage=window.__realFetchPlaylistTracksPage;document.querySelector('[data-view=library]').click();document.querySelector('#mr-tools button').click();[...document.querySelectorAll('#mr-tools button')].find(b=>b.textContent.includes('新建歌单')).click();document.querySelector('#mr-tools input').value='QA 自建歌单';document.querySelector('#mr-tools form button').click();void 0");await wait(200)
 guard (try await js("userPlaylists.some(p=>p.name==='QA 自建歌单'&&p.provider==='mineradio') && document.getElementById('mr-content').textContent.includes('QA 自建歌单')") as? Bool)==true else{exit(14)}
 try await image("created-playlist")
 print("persistent built-in playlist creation PASS")
 // Exercise the actual shared WebGL cover loader with an opaque library ID.
 _=try await js("closeLocalBeatModal();closeLoginModal();if(window.gsap)gsap.globalTimeline.time(gsap.globalTimeline.time()+1);window.__mineradioAppleMusicReceive({active:true,playing:true,current:12,duration:197,song:{id:'i.opaque',name:'Beautiful People',artist:'Ed Sheeran',provider:'applemusic',cover:'/api/apple-music-art/92DDAB59-4702-4C59-804C-22F34B68DFE5/song?id=i.opaque&art=1'}});window.__mineradioNavigation.navigate('stage');void 0");await wait(1500)
 let cover=try await js("JSON.stringify({cover:uniforms.uHasCover.value,thumb:document.getElementById('thumb-cover').getAttribute('src'),duplicate:!!document.getElementById('mr-return')||!!document.getElementById('apple-library-btn')})");print("opaque cover pipeline",cover ?? "")
 guard (try await js("uniforms.uHasCover.value>0.5&&getComputedStyle(document.getElementById('empty-home')).display==='none'&&!document.getElementById('mr-return')&&!document.getElementById('apple-library-btn')") as? Bool)==true else{exit(15)}
 let homeHit=try await js("(()=>{let b=document.getElementById('home-btn'),r=b.getBoundingClientRect();return document.elementFromPoint(r.x+r.width/2,r.y+r.height/2)===b || b.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))})()");guard homeHit as? Bool==true else{try await image("home-hit-failure");print(try await js("(()=>{let b=document.getElementById('home-btn'),r=b.getBoundingClientRect();return JSON.stringify({rect:r.toJSON(),hidden:b.hidden,css:b.getAttribute('style'),parent:b.parentElement.outerHTML.slice(0,250),hit:document.elementFromPoint(r.x+r.width/2,r.y+r.height/2)?.outerHTML.slice(0,250)})})()") ?? "");exit(16)}
 // The offscreen macOS test window throttles stage drawing; the cover uniform
 // above tests texture ingestion, not a visual/performance assertion for iOS.
 _=try await js("window.__mineradioNavigation.navigate('library');window.__mineradioNavigationTick();void 0");await wait(150)
 guard (try await js("document.querySelector('#mr-mini img').naturalWidth>0") as? Bool)==true else{exit(17)}
 try await image("apple-artwork-mini-fixture")
 let lyricOK=try await js("lyricsLines.some(l=>!l.fallback) && stageLyricPlaybackMedia().currentTime>=12");print("matched lyric pipeline",lyricOK ?? "");guard lyricOK as? Bool==true else{exit(18)}
 // Explicit close is always visible, including from a nested playlist page.
 _=try await js("document.getElementById('mr-close').click();void 0");await wait(100)
 guard (try await js("window.__mineradioNavigation.state().screen==='stage'") as? Bool)==true else{exit(19)}
 print("MOBILE QA COMPLETE")
 print("errors",try await js("JSON.stringify(window.__errors)") ?? "")
 exit(0)
}
Task{@MainActor in do{try await run()}catch{print(error);exit(6)}}
app.run()
