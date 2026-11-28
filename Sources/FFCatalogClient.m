#import "FFLicense.h"

#import "FFCatalogClient.h"
#import "FFCore.h"
#import "FFCrypto.h"
#import "FFProtect.h"

NSString *const FFCatalogDidSyncNotification = @"FFCatalogDidSyncNotification";

@implementation FFCatalogResult
@end

@implementation FFCatalogClient

+ (instancetype)sharedClient {
    static FFCatalogClient *client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        client = [FFCatalogClient new];
    });
    return client;
}

- (NSString *)cacheRoot {
    static NSString *root;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        root = [FFPatchRootDirectory() stringByAppendingPathComponent:@"Catalog"];
        [[NSFileManager defaultManager] createDirectoryAtPath:root
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    });
    return root;
}

- (NSString *)catalogBaseURL {
    return FFCatalogBaseURL();
}

- (void)clearPayloadCache {
    NSArray<NSString *> *entries = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:self.cacheRoot error:NULL];
    for (NSString *entry in entries) {
        if ([entry isEqualToString:@"catalog.json"]) continue;
        [[NSFileManager defaultManager] removeItemAtPath:
            [self.cacheRoot stringByAppendingPathComponent:entry] error:NULL];
    }
}

#pragma mark - HTTP

- (NSData *)dataAtURL:(NSString *)url timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSURL *parsed = [NSURL URLWithString:url];
    if (parsed == nil) {
        if (error) *error = FFMakeError(FFErrorInvalidPayload, @"URL inválida: %@", url);
        return nil;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:parsed];
    request.timeoutInterval = MAX(timeout, 5.0);
    [request setValue:@"ffpatch/1" forHTTPHeaderField:@"User-Agent"];

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSData *payload = nil;
    __block NSError *transportError = nil;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *requestError) {
        if (requestError != nil) {
            transportError = requestError;
        } else if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            if (status < 200 || status >= 300) {
                transportError = FFMakeError(FFErrorApplyFailed, @"HTTP %ld em %@",
                                             (long)status, parsed.path);
            }
        }
        payload = data;
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];

    long wait = (long)(MAX(timeout, 5.0) * (double)NSEC_PER_SEC) + (long)(2 * NSEC_PER_SEC);
    if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, wait)) != 0) {
        [task cancel];
        if (error) *error = FFMakeError(FFErrorApplyFailed, @"tempo esgotado em %@", parsed.path);
        return nil;
    }
    if (transportError != nil) {
        if (error) *error = transportError;
        return nil;
    }
    return payload;
}

#pragma mark - Payload download

- (BOOL)ensureAsset:(NSDictionary *)asset
         functionID:(NSString *)functionID
             gameID:(NSString *)gameID
       destination:(NSString *)destination
              error:(NSError **)error {
    NSString *expectedSHA = asset[@"sha256"];
    NSString *remoteURL = asset[@"url"];
    NSNumber *expectedSize = [asset[@"size"] isKindOfClass:[NSNumber class]] ? asset[@"size"] : nil;
    if (expectedSHA.length == 0 || remoteURL.length == 0) {
        if (error) *error = FFMakeError(FFErrorInvalidPayload, @"entrada de asset incompleta");
        return NO;
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:destination]) {
        NSString *existing = FFSHA256HexOfFile(destination, NULL);
        if ([existing isEqualToString:expectedSHA]) return YES;
    }

    NSData *pack = [self dataAtURL:remoteURL timeout:20.0 error:error];
    if (pack.length == 0) return NO;

    NSData *plain = FFDecryptPack(pack, functionID, gameID, error);
    if (plain == nil) return NO;

    NSString *digest = FFSHA256HexOfData(plain);
    if (![digest isEqualToString:expectedSHA]) {
        if (error) {
            *error = FFMakeError(FFErrorVerifyFailed,
                                 @"SHA-256 divergente em %@", destination.lastPathComponent);
        }
        return NO;
    }
    if (expectedSize != nil && plain.length != expectedSize.unsignedIntegerValue) {
        if (error) {
            *error = FFMakeError(FFErrorVerifyFailed,
                                 @"tamanho divergente em %@", destination.lastPathComponent);
        }
        return NO;
    }
    return FFSafeWriteFile(destination, plain, error);
}

#pragma mark - Sync

