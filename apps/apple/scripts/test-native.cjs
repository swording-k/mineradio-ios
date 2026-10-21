'use strict';
const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../../..');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'mineradio-native-tests-'));
const src = names => names.map(name => `apps/apple/Sources/${name}.swift`);
const providers = ['NeteaseContract','QQMusicNativeAPI','KugouContract','KugouTransport','KugouNativeAPI','QishuiCatalogContract','QishuiCatalogAPI','AppleMediaPolicy'];
const netease = ['NeteaseEAPI','NeteaseContract','NeteaseTransport','NeteaseNativeAPI'];
const suites = [
  ['EndpointPolicyTests', ['EndpointPolicy']],
  ['NeteaseContractTests', ['NeteaseEAPI','NeteaseContract']],
  ['NeteaseRoutesTests', netease],
  ['OfficialLoginPolicyTests', ['OfficialLoginPolicy']],
  ['QQMusicNativeTests', ['QQMusicNativeAPI']],
  ['KugouNativeTests', ['KugouContract','KugouTransport','KugouNativeAPI']],
  ['QishuiAuthContractTests', ['QishuiAuthContract']],
  ['QishuiCatalogTests', ['QishuiCatalogContract','QishuiCatalogAPI']],
  ['AppleMediaPolicyTests', providers],
  ['MediaStreamTests', [...providers,'NeteaseMediaStream']],
  ['LoopbackServiceTests', [...new Set([...providers,...netease,'NeteaseMediaStream','AppleLocalService','QishuiAuthRuntime','QishuiAuthContract'])]],
];
function run(command, args) {
  const result = spawnSync(command, args, {cwd: root, stdio: 'inherit'});
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed (${result.status})`);
}
try {
  run(process.execPath, ['apps/apple/scripts/build-web-bundle.cjs']);
  const tests = fs.readdirSync(path.join(root,'apps/apple/Tests')).filter(file => file.endsWith('.cjs')).map(file => `apps/apple/Tests/${file}`);
  run(process.execPath, ['--test', ...tests]);
  for (const [name, sources] of suites) {
    process.stdout.write(`\n${name}\n`);
    const binary = path.join(temporary, name);
    run('xcrun', ['swiftc', ...src(sources), `apps/apple/Tests/${name}.swift`, '-o', binary]);
    if (!fs.existsSync(binary)) throw new Error('Compiler did not create a test executable');
    run(binary, []);
  }
} finally { fs.rmSync(temporary, {recursive: true, force: true}); }
