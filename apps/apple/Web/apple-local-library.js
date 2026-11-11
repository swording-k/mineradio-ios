// Device-local audio library. IndexedDB stores files, never platform cookies or
// remote streams. Blob URLs stay stable for this page and are released on clear.
(function installAppleLocalLibrary() {
  if (!window.indexedDB) return;
  var database, urls = new Map();
  function open() {
    if (!database) database = new Promise(function (resolve, reject) {
      var request = indexedDB.open('mineradio-local-audio', 1);
      request.onupgradeneeded = function () { request.result.createObjectStore('tracks', {keyPath: 'id'}); };
      request.onsuccess = function () { resolve(request.result); };
      request.onerror = function () { database = null; reject(request.error); };
      request.onblocked = function () { database = null; reject(new Error('本地曲库被其他页面占用，请重启后再试')); };
    });
    return database;
  }
  async function store(mode, action) {
    var db = await open();
    return new Promise(function (resolve, reject) {
      var transaction = db.transaction('tracks', mode), result;
      transaction.oncomplete = function () { resolve(result); };
      transaction.onerror = transaction.onabort = function () { reject(transaction.error || new Error('本地曲库保存失败')); };
      var request = action(transaction.objectStore('tracks'));
      request.onsuccess = function () { result = request.result; };
    });
  }
  function song(record) {
    if (!urls.has(record.id)) urls.set(record.id, URL.createObjectURL(record.file));
    return {type: 'local', source: 'local', provider: 'local', name: record.name,
      artist: '本地文件', localKey: record.id, localFileId: record.id,
      localUrl: urls.get(record.id), duration: 0};
  }
  var host = window.desktopWindow || {isDesktop: false};
  host.importLocalMusicFiles = async function (files) {
    var failures = [], tracks = [];
    for (var file of Array.from(files)) {
      if (!isAudioUploadFile(file)) continue;
      var id = [file.name, file.size, file.lastModified].join(':');
      var record = {id: id, name: file.name.replace(/\.[^.]+$/, ''), file: file};
      try {
        await store('readwrite', function (s) { return s.put(record); });
        tracks.push(song(record));
      } catch (_) { failures.push({name: file.name}); }
    }
    if (!tracks.length) throw new Error('无法保存文件：请检查设备可用存储空间');
    return {ok: true, tracks: tracks, failures: failures};
  };
  host.listLocalMusicLibrary = async function () {
    var records = await store('readonly', function (s) { return s.getAll(); });
    return {ok: true, tracks: records.map(song)};
  };
  window.desktopWindow = host;
  var panel = document.getElementById('upload-panel');
  if (panel) {
    var info = document.createElement('p');
    info.textContent = '本地音乐保存在此设备，可断网播放。仅导入你有权使用的音频；云盘文件需先下载。';
    info.style.cssText = 'font-size:12px;line-height:1.6;max-width:300px;white-space:normal';
    panel.appendChild(info);
    var library = document.createElement('button');
    library.type = 'button'; library.className = 'modal-btn'; library.textContent = '打开本地曲库';
    library.style.minHeight = '44px';
    library.onclick = async function () {
      try {
        var result = await host.listLocalMusicLibrary();
        if (!result.tracks.length) return showToast('本地曲库为空，请先导入音频');
        persistentLocalLibraryTracks = result.tracks;
        importLocalAudioSongs(result.tracks);
        closeUploadPanel();
      } catch (_) { showToast('本地曲库读取失败，请重试'); }
    };
    panel.appendChild(library);
    var clear = document.createElement('button'), confirmUntil = 0;
    clear.type = 'button'; clear.className = 'modal-btn'; clear.textContent = '清空本地曲库'; clear.style.minHeight = '44px';
    clear.onclick = async function () {
      if (Date.now() > confirmUntil) {
        confirmUntil = Date.now() + 4000;
        clear.textContent = '再次点击清空（不影响原文件）';
        setTimeout(function () { clear.textContent = '清空本地曲库'; }, 4000);
        return;
      }
      try {
        await store('readwrite', function (s) { return s.clear(); });
        persistentLocalLibraryTracks = [];
        // Keep active session URLs alive; currently playing audio is not cut off.
        showToast('已清空保存的曲库，当前播放队列本次仍可用');
      } catch (_) { showToast('清空失败，请重试'); }
      confirmUntil = 0; clear.textContent = '清空本地曲库';
    };
    panel.appendChild(clear);
  }
  var actions = document.getElementById('upload-actions');
  if (actions) {
    var entry = document.createElement('button');
    entry.type = 'button'; entry.className = 'fx-mini-btn ghost';
    entry.textContent = '本地音乐'; entry.style.cssText = 'min-height:44px;white-space:nowrap';
    entry.onclick = function (event) { toggleUploadPanel(event); };
    actions.appendChild(entry);
  }
  var input = document.getElementById('file-input');
  if (input) input.multiple = true;
  // Original startup runs before this adapter; restore after installing host APIs.
  if (typeof restorePersistedLocalLibrary === 'function') restorePersistedLocalLibrary();
})();
