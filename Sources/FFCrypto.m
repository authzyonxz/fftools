

#import "FFCrypto.h"
#import "FFCore.h"
#import "FFProtect.h"

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

static NSData *FFDariveKeyWithSecret(NSData *secret, NSString *tag, NSString *functionID, NSString *gameID) {

    NSMutableData *buffer = [NSMutableData data];
    NSData *secretBytes = secret;
    if (secretBytes == nil) return nil;
    [buffer appendData:secretBytes];
    [buffer appendData:[@"|" dataUsingEncoding:NSUTF8StringEncoding]];
    [buffer appendData:[tag dataUsingEncoding:NSUTF8StringEncoding]];
    [buffer appendData:[@"|" dataUsingEncoding:NSUTF8StringEncoding]];
    [buffer appendData:[functionID dataUsingEncoding:NSUTF8StringEncoding]];
    [buffer appendData:[@"|" dataUsingEncoding:NSUTF8StringEncoding]];
    [buffer appendData:[gameID dataUsingEncoding:NSUTF8StringEncoding]];

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(buffer.bytes, (CC_LONG)buffer.length, digest);
    return [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
}

NSData *FFDecryptPack(NSData *pack, NSString *functionID, NSString *gameID, NSError **error) {
    if (pack.length < 4 + 16 + 32 + 16) {
        if (error) *error = FFMakeError(FFErrorVerifyFailed, @"pack curto");
        return nil;
    }
    const unsigned char *bytes = pack.bytes;
    if (memcmp(bytes, "FPP1", 4) != 0) {
        if (error) *error = FFMakeError(FFErrorVerifyFailed, @"magic FPP1 ausente");
        return nil;
    }

    NSData *iv = [pack subdataWithRange:NSMakeRange(4, 16)];
    NSData *packedHMAC = [pack subdataWithRange:NSMakeRange(20, 32)];
    NSData *ciphertext = [pack subdataWithRange:NSMakeRange(52, pack.length - 52)];

    NSData *secret = FFMasterSecret();
    if (secret == nil) {
        if (error) *error = FFMakeError(FFErrorInvalidPayload, @"segredo do app ausente");
        return nil;
    }

    NSData *keyEnc = FFDariveKeyWithSecret(secret, @"enc", functionID, gameID);
    NSData *keyMac = FFDariveKeyWithSecret(secret, @"mac", functionID, gameID);
    if (keyEnc == nil || keyMac == nil) {
        if (error) *error = FFMakeError(FFErrorInvalidPayload, @"derivação de chave falhou");
        return nil;
    }

    NSMutableData *macInput = [NSMutableData dataWithData:iv];
    [macInput appendData:ciphertext];
    unsigned char computed[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, keyMac.bytes, keyMac.length, macInput.bytes, macInput.length, computed);
    if (memcmp(computed, packedHMAC.bytes, CC_SHA256_DIGEST_LENGTH) != 0) {
        if (error) *error = FFMakeError(FFErrorVerifyFailed, @"HMAC não confere");
        return nil;
    }

    size_t outputLength = ciphertext.length + kCCBlockSizeAES128;
    NSMutableData *plain = [NSMutableData dataWithLength:outputLength];
    size_t moved = 0;
    CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES,
                                     kCCOptionPKCS7Padding,
                                     keyEnc.bytes, keyEnc.length,
                                     iv.bytes,
                                     ciphertext.bytes, ciphertext.length,
                                     plain.mutableBytes, outputLength,
                                     &moved);
    if (status != kCCSuccess) {
        if (error) *error = FFMakeError(FFErrorVerifyFailed, @"AES falhou (%d)", (int)status);
        return nil;
    }
    plain.length = moved;
    return plain;
}
