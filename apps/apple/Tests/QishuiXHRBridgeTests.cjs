const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
function fixture() {
  const messages = [];
  const window = {webkit: {messageHandlers: {qishuiRequest: {postMessage: message => messages.push(message)}}}};
  const context = {window, Event, EventTarget, URL, Map, Object, String, Math, JSON, queueMicrotask, setTimeout, clearTimeout, location: {href: 'qishui-auth://security/security_host.html'}};
  vm.runInNewContext(fs.readFileSync('apps/apple/Web/qishui-xhr-bridge.js', 'utf8'), context);
  return {window, messages};
}
test('signed Passport URL/form survives transport; response arrives as XHR load', () => {
  const {window, messages} = fixture(), xhr = new window.XMLHttpRequest();
  const url = 'https://api.qishui.com/passport/web/check_qrconnect/?a_bogus=SIGNATURE&msToken=TOKEN';
  let loaded = false;
  xhr.open('POST', url); xhr.setRequestHeader('x-ss-stub', 'MD5');
  xhr.onload = () => {loaded = true;}; xhr.send('token=QR');
  assert.equal(messages.length, 1); assert.equal(messages[0].url, url); assert.equal(messages[0].body, 'token=QR');
  window.__qishuiNativeComplete(messages[0].id, {status: 200, body: '{"data":{"status":"1"}}'});
  assert(loaded); assert.equal(xhr.readyState, 4); assert.equal(xhr.responseText, '{"data":{"status":"1"}}');
});
test('off-host, wrong method, and arbitrary paths never reach native transport', async () => {
  const {window, messages} = fixture();
  for (const url of ['https://api.qishui.com.evil.test/passport/web/get_qrcode/', 'http://api.qishui.com/passport/web/get_qrcode/', 'https://api.qishui.com/private', 'https://user@api.qishui.com/passport/web/get_qrcode/']) {
    const xhr = new window.XMLHttpRequest(); xhr.open('GET', url); xhr.send();
  }
  const wrong = new window.XMLHttpRequest(); wrong.open('POST', 'https://api.qishui.com/passport/web/get_qrcode/'); wrong.send();
  await new Promise(resolve => setImmediate(resolve)); assert.equal(messages.length, 0);
});
test('abort suppresses late native reply and synchronous requests are rejected', () => {
  const {window, messages} = fixture(), xhr = new window.XMLHttpRequest(); let loaded = false;
  assert.throws(() => xhr.open('GET', 'https://api.qishui.com/', false), /Synchronous/);
  xhr.open('GET', 'https://api.qishui.com/passport/web/get_qrcode/'); xhr.onload = () => {loaded = true;}; xhr.send(); xhr.abort();
  window.__qishuiNativeComplete(messages[0].id, {status: 200, body: '{}'}); assert.equal(loaded, false);
});
