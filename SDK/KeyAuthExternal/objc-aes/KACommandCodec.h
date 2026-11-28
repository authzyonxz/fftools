#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// OPTIONAL legacy integration adapter; not part of the EXTERNAL iOS license flow.
// Requires cpp/Transport.cpp plus a trusted, maintained OpenSSL 3 library.
@interface KACommandCodec : NSObject
+ (nullable NSDictionary *)encryptCommand:(NSDictionary *)command token:(NSString *)token error:(NSError **)error;
+ (nullable NSDictionary *)decryptEnvelope:(NSDictionary *)envelope token:(NSString *)token error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
