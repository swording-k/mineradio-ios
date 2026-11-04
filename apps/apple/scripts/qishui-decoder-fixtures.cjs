// Synthetic media only; compares against Android's reference decoder, no network or accounts.
const crypto = require('node:crypto');
const {TrackDecryptor} = require('../../../../Mineradio-Android/app/src/main/nodejs-project-src/qishui-audio-decryptor/track-decryptor');
const u = n => {const b=Buffer.alloc(4); b.writeUInt32BE(n); return b;};
const box = (type,...parts) => {const b=Buffer.concat(parts);return Buffer.concat([u(b.length+8),Buffer.from(type),b]);};
const key='00112233445566778899aabbccddeeff';
function make(flac) {
 const sample=Buffer.from('Synthetic sample payload for licensed decoder verification.');
 const iv=Buffer.from('01020304050607080000000000000000','hex');
 const cipher=crypto.createCipheriv('aes-128-ctr',Buffer.from(key,'hex'),iv);
 const encrypted=Buffer.concat([cipher.update(sample),cipher.final()]);
 const metadata=Buffer.from([0,0,0,0,128,0,0,3,1,2,3]);
 const stsd=box('stsd',Buffer.alloc(8),Buffer.from('enca'),...(flac?[box('dfLa',metadata)]:[]));
 const stsz=box('stsz',Buffer.alloc(4),u(0),u(1),u(sample.length));
 const stsc=box('stsc',Buffer.alloc(4),u(1),u(1),u(1),u(1));
 const stco=box('stco',Buffer.alloc(4),u(1),u(0));
 const senc=box('senc',Buffer.alloc(4),u(1),iv.subarray(0,8));
 const moov=box('moov',box('trak',box('mdia',box('minf',box('stbl',stsd,stsz,stsc,stco,senc)))));
 const data=Buffer.concat([box('ftyp',Buffer.from('M4A ')),moov,box('mdat',encrypted)]);
 // Resolve real chunk offset, even though older Android reference ignores it.
 const at=data.indexOf(Buffer.from('stco'));
 data.writeUInt32BE(data.indexOf(Buffer.from('mdat'))+4,at+12);
 const expected=new TrackDecryptor().decrypt({encryptedBuffer:data,spadeA:key});
 return {input:data.toString('base64'),expected:expected.buffer.toString('base64'),extension:expected.extension};
}
const decoded=Buffer.concat([Buffer.from('1'+key),Buffer.from('x')]);
const inner=Buffer.alloc(decoded.length);
for(let i=0;i<inner.length;i++){ const prev=i===0?0xfa:i===1?0x55:inner[i-2];const bits=i.toString(2).replace(/0/g,'').length;inner[i]=(decoded[i]+bits+21)^prev; }
const raw=Buffer.concat([Buffer.from([49^inner[0]^inner[1]]),inner,Buffer.from([0])]);
console.log(JSON.stringify({key,spade:raw.toString('base64'),m4a:make(false),flac:make(true)}));
