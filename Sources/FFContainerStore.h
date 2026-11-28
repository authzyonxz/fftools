

#ifndef FF_CONTAINER_STORE_H
#define FF_CONTAINER_STORE_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FFContainerKind) {
    FFContainerKindData   = 0,
    FFContainerKindBundle = 1,
};

@interface FFContainerStore : NSObject

+ (instancetype)sharedStore;

- (nullable NSString *)dataContainerForBundleID:(NSString *)bundleID
                                           error:(NSError *_Nullable *_Nullable)error;

- (nullable NSString *)bundleContainerForBundleID:(NSString *)bundleID
                                             error:(NSError *_Nullable *_Nullable)error;

- (nullable NSString *)containerForBundleID:(NSString *)bundleID
                                       kind:(FFContainerKind)kind
                                      error:(NSError *_Nullable *_Nullable)error;

- (void)invalidateCache;

- (BOOL)pathIsDirectory:(NSString *)path;

@end

NS_ASSUME_NONNULL_END

#endif
