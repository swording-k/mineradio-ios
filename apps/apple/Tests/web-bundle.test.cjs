'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { buildWebBundle } = require('../scripts/build-web-bundle.cjs');

test('Apple bundle preserves original module order and avoids synchronous network loading', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'mineradio-web-bundle-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const publicDir = path.join(root, 'public');
  fs.mkdirSync(path.join(publicDir, 'js'), { recursive: true });
  fs.writeFileSync(path.join(publicDir, 'js/index-loader.js'), "const modulePaths = ['js/a.js', 'js/b.js'];");
  fs.writeFileSync(path.join(publicDir, 'js/a.js'), 'var first = 1;\n');
  fs.writeFileSync(path.join(publicDir, 'js/b.js'), 'var second = first + 1;\n');
  const result = buildWebBundle(publicDir, path.join(root, 'output'));
  assert.equal(result.moduleCount, 2);
  assert.equal(fs.readFileSync(path.join(root, 'output/index-modules.js'), 'utf8'), 'var first = 1;\n\nvar second = first + 1;\n');
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'output/manifest.json')));
  assert.deepEqual(manifest.modules.map(x => x.path), ['js/a.js', 'js/b.js']);
  assert(manifest.modules.every(x => /^[a-f0-9]{64}$/.test(x.sha256)));
});

test('Apple bundle rejects module paths outside public assets', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'mineradio-bundle-traversal-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.mkdirSync(path.join(root, 'js'));
  fs.writeFileSync(path.join(root, 'js/index-loader.js'), "const modulePaths = ['../private.js'];");
  assert.throws(() => buildWebBundle(root, path.join(root, 'output')), /module path/i);
});
