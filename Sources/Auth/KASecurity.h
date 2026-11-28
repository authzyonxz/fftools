#import <Foundation/Foundation.h>
#import <Security/Security.h>
NS_ASSUME_NONNULL_BEGIN
NSError *KAError(NSString *code);
NSString *KAB64(NSData *data);
NSData * _Nullable KAUnB64(NSString *text);
NSData *KAHash(NSData *data);
SecKeyRef _Nullable KACopyDeviceKey(NSError **error) CF_RETURNS_RETAINED;
BOOL KASaveLicense(NSString *license, NSError **error);
NSString * _Nullable KAReadLicense(NSError **error);
void KADeleteLicense(void);
NSDictionary * _Nullable KAVerifyGrant(NSString *jwt, NSString *sessionToken,
                                      NSString *installationID, NSError **error);
NS_ASSUME_NONNULL_END
