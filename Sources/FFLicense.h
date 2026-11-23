//
//  FFLicense.h
//  FFPatch — profile tab data: key, duration, package, supported versions, build.
//

#ifndef FF_LICENSE_H
#define FF_LICENSE_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFLicense : NSObject

@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *duration;          // "30 dias" / "expira em 23/12/2026"
@property (nonatomic, copy) NSString *packageName;       // com.daddy.ffpatch
@property (nonatomic, copy) NSString *compatibleRanges;  // "iOS 17.0–18.7.1 · ..."
@property (nonatomic, copy) NSString *build;             // "1 (0.1.0)"
@property (nonatomic, copy) NSString *status;            // "ATIVA" / "EXPIRADA" / "LOCAL"

/* Device rows shown under the profile card. */
@property (nonatomic, copy) NSString *deviceModel;
@property (nonatomic, copy) NSString *deviceOS;
@property (nonatomic, copy) NSString *deviceBuild;
@property (nonatomic, copy) NSString *sandboxBackend;
@property (nonatomic, copy) NSString *accessStatus;

+ (instancetype)current;
- (NSString *)summaryText;

@end

NS_ASSUME_NONNULL_END

#endif /* FF_LICENSE_H */
