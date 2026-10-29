const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('public/js/modules/09-idle-toast-libraries.js', 'utf8');
const fn = source.slice(source.indexOf('function positionVisualGuideStep()'), source.indexOf('function nextVisualGuideStep()'));
function layout(w, h, rect, naturalHeight = 260, viewport) {
  const ring = { style: {}, classList: { toggle() {} } };
  const card = { style: {}, get offsetHeight() { return Math.min(naturalHeight, parseFloat(this.style.maxHeight) || Infinity); } };
  const guide = { querySelector() { return null; } };
  const context = { innerWidth: w, innerHeight: h, visualGuideActive: true, visualGuideStep: 0,
    window: { visualViewport: viewport, getComputedStyle() { return { paddingTop: '12', paddingRight: '12', paddingBottom: '12', paddingLeft: '12' }; } },
    document: { getElementById(id) { return { 'visual-guide': guide, 'visual-guide-ring': ring, 'visual-guide-card': card }[id]; } },
    activeVisualGuideSteps() { return [{}]; }, guideTargetRect() { return rect; } };
  vm.runInNewContext(fn + ';positionVisualGuideStep()', context);
  return { ring: ring.style, card: card.style };
}
for (const [w, h] of [[320,568], [393,852], [667,320], [852,393], [1024,768]]) {
  test(`guide stays visible at ${w}x${h}`, () => {
    const { card, ring } = layout(w,h,{left:w-20,top:h+20,right:w+80,bottom:h+80,width:100,height:60}, 420);
    assert.ok(parseFloat(card.top) + Math.min(420,parseFloat(card.maxHeight) || Infinity) <= h-12);
    assert.ok(parseFloat(ring.left)+parseFloat(ring.width) <= w-12);
    assert.ok(parseFloat(ring.top)+parseFloat(ring.height) <= h-12);
    assert.ok(parseFloat(ring.height) >= 0);
  });
}
test('visible viewport after keyboard or browser resize bounds the guide', () => {
  const {card} = layout(393,852,{left:10,top:500,right:100,bottom:550,width:90,height:50},300,{offsetLeft:0,offsetTop:40,width:393,height:260});
  assert.ok(parseFloat(card.top)>=52);
  assert.ok(parseFloat(card.top)+Math.min(300,parseFloat(card.maxHeight)||Infinity)<=288);
});
