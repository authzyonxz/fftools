

#ifndef FF_CATALOG_CLIENT_H
#define FF_CATALOG_CLIENT_H

#import <Foundation/Foundation.h>
#import "FFManifest.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const FFCatalogDidSyncNotification;

@interface FFCatalogResult : NSObject
@property (nonatomic, strong) FFManifest *manifest;
@property (nonatomic, assign) BOOL fromCache;
@property (nonatomic, assign) BOOL hadNetworkError;
@property (nonatomic, copy, nullable) NSString *catalogVersion;
@property (nonatomic, copy, nullable) NSString *catalogUpdatedAt;
@property (nonatomic, strong, nullable) NSError *error;
@end

@interface FFCatalogClient : NSObject

+ (instancetype)sharedClient;

- (FFCatalogResult *)syncWithTimeout:(NSTimeInterval)timeout;

- (NSString *)cacheRoot;

- (nullable NSString *)catalogBaseURL;

- (void)clearPayloadCache;

@end

NS_ASSUME_NONNULL_END

#endif
