// Synthetic credentials only. No network or production keys.
const crypto = require('node:crypto');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const cli = process.argv[2];
const token = 'wqd_' + 'T'.repeat(43);
const key = crypto.createHash('sha256').update('wqdash:transport:v1:' + token).digest();
const run = (mode, lines, credential = token) => cp.spawnSync(cli,[mode], {input:[credential,...lines].join('\n')+'\n', encoding:'utf8'});
function encryptNode(text) {
  const iv = crypto.randomBytes(12), cipher = crypto.createCipheriv('aes-256-gcm',key,iv);
  const ciphertext = Buffer.concat([cipher.update(text,'utf8'),cipher.final()]);
  return [iv,ciphertext,cipher.getAuthTag()].map(b=>b.toString('base64url'));
}
let checks = 0;
for (const value of [{command:'packages.list'}, {command:'keys.validate',key:'TESTONLYABCDEFG',packageId:2,deviceId:'synthetic-device'}, {ok:true,result:{valid:false,reason:'key_paused'}}, {message:'Licença — EXTERNAL ✓'}]) {
  const text = JSON.stringify(value), node = encryptNode(text);
  let result = run('decrypt',node); assert.equal(result.status,0); assert.equal(result.stdout.trim(),text); checks++;
  result = run('encrypt',[text]); assert.equal(result.status,0);
  const [iv,ciphertext,tag] = result.stdout.trim().split('\n').map(s=>Buffer.from(s,'base64url'));
  const decipher = crypto.createDecipheriv('aes-256-gcm',key,iv); decipher.setAuthTag(tag);
  assert.equal(Buffer.concat([decipher.update(ciphertext),decipher.final()]).toString(),text); checks++;
  for (let field=0;field<3;field++) {
    const damaged=[...node], b=Buffer.from(damaged[field],'base64url');b[0]^=1;damaged[field]=b.toString('base64url');
    result=run('decrypt',damaged);assert.notEqual(result.status,0);assert.equal(result.stdout,'');checks++;
  }
  assert.notEqual(run('decrypt',node,'wqd_'+'X'.repeat(43)).status,0);checks++;
}
assert.notEqual(run('decrypt',['@@@','AA','AA']).status,0);checks++;
assert.notEqual(run('encrypt',['x'.repeat(48001)]).status,0);checks++;
assert.equal(run('encrypt',['x'.repeat(48000)]).status,0);checks++;
assert.notEqual(run('encrypt',['{}']).stdout,run('encrypt',['{}']).stdout);checks++;
console.log(`${checks} AES interoperability/negative checks passed (Node.js ↔ C++).`);
