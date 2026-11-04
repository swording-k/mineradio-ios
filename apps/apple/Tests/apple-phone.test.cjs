const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
function fixture(){
 const listeners={};
 function node(){return {children:[],classList:{contains:()=>false,add(){}},setAttribute(){},addEventListener(){},querySelector:()=>null,appendChild(n){this.children.push(n);}};}
 const dialog=node(),head=node(),graph=node(),modal=node();
 dialog.children=[head,graph];Object.defineProperty(head,'nextSibling',{get:()=>graph});dialog.firstChild=head;
 dialog.querySelector=q=>q==='.login-panel-head'?head:null;
 dialog.insertBefore=(n,next)=>dialog.children.splice(dialog.children.indexOf(next),0,n);
 modal.querySelector=()=>dialog;
 const root=node();
 const c={window:{matchMedia:()=>({matches:false})},document:{head:root,getElementById:id=>id==='login-modal'?modal:null,querySelector:()=>null,
 createElement:()=>{const n=node();n.querySelector=()=>node();return n;},addEventListener(type,fn){listeners[type]=fn;}},MutationObserver:class{observe(){}},setTimeout(){}};
 vm.runInNewContext(fs.readFileSync('apps/apple/Web/apple-phone.js','utf8'),c);
 return {dialog,head,graph,styles:root.children,listeners};
}
test('phone login keeps header before rotation help in normal document order',()=>{
 const f=fixture();assert.equal(f.dialog.children[0],f.head);assert.equal(f.dialog.children[1].id,'apple-login-rotate-tip');assert.equal(f.dialog.children[2],f.graph);
});
