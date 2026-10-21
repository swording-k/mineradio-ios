const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

test('rotation preserves control identity and restores original parents and order on iPad', () => {
  function node() {
    return {style: {setProperty() {}}, dataset: {}, setAttribute() {}, addEventListener() {},
      appendChild(child) { child.parentNode = this; },
      insertBefore(child, next) { child.parentNode = this; this.restoredNext = next; }};
  }
  const quality = node(), mix = node(), qualityParent = node(), transport = node();
  const modes = node(), actions = node(), nextQuality = node(), nextMix = node();
  quality.parentNode = qualityParent; quality.nextSibling = nextQuality;
  mix.parentNode = transport; mix.nextSibling = nextMix;
  const phone = {matches: true, addEventListener(_, callback) { this.rotate = callback; }};
  const ids = {'quality-control': quality, 'cuefield-automix-btn': mix};
  const viewport = {content: 'width=device-width'};
  vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-layout.js', 'utf8'), {
    document: {querySelector: selector => selector.startsWith('meta') ? viewport : selector.endsWith('.modes') ? modes : actions,
      createElement: node, head: node(), getElementById: id => ids[id], documentElement: node()},
    window: {matchMedia: () => phone, innerHeight: 844, addEventListener() {}}
  });
  assert.equal(quality.parentNode, modes); assert.equal(mix.parentNode, actions);
  phone.matches = false; phone.rotate();
  assert.equal(quality.parentNode, qualityParent); assert.equal(mix.parentNode, transport);
  assert.equal(qualityParent.restoredNext, nextQuality); assert.equal(transport.restoredNext, nextMix);
  phone.matches = true; phone.rotate();
  assert.equal(quality.parentNode, modes); assert.equal(mix.parentNode, actions);
  assert.match(viewport.content, /viewport-fit=cover/);
});
