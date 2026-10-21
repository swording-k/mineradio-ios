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
  assert.equal(quality.parentNode, modes); assert.equal(mix.parentNode, modes);
  phone.matches = false; phone.rotate();
  assert.equal(quality.parentNode, qualityParent); assert.equal(mix.parentNode, transport);
  assert.equal(qualityParent.restoredNext, nextQuality); assert.equal(transport.restoredNext, nextMix);
  phone.matches = true; phone.rotate();
  assert.equal(quality.parentNode, modes); assert.equal(mix.parentNode, modes);
  assert.match(viewport.content, /viewport-fit=cover/);
  assert.match(viewport.content, /user-scalable=no/);
  assert.match(viewport.content, /maximum-scale=1/);
});

test('touch-only input cannot activate desktop left-edge queue hover', () => {
  let hover = false, originalCalls = 0;
  const element = () => ({style:{setProperty() {}},dataset:{},appendChild() {},setAttribute() {},addEventListener() {}});
  const context = {
    document: {querySelector: () => null, createElement: element, head: element(), getElementById: () => null, documentElement: element()},
    window: {matchMedia: query => query.includes('hover:') ? {get matches() {return hover;}} : {matches:true,addEventListener() {}},innerHeight:844,addEventListener() {}},
    isPlaylistEdgeTrigger: () => {originalCalls++; return true;}
  };
  vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-layout.js','utf8'),context);
  assert.equal(context.isPlaylistEdgeTrigger(1,200,844,null), false);
  assert.equal(originalCalls,0);
  hover = true;
  assert.equal(context.isPlaylistEdgeTrigger(1,200,844,null), true);
  assert.equal(originalCalls,1);
});

function touchFixture(setup) {
  const elements = {}, pending = []; let now = 0;
  function node() {
    const classes = new Set(), listeners = {};
    return {style:{setProperty() {}},dataset:{},classList:{add: (...xs)=>xs.forEach(x=>classes.add(x)),remove: (...xs)=>xs.forEach(x=>classes.delete(x)),contains:x=>classes.has(x),toggle(x,on){if(on===undefined) on=!classes.has(x);on?classes.add(x):classes.delete(x);return on;}},
      addEventListener(type,fn){(listeners[type] ||= []).push(fn);},emit(type,e){for(const fn of listeners[type]||[])fn(e);},setAttribute(){},appendChild(){},prepend(child){this.close=child;},getBoundingClientRect:()=>({height:100})};
  }
  elements['bottom-bar']=node(); elements['bottom-handle']=node();
  const context={document:{querySelector:()=>null,createElement:node,head:node(),documentElement:node(),getElementById:id=>elements[id]},
    window:Object.assign(node(),{matchMedia:q=>({matches:!q.includes('hover:'),addEventListener(){}}),innerHeight:844}),
    controlsHovering:true,controlsRevealHoldUntil:100,controlsAutoHide:true,
    holdBottomControlsVisible: ms=>{context.held=ms;},updateControlsChromeState(){},
    setTimeout:(fn,delay=0)=>{const item={fn,at:now+delay};pending.push(item);return item;},clearTimeout(item){if(item)item.cancelled=true;}};
  context.document.body=node();
  if(setup)setup(context,elements,node);
  vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-layout.js','utf8'),context);
  return {context,elements,bar:elements['bottom-bar'],handle:elements['bottom-handle'],tick(ms){now+=ms;for(const item of pending.splice(0)){if(item.at<=now&&!item.cancelled)item.fn();else pending.push(item);}}};
}
test('touch release clears sticky desktop hover and holds controls long enough to tap pause',()=>{
  const f=touchFixture();
  f.bar.emit('pointerup',{pointerType:'touch',clientX:100,clientY:100,target:{closest:()=>null}});
  f.tick(0);
  assert.equal(f.context.controlsHovering,false);
  assert(f.context.held>=3000);
});
test('downward swipe collapses bar; handle restores it without changing auto-hide preference',()=>{
  const f=touchFixture(), target={closest:()=>null};
  f.bar.emit('pointerdown',{pointerType:'touch',pointerId:1,clientX:100,clientY:100,target});
  f.bar.emit('pointerup',{pointerType:'touch',pointerId:1,clientX:102,clientY:160,target});
  assert(f.bar.classList.contains('apple-controls-collapsed'));
  f.handle.emit('click',{});
  assert(!f.bar.classList.contains('apple-controls-collapsed'));
  assert.equal(f.context.controlsAutoHide,true);
});
test('scrubbing progress is not treated as a collapse gesture',()=>{
  const f=touchFixture(), target={closest:()=>({})};
  f.bar.emit('pointerdown',{pointerType:'touch',pointerId:1,clientX:100,clientY:100,target});
  f.bar.emit('pointerup',{pointerType:'touch',pointerId:1,clientX:102,clientY:160,target});
  assert(!f.bar.classList.contains('apple-controls-collapsed'));
});

test('swipe finishing outside the bar still collapses it',()=>{
  const f=touchFixture(), target={closest:()=>null};
  f.bar.emit('pointerdown',{pointerType:'touch',pointerId:1,clientX:100,clientY:100,target});
  f.context.window.emit('pointerup',{pointerType:'touch',pointerId:1,clientX:100,clientY:165,target});
  assert(f.bar.classList.contains('apple-controls-collapsed'));
});
test('manual collapse preserves a disabled auto-hide preference',()=>{
  const f=touchFixture(), target={closest:()=>null};
  f.context.controlsAutoHide=false;
  f.bar.emit('pointerdown',{pointerType:'touch',pointerId:1,clientX:100,clientY:100,target});
  f.bar.emit('pointerup',{pointerType:'touch',pointerId:1,clientX:100,clientY:165,target});
  f.handle.emit('click',{});
  assert.equal(f.context.controlsAutoHide,false);
});

test('phone handle reveal survives a legacy half-second hide and expires only after its own idle deadline',()=>{
  const f=touchFixture();
  f.handle.emit('click',{});
  assert(f.bar.classList.contains('apple-touch-controls-open'));
  f.bar.classList.add('soft-hidden');
  f.tick(600);
  assert(f.bar.classList.contains('apple-touch-controls-open'));
  f.tick(8000);
  assert(!f.bar.classList.contains('apple-touch-controls-open'));
});

test('explicit library close clears peek as well as show and cancels a pending hover timer',()=>{
  const f=touchFixture((context,elements,node)=>{
    elements['playlist-panel']=node();
    context.peekTimers={pl:{}};
    context.togglePlaylistPanel=()=>elements['playlist-panel'].classList.remove('show');
  });
  const panel=f.elements['playlist-panel'];
  panel.classList.add('show','peek');
  panel.close.emit('click',{});
  assert(!panel.classList.contains('show'));
  assert(!panel.classList.contains('peek'));
  assert.equal(f.context.peekTimers.pl,null);
});

test('phone compatibility mouse movement cannot drive the desktop controls timer',()=>{
  let calls=0;
  const f=touchFixture(context=>{context.updateControlsAutoHideFromPointer=()=>calls++;});
  f.context.updateControlsAutoHideFromPointer(100,800);
  assert.equal(calls,0);
});
