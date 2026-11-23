//
//  FFContainerStore.h
//  FFPatch — bundle identifier → container path resolution, no jailbreak.
//
//  Resolution order (all paths are tried until one yields a directory we can
//  actually stat):
//    1. worse_query container index        (identifier → path, iOS 26.7+/27)
//    2. MobileContainerManager query       (container_query_* via mcm_bridge)
//    3. container metadata plist scan      (/var/mobile/Containers/Data/Application)
//
//  The first two come from the 3106 base; the third is the plain-filesystem
//  fallback that still works once a sandbox grant is in place.
//

#ifndef FF_CONTAINER_STORE_H
#define FF_CONTAINER_STORE_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FFContainerKind) {
    FFContainerKindData   = 0,  // /var/mobile/Containers/Data/Application/<uuid>
    FFContainerKindBundle = 1,  // /var/containers/Bundle/Application/<uuid>/X.app
};

@interface FFContainerStore : NSObject

+ (instancetype)sharedStore;

/*! Resolves the data container of `bundleID` (e.g. com.dts.freefireth). */
- (nullable NSString *)dataContainerForBundleID:(NSString *)bundleID
                                           error:(NSError *_Nullable *_Nullable)error;

/*! Resolves the .app bundle path of `bundleID` (install container). */
- (nullable NSString *)bundleContainerForBundleID:(NSString *)bundleID
                                             error:(NSError *_Nullable *_Nullable)error;

/*! Data container for the given kind (bundle lookup delegates to the method above). */
- (nullable NSString *)containerForBundleID:(NSString *)bundleID
                                       kind:(FFContainerKind)kind
                                      error:(NSError *_Nullable *_Nullable)error;

/*! Drops every cached resolution (call after an OS/app update or a re-sign). */
- (void)invalidateCache;

/*! YES when a path exists, is a directory and is not a symlink. */
- (BOOL)pathIsDirectory:(NSString *)path;

@end

NS_ASSUME_NONNULL_END

#endif /* FF_CONTAINER_STORE_H */
