#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString *const KAExternalErrorDomain;
FOUNDATION_EXPORT NSString *const KAExternalDidLockNotification;
typedef void (^KACompletion)(NSDictionary * _Nullable license, NSError * _Nullable error);

// Main-thread API. The server is the authority; never persist a local "licensed" flag.
@interface KAExternalClient : NSObject
- (void)loginWithLicense:(NSString *)license remember:(BOOL)remember completion:(KACompletion)completion;
- (void)authorizeOperation:(KACompletion)completion;
- (void)revalidate:(KACompletion)completion;
- (void)invalidate;
- (void)forgetLicense;
// Callback supplies an authenticated request only after online revalidation.
// Only /api/v1/functions/:id/(payload|original) is allowed, never /3106.
- (void)requestForFunction:(NSString *)functionID original:(BOOL)original
               completion:(void (^)(NSURLRequest * _Nullable request, NSError * _Nullable error))completion;
@end
NS_ASSUME_NONNULL_END
