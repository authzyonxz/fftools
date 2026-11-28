

#ifndef FF_LAUNCH_SERVICES_STORE_H
#define FF_LAUNCH_SERVICES_STORE_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFLaunchServicesSnapshot : NSObject
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *containerBundleIDs;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *displayNames;
@property (nonatomic, copy) NSString *layoutLabel;
@property (nonatomic, assign) NSUInteger mappedContainerCount;
- (nullable NSString *)containerPathForBundleID:(NSString *)bundleID;
- (nullable NSString *)bundleIDForContainerPath:(NSString *)path;
@end

@interface FFLaunchServicesStore : NSObject

+ (nullable FFLaunchServicesSnapshot *)snapshot;

+ (void)invalidateSnapshot;

+ (NSString *)canonicalContainerPath:(NSString *)path;

+ (BOOL)isDataContainerPath:(NSString *)path;

+ (BOOL)looksLikeBundleIdentifier:(NSString *)value;

@end

NS_ASSUME_NONNULL_END

#endif
