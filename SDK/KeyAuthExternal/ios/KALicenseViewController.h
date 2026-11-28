#import <UIKit/UIKit.h>
#import "KAExternalClient.h"
NS_ASSUME_NONNULL_BEGIN
@interface KALicenseViewController : UIViewController
- (instancetype)initWithClient:(KAExternalClient *)client onAuthorized:(void (^)(NSDictionary *license))onAuthorized;
@end

// Install as window.rootViewController. Factory is called ONLY after successful online authorization.
@interface KAProtectedRootController : UIViewController
- (instancetype)initWithContentFactory:(UIViewController * (^)(KAExternalClient *client, NSDictionary *license))factory;
@end
NS_ASSUME_NONNULL_END
