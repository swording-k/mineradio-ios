// MusicKit protected playback remains native; no stream URL or credential enters WebAudio.
(function () {
  var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.appleMusic;
  if (!bridge || window.__mineradioAppleMusicInstalled) return;
  window.__mineradioAppleMusicInstalled = true;
  var state = {active: false}, key = '';
  function command(action, value) {
    return bridge.postMessage({action: action, value: value}).then(function (r) {
      if (r && r.ok === false && typeof showToast === 'function') showToast(r.message);
      return r;
    });
  }
  function call(name) { var fn = arguments[0]; if (typeof fn === 'function') { try { fn.apply(null, Array.prototype.slice.call(arguments, 1)); } catch (_) {} } }
  window.__mineradioAppleMusicPrepare = function () {
    if (typeof trackSwitchToken !== 'undefined') trackSwitchToken++;
    if (typeof audio !== 'undefined' && audio) audio.pause();
    playing = false;
    call(typeof closeLoginModal === 'function' && closeLoginModal);
    call(typeof closeUserModal === 'function' && closeUserModal);
    if (typeof finalizeListenSession === 'function') finalizeListenSession(false);
    if (typeof cancelBeatAnalysisTimer === 'function') cancelBeatAnalysisTimer();
    if (typeof clearAlbumGaplessPreload === 'function') clearAlbumGaplessPreload('apple-music');
    return true;
  };
  window.__mineradioAppleMusicReceive = function (next) {
    var wasActive = state.active;
    state = next || {active:false};
    if (!state.active) { if(wasActive)playing=false; return; }
    playing = !!state.playing;
    if (!state.song) return;
    var song = state.song;
    if (key !== song.id) {
      key = song.id; trackSwitchToken++; playQueue = [song]; currentIdx = 0; firstPlayDone = true;
      if (typeof homeForcedOpen !== 'undefined') homeForcedOpen = false;
      if (typeof homeSuppressed !== 'undefined') homeSuppressed = false;
      call(typeof switchPlaybackVisualToEmily === 'function' && switchPlaybackVisualToEmily);
      call(typeof updateEmptyHomeVisibility === 'function' && updateEmptyHomeVisibility);
      ['thumb-title','thumb-artist'].forEach(function (id,i) { var n=document.getElementById(id); if(n)n.textContent=i?song.artist:song.name; });
      call(typeof updateControlTrackInfo === 'function' && updateControlTrackInfo, song);
      call(typeof resetLyricsForTrackSwitch === 'function' && resetLyricsForTrackSwitch, song, trackSwitchToken);
      call(typeof loadCoverFromUrl === 'function' && loadCoverFromUrl, song.cover || '', {trackToken:trackSwitchToken});
      call(typeof hideLoading === 'function' && hideLoading);
      call(typeof renderQueuePanel === 'function' && renderQueuePanel);
    }
    call(typeof updatePlaybackProgressUi === 'function' && updatePlaybackProgressUi);
  };
  var queueAt = playQueueAt;
  playQueueAt = async function (idx) {
    if (state.active && playQueue[idx] && playQueue[idx].provider === 'applemusic') { await command('seek', 0); return command('play'); }
    if (state.active) { var r = await command('stop'); if (!r || !r.ok) return false; state={active:false};key=''; }
    return queueAt.apply(this, arguments);
  };
  [['togglePlay','toggle'],['nextTrack','next'],['prevTrack','prev'],['commitProgressSeek','seek']].forEach(function(pair){
    var original = pair[0] === 'togglePlay' ? togglePlay : pair[0] === 'nextTrack' ? nextTrack : pair[0] === 'prevTrack' ? prevTrack : commitProgressSeek;
    var wrapped = function(value){ if(state.active)return command(pair[1],pair[1]==='seek'?Number(value):undefined);return original.apply(this,arguments); };
    if(pair[0]==='togglePlay')togglePlay=wrapped;else if(pair[0]==='nextTrack')nextTrack=wrapped;else if(pair[0]==='prevTrack')prevTrack=wrapped;else commitProgressSeek=wrapped;
  });
  if (typeof toggleLikeCurrent === 'function') {
    var like=toggleLikeCurrent; toggleLikeCurrent=function(){if(state.active){showToast('请在 Apple Music 中管理喜爱歌曲');return;}return like.apply(this,arguments);};
  }
  var time=getPlaybackCurrentSeconds, duration=getPlaybackDurationSeconds;
  getPlaybackCurrentSeconds=function(){return state.active?Number(state.current)||0:time.apply(this,arguments);};
  getPlaybackDurationSeconds=function(){return state.active?Number(state.duration)||0:duration.apply(this,arguments);};
  ['login-platform-tabs','user-platform-tabs','search-mode-tabs'].forEach(function(id){
    var parent=id==='user-platform-tabs'?document.querySelector('#user-modal .user-platform-tabs'):document.getElementById(id);
    if(!parent && id==='user-platform-tabs')return;
    if(!parent)return;
    var button=document.createElement('button');button.type='button';button.textContent='Apple Music';button.setAttribute('aria-label','打开 Apple Music 音乐库');
    button.style.cssText='color:#fa586a;min-height:44px;flex-shrink:0';button.onclick=function(){command('open');};parent.appendChild(button);
  });
})();
