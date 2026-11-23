//
//  FFLicense.h
//  FFPatch — API-backed package, expiry and validation state.
//

#ifndef FF_LICENSE_H
#define FF_LICENSE_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const FFLicenseDidUpdateNotification;

@interface FFLicense : NSObject

@property (nonatomic, copy) NSString *key;                // Retained for local compatibility; never shown in Perfil.
@property (nonatomic, copy) NSString *duration;           // API expiry date / status text.
@property (nonatomic, copy) NSString *packageName;        // Package name returned by Logos API.
@property (nonatomic, copy) NSString *compatibleRanges;
@property (nonatomic, copy) NSString *build;
@property (nonatomic, copy) NSString *status;             // API validation status.
@property (nonatomic, assign, readonly) BOOL apiValidated;
@property (nonatomic, assign, readonly) BOOL apiValidationPending;

/* Device rows shown under the profile card. */
@property (nonatomic, copy) NSString *deviceModel;
@property (nonatomic, copy) NSString *deviceOS;
@property (nonatomic, copy) NSString *deviceBuild;
@property (nonatomic, copy) NSString *sandboxBackend;
@property (nonatomic, copy) NSString *accessStatus;

+ (instancetype)current;
- (void)validateWithCompletion:(nullable void (^)(BOOL isValid))completion;
- (NSString *)summaryText;

@end

NS_ASSUME_NONNULL_END

#endif /* FF_LICENSE_H */
