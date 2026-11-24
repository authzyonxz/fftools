//
//  FFLaunchServicesStore.h
//  FFPatch — bundle id ⇄ data-container resolution from lsd's CSStore ("bdsl").
//
//  Port of the LaunchServices store reader used by the 3106 base (itself a port
//  of WQ Files' WQLaunchServices.m, GPL-3.0-or-later — see NOTICE.md).
//
//  Why it exists: on iOS 27.x with the worse_query backend, MCM refuses the
//  lookup and the per-container metadata plist is unreadable, so the only way
//  to learn "which /var/mobile/Containers/Data/Application/<UUID> is Free Fire"
//  is lsd's own database, which lives inside an InternalDaemon container.
//

#ifndef FF_LAUNCH_SERVICES_STORE_H
#define FF_LAUNCH_SERVICES_STORE_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFLaunchServicesSnapshot : NSObject
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *containerBundleIDs;  // canonical path → bundle id
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *displayNames;        // bundle id → display name
@property (nonatomic, copy) NSString *layoutLabel;
@property (nonatomic, assign) NSUInteger mappedContainerCount;
- (nullable NSString *)containerPathForBundleID:(NSString *)bundleID;
- (nullable NSString *)bundleIDForContainerPath:(NSString *)path;
@end

@interface FFLaunchServicesStore : NSObject

/*! Cached snapshot (scans for the newest bdsl store when needed). */
+ (nullable FFLaunchServicesSnapshot *)snapshot;

/*! Drops the cache so the next call re-scans. */
+ (void)invalidateSnapshot;

/*! /var → /private/var and trailing slash normalisation. */
+ (NSString *)canonicalContainerPath:(NSString *)path;

/*! YES for /…/Containers/Data/Application/<UUID> (and PluginKitPlugin). */
+ (BOOL)isDataContainerPath:(NSString *)path;

/*! YES for a plausible reverse-DNS bundle identifier. */
+ (BOOL)looksLikeBundleIdentifier:(NSString *)value;

@end

NS_ASSUME_NONNULL_END

#endif /* FF_LAUNCH_SERVICES_STORE_H */
