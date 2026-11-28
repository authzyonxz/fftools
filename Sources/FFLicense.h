

#ifndef FF_LICENSE_H
#define FF_LICENSE_H

#import <Foundation/Foundation.h>
#import "KAExternalClient.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const FFLicenseDidUpdateNotification;

@interface FFLicense : NSObject

@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *duration;
@property (nonatomic, copy) NSString *packageName;
@property (nonatomic, copy) NSString *compatibleRanges;
@property (nonatomic, copy) NSString *build;
@property (nonatomic, copy) NSString *status;
@property (atomic, assign, readonly) BOOL apiValidated;

@property (nonatomic, copy) NSString *deviceModel;
@property (nonatomic, copy) NSString *deviceOS;
@property (nonatomic, copy) NSString *deviceBuild;
@property (nonatomic, copy) NSString *sandboxBackend;
@property (nonatomic, copy) NSString *accessStatus;

+ (instancetype)current;
- (void)adoptClient:(KAExternalClient *)client license:(NSDictionary *)license;
- (BOOL)ensureAuthorizedWithError:(NSError **)error;
- (NSString *)summaryText;

@end

NS_ASSUME_NONNULL_END

#endif
