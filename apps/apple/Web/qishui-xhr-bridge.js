/* Isolated Apple Passport signer environment only. Install before BDMS so the
 * SDK signs the request before this transport delivers it to native code. */
(() => {
  const pending = new Map();
  let sequence = 0;
  class NativeXHR extends EventTarget {
    constructor() {
      super(); this.readyState = 0; this.status = 0; this.responseText = '';
      this.response = ''; this.responseURL = ''; this.timeout = 30000;
      this.withCredentials = false; this.upload = new EventTarget();
      this.headers = {}; this.responseType = ''; this._id = null;
    }
    open(method, url, async = true) {
      if (async === false) throw new Error('Synchronous Passport requests are unsupported');
      this.method = String(method).toUpperCase(); this.url = String(url);
      this.readyState = 1; this._event('readystatechange');
    }
    setRequestHeader(name, value) { this.headers[String(name)] = String(value); }
    getAllResponseHeaders() { return 'content-type: application/json\r\n'; }
    getResponseHeader(name) { return String(name).toLowerCase() === 'content-type' ? 'application/json' : null; }
    overrideMimeType() {}
    send(body = null) {
      const url = new URL(this.url, location.href);
      const methods = {'/passport/web/get_qrcode/': 'GET', '/passport/web/check_qrconnect/': 'POST'};
      if (url.protocol !== 'https:' || url.hostname !== 'api.qishui.com' || methods[url.pathname] !== this.method || url.username || url.password || url.port && url.port !== '443') {
        queueMicrotask(() => this._fail('error')); return;
      }
      if (pending.size >= 4) {queueMicrotask(() => this._fail('error')); return;}
      this._id = String(++sequence); pending.set(this._id, this);
      this._timer = setTimeout(() => this._fail('timeout'), Math.min(30000, Math.max(1000, this.timeout || 30000)));
      window.webkit.messageHandlers.qishuiRequest.postMessage({id: this._id, url: url.href, method: this.method, headers: this.headers, body: body == null ? null : String(body)});
    }
    abort() { this._fail('abort'); }
    _event(name) {const event = new Event(name); this.dispatchEvent(event); if (typeof this['on' + name] === 'function') this['on' + name](event);}
    _fail(name) { clearTimeout(this._timer); if (this._id) pending.delete(this._id); this.readyState = 4; this._event('readystatechange'); this._event(name); this._event('loadend'); }
    _complete(result) {
      clearTimeout(this._timer); pending.delete(this._id);
      if (result.error) {this._fail('error'); return;}
      this.status = result.status; this.responseText = result.body || ''; this.responseURL = this.url;
      this.response = this.responseType === 'json' ? JSON.parse(this.responseText || '{}') : this.responseText;
      this.readyState = 4; this._event('readystatechange'); this._event('load'); this._event('loadend');
    }
  }
  for (const [name, value] of Object.entries({UNSENT: 0, OPENED: 1, HEADERS_RECEIVED: 2, LOADING: 3, DONE: 4})) {NativeXHR[name] = value; NativeXHR.prototype[name] = value;}
  window.XMLHttpRequest = NativeXHR;
  window.__qishuiNativeComplete = (id, result) => {const xhr = pending.get(String(id)); if (xhr) xhr._complete(result);};
})();
