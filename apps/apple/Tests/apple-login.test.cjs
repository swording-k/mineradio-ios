const test = require('node:test'), assert = require('node:assert/strict'), vm = require('node:vm'), fs = require('node:fs');
function fixture(result, setup) {
  const calls = [], status = {}, powerStates = [];
  const context = {window: {__mineradioAppleSetAuthPresentation: value => powerStates.push(value), webkit: {messageHandlers: {appleAccountLogin: {postMessage: async input => {calls.push(input); return result;}}}}},
    document: {getElementById: () => status},
    qqWebLoginBusy: false, kugouWebLoginBusy: false, activeAccountProvider: 'netease',
    updateLoginProviderUi() {}, normalizeQQLoginStatus: value => value, normalizeKugouLoginStatus: value => value,
    renderUserBtn() {}, refreshUserPlaylists: async () => calls.push('library'), loadHomeDiscover: async () => {},
    showToast: text => calls.push(text), closeLoginModal: () => calls.push('closed')};
  if (setup) setup(context);
  vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-login.js','utf8'), context);
  return {context, calls, status, powerStates};
}
test('official login returns verified state without exposing a cookie to the player', async () => {
  const f = fixture({loggedIn: true, nickname: 'Fixture', playbackKeyReady: true});
  await f.context.openQQWebLogin();
  assert.equal(f.calls[0].provider, 'qq'); assert.equal(f.context.activeAccountProvider, 'qq');
  assert(f.calls.includes('library')); assert.equal(f.context.qqWebLoginBusy, false);
});
test('cancel and failed verification do not connect an account or load its library', async () => {
  const f = fixture({loggedIn: false, cancelled: true, message: 'cancelled'});
  await f.context.openKugouWebLogin();
  assert.equal(f.context.activeAccountProvider, 'netease'); assert(!f.calls.includes('library'));
  assert.equal(f.context.kugouWebLoginBusy, false);
  assert.deepEqual(f.powerStates, [true, false]);
});

test('Qishui additional verification is surfaced instead of polling forever', async () => {
  let stopped = false;
  const f = fixture({}, context => {
    context.URL = URL; context.window.location = {href: 'http://127.0.0.1:19363/'};
    context.window.fetch = async () => new Response(JSON.stringify({status: 'mfa_required', errorCode: 2046, message: 'additional verification required'}));
    context.qishuiQrPollGeneration = 3; context.loginProvider = 'qishui';
    context.stopQrPoll = () => { stopped = true; };
    context.pollQishuiQr = async () => { await context.window.fetch('/api/qishui/login/check?token=fixture'); };
  });
  await f.context.pollQishuiQr(3);
  assert(stopped); assert.equal(f.status.textContent, 'additional verification required');
});
