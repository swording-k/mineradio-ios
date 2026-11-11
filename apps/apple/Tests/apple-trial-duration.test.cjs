const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
test('resolved preview duration bounds progress and a subsequent full stream clears stale trial state', () => {
 const start = fs.readFileSync('public/js/modules/05-playback/13-playback-start-audio.js','utf8');
 const progress = fs.readFileSync('public/js/modules/06-lyrics/04-progress-seek.js','utf8');
 const song = {trial:true,duration:204};
 const context = {song,audio:{duration:204},currentCoverSong:()=>song};
 vm.runInNewContext(start.slice(start.indexOf('function applyResolvedTrialInfo(')),context);
 vm.runInNewContext(progress.slice(progress.indexOf('function normalizePlaybackDurationSeconds('),progress.indexOf('function getPlaybackCurrentSeconds(')),context);
 context.applyResolvedTrialInfo(song,{url:'local-test',trial:true,trialDuration:60});
 assert.equal(context.getPlaybackDurationSeconds(),60);
 context.applyResolvedTrialInfo(song,{url:'full-test',trial:false});
 assert.equal(song.trial,false);
 assert.equal(context.getPlaybackDurationSeconds(),204);
});
