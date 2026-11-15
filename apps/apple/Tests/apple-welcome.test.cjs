const {test}=require('node:test'), assert=require('node:assert/strict'), fs=require('node:fs'), vm=require('node:vm');
const shared=fs.readFileSync('public/js/modules/08-account/00-login-easter-egg.js','utf8');
const adapter=fs.readFileSync('apps/apple/Web/apple-welcome.js','utf8');
function fixture({saved=false, logged=false}={}) {
  const key='mineradio-login-easter-egg-browser-preview-v1', values=new Map(saved?[[key,'1']]:[]), calls=[];
  const node=()=>{const cls=new Set();return {children:[],classList:{contains:c=>cls.has(c),toggle:(c,on)=>on?cls.add(c):cls.delete(c)},setAttribute(){},appendChild(x){this.children.push(x)},focus(){this.focused=true}}};
  const hero=node(), gate=node(), modal=node(), first=node();
  const context={window:{},localStorage:{getItem:k=>values.get(k),setItem:(k,v)=>values.set(k,v)},document:{head:node(),readyState:'loading',createElement:node,addEventListener(){},querySelector:s=>s.includes('home-hero')?hero:first,getElementById:id=>({'login-easter-egg-gate':gate,'login-modal':modal})[id]},
    hasAnyPlatformLogin:()=>logged,renderUserBtn:()=>{},resumeLoginModalAfterGate:()=>calls.push('platforms'),triggerUploadInput:k=>calls.push(k),showLoginModal:()=>{modal.classList.toggle('show',true);return context.prepareLoginEasterEggGate()}};
  vm.runInNewContext(shared,context);vm.runInNewContext(adapter,context);
  return {hero,gate,modal,first,calls,context,values,key};
}
test('fresh install can connect from Home and unlock once without avatar taps or a keyboard',async()=>{
  const f=fixture(), home=f.hero.children[0];await f.context.ensureLoginEasterEggStatus();f.context.renderUserBtn();
  assert.equal(home.hidden,false);
  await home.children.find(b=>b.textContent==='连接音乐平台').onclick();
  const button=f.gate.children[0].children.find(e=>e.type==='button');assert(button.focused);
  assert.equal(f.values.get(f.key),undefined);
  await button.onclick();
  assert.equal(f.values.get(f.key),'1'); assert.deepEqual(f.calls,['platforms']);assert(f.first.focused);assert(home.hidden);
});
test('returning listeners keep their dashboard; local import neither opens the gate nor unlocks it',async()=>{
  for (const options of [{saved:true},{logged:true}]) {
    const f=fixture(options);await f.context.ensureLoginEasterEggStatus();f.context.renderUserBtn();
    assert(f.hero.children[0].hidden);
  }
  const f=fixture();f.hero.children[0].children.find(b=>b.textContent==='导入本地音乐').onclick();
  assert.deepEqual(f.calls,['audio']);assert.equal(f.values.get(f.key),undefined);
});
test('unavailable persistence leaves a visible, retryable gate instead of claiming success',async()=>{
  const f=fixture(); f.context.localStorage.setItem=()=>{throw Error('unavailable')};
  await f.context.showLoginModal();const panel=f.gate.children[0], button=panel.children.find(e=>e.type==='button');
  await button.onclick(); assert.deepEqual(f.calls,[]); assert.equal(button.disabled,false);
  assert.match(panel.children.at(-1).textContent,/重试/);
});
