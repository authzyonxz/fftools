const crypto=require('node:crypto'),fs=require('node:fs');
const {privateKey,publicKey}=crypto.generateKeyPairSync('ec',{namedCurve:'prime256v1'});
const jwk=publicKey.export({format:'jwk'}),token='synthetic-session',installation='synthetic-installation';
const now=Math.floor(Date.now()/1000);
const header={alg:'ES256',typ:'KA2+jwt',kid:'605JmqMJES2Jbv4b'};
const claims={iss:'https://keyauthv2.org',aud:'keyauth-ios',package:'external1',packageId:'5d933aad-02da-4f37-a509-dfffee5600ed',installationId:installation,sessionId:'synthetic-session-id',sessionHash:crypto.createHash('sha256').update(token).digest('base64url'),keyStatus:'active',policyVersion:2,scope:['app:open'],iat:now,exp:now+300};
function sign(c=claims,h=header) {const text=[h,c].map(x=>Buffer.from(JSON.stringify(x)).toString('base64url')).join('.');return text+'.'+crypto.sign('sha256',Buffer.from(text),{key:privateKey,dsaEncoding:'ieee-p1363'}).toString('base64url');}
const cases=[{name:'valid',jwt:sign(),ok:true}];
for(const [name,change] of Object.entries({wrong_package:{package:'another'},wrong_id:{packageId:'another'},wrong_issuer:{iss:'https://wrong.invalid'},wrong_audience:{aud:'wrong'},wrong_device:{installationId:'another'},wrong_session:{sessionHash:'another'},expired:{iat:now-400,exp:now-100},long_lifetime:{exp:now+301},missing_scope:{scope:[]},inactive:{keyStatus:'paused'},wrong_policy:{policyVersion:3},invalid_exp_type:{exp:'tomorrow'}})) cases.push({name,jwt:sign({...claims,...change}),ok:false});
cases.push({name:'wrong_algorithm',jwt:sign(claims,{...header,alg:'HS256'}),ok:false});
cases.push({name:'unknown_key',jwt:sign(claims,{...header,kid:'unknown'}),ok:false});
const damaged=sign().split('.');const signature=Buffer.from(damaged[2],'base64url');signature[0]^=1;damaged[2]=signature.toString('base64url');
cases.push({name:'tampered_signature',jwt:damaged.join('.'),ok:false},{name:'malformed',jwt:'broken',ok:false});
fs.mkdirSync('.validation',{recursive:true});
fs.writeFileSync('.validation/grants.json',JSON.stringify({token,installation,cases}));

const source=fs.readFileSync('Sources/Auth/KASecurity.m','utf8').replace('HdZDerHU3s-XNbstavzNU1GM2yVhacHl_iYk01NmWXY',jwk.x).replace('jSblrrKkR2W1UmgIb9u22zPH-k8YUSjVQJ6x1Yre-wY',jwk.y);
fs.writeFileSync('.validation/KASecurity-test.m',source);
