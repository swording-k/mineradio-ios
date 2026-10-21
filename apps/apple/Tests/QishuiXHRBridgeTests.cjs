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
test('security transport is limited to the active challenge and exact official Passport hosts', async () => {
  const {window, messages} = fixture();
  const endpoint = 'https://api.qishui.com/passport/safe/pack_verify_ways_data/?aid=386088';
  const before = new window.XMLHttpRequest(); before.open('POST', endpoint); before.send('fixture=1');
  await new Promise(resolve => setImmediate(resolve)); assert.equal(messages.length, 0);
  window.__qishuiSecurityActive = true;
  for (const host of ['api.qishui.com', 'verify.zijieapi.com', 'auth.zijieapi.com']) {
    const xhr = new window.XMLHttpRequest(); xhr.open('POST', `https://${host}/passport/safe/fixture/`); xhr.send('fixture=1');
    const message = messages.at(-1); assert.equal(new URL(message.url).host, host);
    window.__qishuiNativeComplete(message.id, {status: 200, body: '{}'});
  }
  for (const url of ['https://api.qishui.com.evil.test/passport/safe/a/', 'https://api.qishui.com/private', 'https://api.qishui.com/passport/../private', 'http://verify.zijieapi.com/passport/a/', 'https://user@verify.zijieapi.com/passport/a/']) {
    const xhr = new window.XMLHttpRequest(); xhr.open('POST', url); xhr.send();
  }
  await new Promise(resolve => setImmediate(resolve)); assert.equal(messages.length, 3);
  window.__qishuiSecurityActive = false;
  const after = new window.XMLHttpRequest(); after.open('POST', endpoint); after.send();
  await new Promise(resolve => setImmediate(resolve)); assert.equal(messages.length, 3);
});
