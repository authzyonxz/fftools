#import "KASecurity.h"
#import "KAExternalClient.h"
#import <CommonCrypto/CommonDigest.h>
#import <math.h>

NSString *const KAExternalErrorDomain = @"org.keyauthv2.external";
NSString *const KAExternalDidLockNotification = @"KAExternalDidLockNotification";
static NSString *KAService(void) { return [NSString stringWithFormat:@"%@.external.license.v1", NSBundle.mainBundle.bundleIdentifier]; }

NSError *KAError(NSString *code) {
    NSDictionary *messages = @{
        @"KEY_REQUIRED": @"Digite sua key para continuar.",
        @"KEY_FORMAT": @"A key deve ter 15 caracteres: letras A–Z e números 1–9.",
        @"KEY_INVALID": @"Key inválida, pausada ou não pertencente ao EXTERNAL.",
        @"KEY_EXPIRED": @"Sua licença expirou. Renove sua key.",
        @"DEVICE_MISMATCH": @"Esta key está vinculada a outro dispositivo. Solicite o reset do HWID.",
        @"PACKAGE_UNAVAILABLE": @"O EXTERNAL está indisponível ou em manutenção. Tente mais tarde.",
        @"PACKAGE_NOT_FOUND": @"O pacote EXTERNAL não está disponível.",
        @"SESSION_EXPIRED": @"A sessão expirou. Valide sua key novamente.",
        @"SESSION_NOT_FOUND": @"A sessão terminou. Valide sua key novamente.",
        @"GRANT_INACTIVE": @"A licença deixou de estar ativa. Valide sua key novamente.",
        @"DATABASE_UNAVAILABLE": @"O serviço está temporariamente indisponível.",
        @"RATE_LIMITED": @"Muitas tentativas. Aguarde antes de tentar novamente.",
        @"NETWORK": @"Não foi possível conectar. Verifique sua internet e tente novamente.",
        @"INVALID_RESPONSE": @"O servidor enviou uma resposta inesperada. O acesso continua bloqueado.",
        @"GRANT_INVALID": @"Não foi possível confirmar a autenticidade da autorização.",
        @"CHALLENGE_INVALID": @"O desafio expirou ou é inválido. Tente novamente.",
        @"PROOF_INVALID": @"Não foi possível confirmar a identidade deste aparelho.",
        @"KEYCHAIN": @"Não foi possível acessar o Keychain. Verifique o desbloqueio e a assinatura do app.",
        @"SECURE_KEY": @"Não foi possível usar a chave protegida deste aparelho.",
        @"CANCELLED": @"A validação foi interrompida. Tente novamente.",
    };
    return [NSError errorWithDomain:KAExternalErrorDomain code:1 userInfo:@{
        NSLocalizedDescriptionKey: messages[code] ?: @"Não foi possível validar a licença. Tente novamente.",
        @"apiCode": code ?: @"UNKNOWN"
    }];
}
NSString *KAB64(NSData *data) {
    return [[[[data base64EncodedStringWithOptions:0] stringByReplacingOccurrencesOfString:@"+" withString:@"-"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"] stringByReplacingOccurrencesOfString:@"=" withString:@""];
}
NSData *KAUnB64(NSString *text) {
    if (![text isKindOfClass:NSString.class] || text.length % 4 == 1) return nil;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"];
    if ([text rangeOfCharacterFromSet:allowed.invertedSet].location != NSNotFound) return nil;
    NSString *s = [[text stringByReplacingOccurrencesOfString:@"-" withString:@"+"] stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    while (s.length % 4) s = [s stringByAppendingString:@"="];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:s options:0];
    return [KAB64(data ?: NSData.data) isEqual:text] ? data : nil;
}
NSData *KAHash(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    return [NSData dataWithBytes:digest length:sizeof(digest)];
}
static NSDictionary *KALicenseQuery(void) {
    return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecAttrService:KAService(), (__bridge id)kSecAttrAccount:@"external1",
             (__bridge id)kSecAttrSynchronizable:@NO};
}
BOOL KASaveLicense(NSString *license, NSError **error) {
    NSDictionary *attributes = @{(__bridge id)kSecValueData:[license dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly};
    OSStatus result = SecItemUpdate((__bridge CFDictionaryRef)KALicenseQuery(), (__bridge CFDictionaryRef)attributes);
    if (result == errSecItemNotFound) {
        NSMutableDictionary *query = [KALicenseQuery() mutableCopy]; [query addEntriesFromDictionary:attributes];
        result = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }
    if (result != errSecSuccess && error) *error = KAError(@"KEYCHAIN");
    return result == errSecSuccess;
}
NSString *KAReadLicense(NSError **error) {
    NSMutableDictionary *query = [KALicenseQuery() mutableCopy];
    query[(__bridge id)kSecReturnData] = @YES; query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef item = NULL; OSStatus result = SecItemCopyMatching((__bridge CFDictionaryRef)query, &item);
    if (result == errSecItemNotFound) return nil;
    if (result != errSecSuccess) { if (error) *error = KAError(@"KEYCHAIN"); return nil; }
    return [[NSString alloc] initWithData:CFBridgingRelease(item) encoding:NSUTF8StringEncoding];
}
void KADeleteLicense(void) { SecItemDelete((__bridge CFDictionaryRef)KALicenseQuery()); }
SecKeyRef KACopyDeviceKey(NSError **error) {
    NSData *tag = [[KAService() stringByAppendingString:@".device-key"] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *query = @{(__bridge id)kSecClass:(__bridge id)kSecClassKey,
        (__bridge id)kSecAttrApplicationTag:tag, (__bridge id)kSecAttrKeyType:(__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
        (__bridge id)kSecAttrTokenID:(__bridge id)kSecAttrTokenIDSecureEnclave,
        (__bridge id)kSecReturnRef:@YES};
    CFTypeRef existing = NULL; OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &existing);
    if (status == errSecSuccess) return (SecKeyRef)existing;
    if (status != errSecItemNotFound) { if (error) *error = KAError(@"KEYCHAIN"); return NULL; }
    CFErrorRef failure = NULL;
    SecAccessControlRef access = SecAccessControlCreateWithFlags(NULL, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, kSecAccessControlPrivateKeyUsage, &failure);
    if (!access) { if (failure) CFRelease(failure); if (error) *error = KAError(@"SECURE_KEY"); return NULL; }
    NSDictionary *attributes = @{(__bridge id)kSecAttrKeyType:(__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
        (__bridge id)kSecAttrKeySizeInBits:@256, (__bridge id)kSecAttrTokenID:(__bridge id)kSecAttrTokenIDSecureEnclave,
        (__bridge id)kSecPrivateKeyAttrs:@{(__bridge id)kSecAttrIsPermanent:@YES,
            (__bridge id)kSecAttrApplicationTag:tag, (__bridge id)kSecAttrAccessControl:(__bridge id)access}};
    SecKeyRef key = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &failure);
    CFRelease(access); if (failure) CFRelease(failure);
    if (!key && error) *error = KAError(@"SECURE_KEY");
    return key; // No silent fallback to an exportable private key.
}
static NSData *KADERInteger(NSData *bytes) {
    const uint8_t *p = bytes.bytes; NSUInteger start = 0;
    while (start + 1 < bytes.length && p[start] == 0) start++;
    BOOL pad = (p[start] & 0x80) != 0;
    uint8_t header[] = {0x02, (uint8_t)(bytes.length - start + (pad ? 1 : 0))};
    NSMutableData *result = [NSMutableData dataWithBytes:header length:2];
    if (pad) { uint8_t zero = 0; [result appendBytes:&zero length:1]; }
    [result appendBytes:p + start length:bytes.length - start]; return result;
}
static NSDictionary *KAJSONObject(NSData *data) {
    if (!data) return nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return [object isKindOfClass:NSDictionary.class] ? object : nil;
}
NSDictionary *KAVerifyGrant(NSString *jwt, NSString *sessionToken, NSString *installationID, NSError **error) {
    if (error) *error = KAError(@"GRANT_INVALID");
    if (jwt.length > 16384) return nil;
    NSArray *parts = [jwt componentsSeparatedByString:@"."]; if (parts.count != 3) return nil;
    NSDictionary *header = KAJSONObject(KAUnB64(parts[0]));
    if (![header[@"alg"] isEqual:@"ES256"] || ![header[@"typ"] isEqual:@"KA2+jwt"] ||
        ![header[@"kid"] isEqual:@"605JmqMJES2Jbv4b"] || header[@"crit"] != nil) return nil;
    // Public verification key extracted from the owner's server, 2026-11-27. NOT a secret.
    NSData *x = KAUnB64(@"HdZDerHU3s-XNbstavzNU1GM2yVhacHl_iYk01NmWXY");
    NSData *y = KAUnB64(@"jSblrrKkR2W1UmgIb9u22zPH-k8YUSjVQJ6x1Yre-wY");
    uint8_t prefix = 4; NSMutableData *raw = [NSMutableData dataWithBytes:&prefix length:1];
    [raw appendData:x]; [raw appendData:y];
    SecKeyRef publicKey = SecKeyCreateWithData((__bridge CFDataRef)raw, (__bridge CFDictionaryRef)@{
        (__bridge id)kSecAttrKeyType:(__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
        (__bridge id)kSecAttrKeyClass:(__bridge id)kSecAttrKeyClassPublic,
        (__bridge id)kSecAttrKeySizeInBits:@256}, NULL);
    NSData *signature = KAUnB64(parts[2]);
    if (!publicKey || signature.length != 64) { if (publicKey) CFRelease(publicKey); return nil; }
    NSData *r = KADERInteger([signature subdataWithRange:NSMakeRange(0,32)]);
    NSData *s = KADERInteger([signature subdataWithRange:NSMakeRange(32,32)]);
    uint8_t sequence[] = {0x30, (uint8_t)(r.length + s.length)};
    NSMutableData *der = [NSMutableData dataWithBytes:sequence length:2]; [der appendData:r]; [der appendData:s];
    NSData *message = [[NSString stringWithFormat:@"%@.%@", parts[0], parts[1]] dataUsingEncoding:NSUTF8StringEncoding];
    BOOL valid = SecKeyVerifySignature(publicKey, kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                      (__bridge CFDataRef)message, (__bridge CFDataRef)der, NULL);
    CFRelease(publicKey); if (!valid) return nil;
    NSDictionary *claims = KAJSONObject(KAUnB64(parts[1]));
    if (![claims[@"iss"] isEqual:@"https://keyauthv2.org"] || ![claims[@"aud"] isEqual:@"keyauth-ios"] ||
        ![claims[@"package"] isEqual:@"external1"] || ![claims[@"packageId"] isEqual:@"5d933aad-02da-4f37-a509-dfffee5600ed"] ||
        ![claims[@"installationId"] isEqual:installationID] || ![claims[@"keyStatus"] isEqual:@"active"] ||
        ![claims[@"policyVersion"] isEqual:@2] || ![claims[@"scope"] isKindOfClass:NSArray.class] ||
        ![claims[@"scope"] containsObject:@"app:open"] ||
        ![claims[@"sessionHash"] isEqual:KAB64(KAHash([sessionToken dataUsingEncoding:NSUTF8StringEncoding]))] ||
        ![claims[@"sessionId"] isKindOfClass:NSString.class] || [claims[@"sessionId"] length] == 0 ||
        ![claims[@"exp"] isKindOfClass:NSNumber.class] || ![claims[@"iat"] isKindOfClass:NSNumber.class]) return nil;
    double now = NSDate.date.timeIntervalSince1970, exp = [claims[@"exp"] doubleValue], iat = [claims[@"iat"] doubleValue];
    if (!isfinite(exp) || !isfinite(iat) || exp <= now || iat > now + 30 || exp <= iat || exp - iat > 300) return nil;
    if (error) *error = nil; return claims;
}