- (FFCatalogResult *)syncWithTimeout:(NSTimeInterval)timeout {
    FFCatalogResult *result = [FFCatalogResult new];
    NSError *authorizationError = nil;
    if (![[FFLicense current] ensureAuthorizedWithError:&authorizationError]) {
        result.error = authorizationError;
        result.hadNetworkError = YES;
        result.manifest = [FFManifest emptyManifest];
        return result;
    }
    NSString *baseURL = [self catalogBaseURL];
    NSString *cacheRoot = [self cacheRoot];
    NSString *cachedCatalogPath = [cacheRoot stringByAppendingPathComponent:@"catalog.json"];

    NSDictionary *catalog = nil;
    NSError *networkError = nil;
    NSTimeInterval started = [NSDate date].timeIntervalSince1970;

    if (baseURL.length == 0) {
        networkError = FFMakeError(FFErrorInvalidPayload, @"catálogo não configurado (Catalog.plist)");
    } else {
        NSString *catalogURL = [baseURL stringByAppendingString:@"/api/catalog"];
        NSData *data = [self dataAtURL:catalogURL timeout:timeout error:&networkError];
        if (data.length > 0) {
            id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if ([parsed isKindOfClass:[NSDictionary class]]) {
                catalog = parsed;
                [data writeToFile:cachedCatalogPath atomically:YES];
                FFLog(@"catalog: baixado v%@ de %@", catalog[@"version"] ?: @"?", baseURL);
            } else {
                networkError = FFMakeError(FFErrorInvalidPayload, @"catálogo não é JSON objeto");
            }
        }
    }

    if (catalog == nil) {
        NSData *cached = [NSData dataWithContentsOfFile:cachedCatalogPath];
        if (cached.length > 0) {
            id parsed = [NSJSONSerialization JSONObjectWithData:cached options:0 error:NULL];
            if ([parsed isKindOfClass:[NSDictionary class]]) {
                catalog = parsed;
                result.fromCache = YES;
                FFLog(@"catalog: usando cache local (v%@)", catalog[@"version"] ?: @"?");
            }
        }
    }

    result.error = networkError;
    result.hadNetworkError = (networkError != nil);
    if (catalog == nil) {
        result.manifest = [FFManifest emptyManifest];
        return result;
    }
    result.catalogVersion = catalog[@"version"] != nil
        ? [NSString stringWithFormat:@"%@", catalog[@"version"]] : nil;
    result.catalogUpdatedAt = [catalog[@"updatedAt"] isKindOfClass:[NSString class]]
        ? catalog[@"updatedAt"] : nil;

    NSArray *games = [catalog[@"games"] isKindOfClass:[NSArray class]] ? catalog[@"games"] : @[];
    NSArray *groups = [catalog[@"groups"] isKindOfClass:[NSArray class]] ? catalog[@"groups"] : @[];

    NSMutableArray<NSDictionary *> *manifestGroups = [NSMutableArray array];
    NSUInteger downloadFailures = 0;

    for (NSDictionary *group in groups) {
        if (![group isKindOfClass:[NSDictionary class]]) continue;
        NSArray *rawFunctions = [group[@"functions"] isKindOfClass:[NSArray class]]
            ? group[@"functions"] : @[];
        NSMutableArray<NSDictionary *> *functions = [NSMutableArray array];

        for (NSDictionary *rawFunction in rawFunctions) {
            if (![rawFunction isKindOfClass:[NSDictionary class]]) continue;
            NSString *functionID = rawFunction[@"id"];
            if (functionID.length == 0) continue;
            NSDictionary *assets = [rawFunction[@"assets"] isKindOfClass:[NSDictionary class]]
                ? rawFunction[@"assets"] : @{};

            NSMutableArray<NSString *> *availableGames = [NSMutableArray array];
            for (NSString *gameID in assets) {
                NSArray *files = [assets[gameID] isKindOfClass:[NSArray class]] ? assets[gameID] : @[];
                if (files.count == 0) continue;

                BOOL gameComplete = YES;
                for (NSDictionary *asset in files) {
                    if (![asset isKindOfClass:[NSDictionary class]]) { gameComplete = NO; continue; }
                    NSString *relativePath = asset[@"path"];
                    if (!FFRelativePathIsSafe(relativePath)) { gameComplete = NO; continue; }

                    NSString *destination = [[[cacheRoot
                        stringByAppendingPathComponent:functionID]
                        stringByAppendingPathComponent:gameID]
                        stringByAppendingPathComponent:relativePath];
                    NSError *assetError = nil;
                    if (![self ensureAsset:asset
                                functionID:functionID
                                    gameID:gameID
                              destination:destination
                                     error:&assetError]) {
                        FFLog(@"catalog: asset falhou %@/%@/%@ — %@", functionID, gameID,
                              relativePath, assetError.localizedDescription ?: @"?");
                        gameComplete = NO;
                    }
                }

                if (gameComplete) {
                    [availableGames addObject:gameID];
                } else {
                    downloadFailures++;
                }
            }

            if (availableGames.count == 0) continue;

            NSMutableDictionary *function = [NSMutableDictionary dictionary];
            function[@"id"] = functionID;
            function[@"name"] = rawFunction[@"name"] ?: functionID;
            function[@"subtitle"] = rawFunction[@"subtitle"] ?: @"";
            function[@"payload"] = rawFunction[@"payload"] ?: functionID;
            function[@"games"] = availableGames;
            function[@"status"] = rawFunction[@"status"] ?: @"active";
            if ([rawFunction[@"locate"] isKindOfClass:[NSDictionary class]]) {
                function[@"locate"] = rawFunction[@"locate"];
            }
            [functions addObject:function];
        }

        if (functions.count > 0) {
            [manifestGroups addObject:@{
                @"id": group[@"id"] ?: @"group",
                @"title": group[@"title"] ?: @"Funções",
                @"exclusive": @([group[@"exclusive"] boolValue]),
                @"functions": functions,
            }];
        }
    }

    NSDictionary *manifestDictionary = @{
        @"schema": @1,
        @"games": games,
        @"groups": manifestGroups,
    };

    NSError *manifestError = nil;
    FFManifest *manifest = [FFManifest manifestFromDictionary:manifestDictionary
                                                  payloadRoot:cacheRoot
                                                        error:&manifestError];
    if (manifest == nil) {
        FFLog(@"catalog: manifest inválido — %@", manifestError.localizedDescription ?: @"?");
        result.manifest = [FFManifest emptyManifest];
        if (result.error == nil) result.error = manifestError;
        return result;
    }

    result.manifest = manifest;
    FFLog(@"catalog: pronto em %.1fs · %lu grupo(s) · %lu falha(s) de download",
          [NSDate date].timeIntervalSince1970 - started,
          (unsigned long)manifestGroups.count, (unsigned long)downloadFailures);
    return result;
}

@end
