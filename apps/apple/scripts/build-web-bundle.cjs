'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

function buildWebBundle(publicDir, outputDir, adapterPath) {
  const loader = fs.readFileSync(path.join(publicDir, 'js/index-loader.js'), 'utf8');
  const block = loader.match(/const modulePaths\s*=\s*\[([\s\S]*?)\];/);
  if (!block) throw new Error('Original module list is missing');
  const paths = [...block[1].matchAll(/'([^']+)'/g)].map(match => match[1]);
  if (!paths.length) throw new Error('Original module list is empty');
  const modules = paths.map(relative => {
    if (!/^[a-zA-Z0-9_\-/]+\.js$/.test(relative) || relative.startsWith('/') || relative.split('/').includes('..')) {
      throw new Error('Invalid module path');
    }
    const source = fs.readFileSync(path.join(publicDir, relative), 'utf8');
    return { path: relative, source, sha256: crypto.createHash('sha256').update(source).digest('hex') };
  });
  const adapterPaths = adapterPath ? (Array.isArray(adapterPath) ? adapterPath : [adapterPath]) : [];
  const adapter = adapterPaths.map(file => fs.readFileSync(file, 'utf8')).join('\n');
  const bundle = modules.map(item => item.source).join('\n') + (adapter ? '\n' + adapter : '');
  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(path.join(outputDir, 'index-modules.js'), bundle);
  fs.writeFileSync(path.join(outputDir, 'manifest.json'), JSON.stringify({
    moduleCount: modules.length,
    appleAdapterSha256: adapter ? crypto.createHash('sha256').update(adapter).digest('hex') : null,
    modules: modules.map(({ path, sha256 }) => ({ path, sha256 })),
    bundleSha256: crypto.createHash('sha256').update(bundle).digest('hex'),
  }, null, 2) + '\n');
  return { moduleCount: modules.length, bytes: Buffer.byteLength(bundle) };
}

module.exports = { buildWebBundle };
if (require.main === module) {
  const root = path.resolve(__dirname, '../../..');
  const result = buildWebBundle(path.join(root, 'public'), path.resolve(__dirname, '../GeneratedWeb'), [path.resolve(__dirname, '../Web/apple-runtime.js'), path.resolve(__dirname, '../Web/apple-login.js')]);
  process.stdout.write(`Apple web bundle: ${result.moduleCount} original modules, ${result.bytes} bytes\n`);
}
