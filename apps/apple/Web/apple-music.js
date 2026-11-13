// MusicKit protected playback remains native; no stream URL or credential enters WebAudio.
(function () {
  var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.appleMusic;
  if (!bridge || window.__mineradioAppleMusicInstalled) return;
  window.__mineradioAppleMusicInstalled = true;
  var state = {active: false}, key = '', receivedAt = 0;
  function position(){var value=Number(state.current)||0;if(state.playing)value+=Math.min(1.5,Math.max(0,(Date.now()-receivedAt)/1000));return state.duration>0?Math.min(state.duration,value):value;}
  function command(action, value) {
    return bridge.postMessage({action: action, value: value}).then(function (r) {
      if (r && r.ok === false && typeof showToast === 'function') showToast(r.message);
      return r;
    });
  }
  function call(name) { var fn = arguments[0]; if (typeof fn === 'function') { try { fn.apply(null, Array.prototype.slice.call(arguments, 1)); } catch (_) {} } }
  window.__mineradioAppleMusicPrepare = function () {
    if (typeof trackSwitchToken !== 'undefined') trackSwitchToken++;
    if (typeof pauseCurrentAudioForTrackSwitch === 'function') pauseCurrentAudioForTrackSwitch();
    else if (typeof audio !== 'undefined' && audio) audio.pause();
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
    state = next || {active:false}; receivedAt = Date.now();
    if (!state.active) { if(wasActive)playing=false; return; }
    var resumed=!!state.playing && !playing;
    playing = !!state.playing;
    call(typeof setPlayIcon === 'function' && setPlayIcon, playing);
    if(resumed)call(typeof markStageLyricsPlaybackResume === 'function' && markStageLyricsPlaybackResume, 'apple-music');
    if (!state.song) return;
    var song = state.song;
    var visualKey=String(song.id)+'|'+String(song.cover||'');
    if (key !== visualKey) {
      key = visualKey; trackSwitchToken++;
      var found=playQueue.findIndex(function(s){return s.provider==='applemusic' && String(s.id)===String(song.id);});
      if(found>=0){currentIdx=found;playQueue[found]=Object.assign({},playQueue[found],song);}else{playQueue=[song];currentIdx=0;}
      if(!firstPlayDone && typeof tweenParticleAlpha==='function' && typeof uniforms!=='undefined')tweenParticleAlpha(uniforms.uAlpha.value||0,1,220);
      firstPlayDone = true;
      if (typeof homeForcedOpen !== 'undefined') homeForcedOpen = false;
      if (typeof homeSuppressed !== 'undefined') homeSuppressed = false;
      call(typeof markRenderInteraction === 'function' && markRenderInteraction, 'apple-music-track', 1000);
      call(typeof forcePlaybackControlsInteractive === 'function' && forcePlaybackControlsInteractive);
      call(typeof switchPlaybackVisualToEmily === 'function' && switchPlaybackVisualToEmily);
      call(typeof dismissHomePage === 'function' && dismissHomePage);
      call(typeof updateEmptyHomeVisibility === 'function' && updateEmptyHomeVisibility);
      ['thumb-title','thumb-artist'].forEach(function (id,i) { var n=document.getElementById(id); if(n)n.textContent=i?song.artist:song.name; });
      call(typeof updateControlTrackInfo === 'function' && updateControlTrackInfo, song);
      call(typeof resetLyricsForTrackSwitch === 'function' && resetLyricsForTrackSwitch, song, trackSwitchToken);
      call(typeof loadCoverFromUrl === 'function' && loadCoverFromUrl, song.cover || '', {trackToken:trackSwitchToken});
      call(typeof fetchLyric === 'function' && fetchLyric, song, trackSwitchToken);
      call(typeof hideLoading === 'function' && hideLoading);
      call(typeof renderQueuePanel === 'function' && renderQueuePanel);
    }
    call(typeof updatePlaybackProgressUi === 'function' && updatePlaybackProgressUi);
  };
  var queueAt = playQueueAt;
  playQueueAt = async function (idx) {
    var song=playQueue[idx];
    if(song && song.provider==='applemusic') {
      var result=await bridge.postMessage({action:'playID',id:String(song.id),ids:playQueue.filter(function(s){return s.provider==='applemusic';}).map(function(s){return String(s.id);})});
      if(!result || !result.ok){if(typeof showToast==='function')showToast(result && result.message || 'Apple Music 播放未完成');return false;}
      return true;
    }
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
  if(typeof stageLyricPlaybackSeconds==='function') {
    var lyricClock=stageLyricPlaybackSeconds;
    stageLyricPlaybackSeconds=function(){return state.active?position():lyricClock.apply(this,arguments);};
  }
  var time=getPlaybackCurrentSeconds, duration=getPlaybackDurationSeconds;
  getPlaybackCurrentSeconds=function(){return state.active?position():time.apply(this,arguments);};
  getPlaybackDurationSeconds=function(){return state.active?Number(state.duration)||0:duration.apply(this,arguments);};
})();
