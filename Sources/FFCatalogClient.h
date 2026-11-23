//
//  FFCatalogClient.h
//  FFPatch — pulls the function catalogue + encrypted payloads from the site.
//
//  The IPA ships no payloads. On launch the client fetches:
//      <baseURL>/api/catalog
//  then, for every published function/game, downloads each FPP1 pack, verifies
//  the HMAC and the SHA-256, decrypts and stores the plain file inside the app's
//  own container (Library/Application Support/FFPatch/Catalog/<fn>/<game>/<path>).
//  FFManifest is then built in memory with payloadRoot pointing at that cache.
//

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

/*! Blocking sync. Call on a background thread only. */
- (FFCatalogResult *)syncWithTimeout:(NSTimeInterval)timeout;

/*! Directory that mirrors Payloads/<function>/<game>/<relative path>. */
- (NSString *)cacheRoot;

/*! Configured catalogue base URL (decoded from Catalog.plist). */
- (nullable NSString *)catalogBaseURL;

/*! Drops downloaded payloads (keeps the cached catalog.json). */
- (void)clearPayloadCache;

@end

NS_ASSUME_NONNULL_END

#endif /* FF_CATALOG_CLIENT_H */
