'use strict';
// FPP1 payload container.
//
//   magic "FPP1" | IV (16) | HMAC-SHA256 (32) | ciphertext (AES-256-CBC, PKCS7)
//
// key_enc = SHA256(masterSecret | "enc" | functionID | "|" | gameID)
// key_mac = SHA256(masterSecret | "mac" | functionID | "|" | gameID)
// hmac    = HMAC-SHA256(key_mac, IV | ciphertext)
//
// The app derives the same keys from its embedded secret; the ciphertext in the
// IPA (well, in transit) is useless without it.

const crypto = require('node:crypto');

const MAGIC = Buffer.from('FPP1', 'ascii');

function deriveKey(secret, tag, functionId, gameId) {
  return crypto
    .createHash('sha256')
    .update(`${secret}|${tag}|${functionId}|${gameId}`)
    .digest();
}

function encryptFile(plain, { secret, functionId, gameId }) {
  if (!secret || secret.length < 16) throw new Error('MASTER_SECRET ausente ou curto (>=16)');
  const keyEnc = deriveKey(secret, 'enc', functionId, gameId);
  const keyMac = deriveKey(secret, 'mac', functionId, gameId);
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-cbc', keyEnc, iv);
  const ciphertext = Buffer.concat([cipher.update(plain), cipher.final()]);
  const hmac = crypto.createHmac('sha256', keyMac).update(iv).update(ciphertext).digest();
  return Buffer.concat([MAGIC, iv, hmac, ciphertext]);
}

function decryptFile(pack, { secret, functionId, gameId }) {
  if (!Buffer.isBuffer(pack) || pack.length < 4 + 16 + 32 + 16) throw new Error('pack curto');
  if (!pack.subarray(0, 4).equals(MAGIC)) throw new Error('magic inválido');
  const iv = pack.subarray(4, 20);
  const hmac = pack.subarray(20, 52);
  const ciphertext = pack.subarray(52);
  const keyEnc = deriveKey(secret, 'enc', functionId, gameId);
  const keyMac = deriveKey(secret, 'mac', functionId, gameId);
  const expected = crypto.createHmac('sha256', keyMac).update(iv).update(ciphertext).digest();
  if (!crypto.timingSafeEqual(expected, hmac)) throw new Error('HMAC não confere');
  const decipher = crypto.createDecipheriv('aes-256-cbc', keyEnc, iv);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]);
}

function sha256Hex(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

module.exports = { encryptFile, decryptFile, sha256Hex, deriveKey, MAGIC };
