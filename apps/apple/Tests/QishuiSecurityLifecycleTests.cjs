const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
function fixture(verify) {
  let timer, cleared = false, cancelled = 0;
  const window = {__qishuiSecondVerify: verify, __qishuiCancelSecondVerify: () => cancelled++};
  vm.runInNewContext(fs.readFileSync('apps/apple/Web/qishui-security-flow.js', 'utf8'), {
    window, Promise, setTimeout: (fn, delay) => { assert.equal(delay, 120000); timer = fn; return 1; },
    clearTimeout: () => { cleared = true; },
  });
  return {window, timeout: () => timer(), state: () => ({cleared, cancelled})};
}
test('actual SDK result is preserved and challenge privilege is removed on success', async () => {
  const f = fixture(async (decision, options) => { assert.equal(decision.fixture, 1); assert.equal(options.fixture, 2); return {status: true}; });
  const result = await f.window.__qishuiAppleSecondVerify({fixture: 1}, {fixture: 2});
  assert.equal(result.status, true); assert.equal(f.window.__qishuiSecurityActive, false);
  assert.equal(f.window.__qishuiAppleCancel, null); assert.equal(f.state().cleared, true);
});
for (const action of ['cancel', 'timeout']) test(`${action} resolves even while official SDK is still loading`, async () => {
  const f = fixture(() => new Promise(() => {}));
  const result = f.window.__qishuiAppleSecondVerify({}, {});
  assert.equal(f.window.__qishuiSecurityActive, true);
  action === 'cancel' ? f.window.__qishuiAppleCancel() : f.timeout();
  assert.equal((await result).status, false);
  assert.deepEqual(f.state(), {cleared: true, cancelled: 1});
  assert.equal(f.window.__qishuiSecurityActive, false);
});
test('SDK rejection clears challenge privileges and timer', async () => {
  const f = fixture(async () => { throw new Error('SDK load failed'); });
  await assert.rejects(f.window.__qishuiAppleSecondVerify({}, {}), /SDK load failed/);
  assert.equal(f.window.__qishuiSecurityActive, false); assert.equal(f.state().cleared, true);
});
