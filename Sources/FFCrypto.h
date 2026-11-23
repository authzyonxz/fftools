//
//  FFCrypto.h
//  FFPatch — FPP1 payload container decoder (mirror of ffpatch-site/lib/crypto.js).
//
//  magic "FPP1" | IV (16) | HMAC-SHA256 (32) | ciphertext (AES-256-CBC, PKCS7)
//  key_enc = SHA256(masterSecret | "enc" | functionID | "|" | gameID)
//  key_mac = SHA256(masterSecret | "mac" | functionID | "|" | gameID)
//  hmac    = HMAC-SHA256(key_mac, IV | ciphertext)
//

#ifndef FF_CRYPTO_H
#define FF_CRYPTO_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/**
 * Decrypts a FPP1 pack. Returns nil and fills `error` when:
 *   - the magic is wrong, the pack is truncated,
 *   - the HMAC does not match (tampered pack / wrong secret),
 *   - AES padding is invalid.
 */
NSData *_Nullable FFDecryptPack(NSData *pack,
                                NSString *functionID,
                                NSString *gameID,
                                NSError *_Nullable *_Nullable error);

/** SHA-256 of a runtime data blob, lowercase hex (already used by FFCore). */
NSString *FFSHA256HexOfData(NSData *data);

NS_ASSUME_NONNULL_END

#endif /* FF_CRYPTO_H */
