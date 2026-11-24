//
//  FFContainerStore.m
//  FFPatch
//

#import "FFContainerStore.h"
#import "FFCore.h"
#import "FFSandbox.h"
#import "FFLaunchServicesStore.h"
#import "FFPathleak.h"

#import "Vendor/mcm_bridge.h"
#import "Vendor/worse_query.h"

#import <sys/stat.h>
#import <unistd.h>
#import <fcntl.h>
#import <errno.h>

static NSString *const FFDataContainerRoot   = @"/var/mobile/Containers/Data/Application";
static NSString *const FFBundleContainerRoot = @"/var/containers/Bundle/Application";
static NSString *const FFMCMetadataFileName  = @".com.apple.mobile_container_manager.metadata.plist";

@implementation FFContainerStore {
    NSMutableDictionary<NSString *, NSString *> *_cache;
    NSLock *_lock;
}

+ (instancetype)sharedStore {
    static FFContainerStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [FFContainerStore new];
    });
    return store;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [NSMutableDictionary dictionary];
        _lock = [NSLock new];
    }
    return self;
}

- (void)invalidateCache {
    [_lock lock];
    [_cache removeAllObjects];
    [_lock unlock];
    [FFLaunchServicesStore invalidateSnapshot];
}

- (NSString *)cacheKeyForBundleID:(NSString *)bundleID kind:(FFContainerKind)kind {
    return [NSString stringWithFormat:@"%ld:%@", (long)kind, bundleID];
}

#pragma mark - Public

- (NSString *)dataContainerForBundleID:(NSString *)bundleID error:(NSError **)error {
    return [self containerForBundleID:bundleID kind:FFContainerKindData error:error];
}

- (NSString *)bundleContainerForBundleID:(NSString *)bundleID error:(NSError **)error {
    return [self containerForBundleID:bundleID kind:FFContainerKindBundle error:error];
}

- (NSString *)containerForBundleID:(NSString *)bundleID
                              kind:(FFContainerKind)kind
                             error:(NSError **)error {
    if (bundleID.length == 0) {
        if (error) *error = FFMakeError(FFErrorInvalidPayload, @"bundle id vazio");
        return nil;
    }

    NSString *key = [self cacheKeyForBundleID:bundleID kind:kind];
    [_lock lock];
    NSString *cached = _cache[key];
    [_lock unlock];
    if (cached.length > 0 && [self isUsableContainerPath:cached kind:kind]) return cached;

    NSMutableArray<NSString *> *attempts = [NSMutableArray array];
    NSString *resolved = nil;

    // 1. lsd's CSStore. On iOS 26.7+/27 this is the only source that still
    //    pairs a bundle id with its data container when MCM refuses and the
    //    per-container metadata plist is root-owned/unreadable.
    if (kind == FFContainerKindData) {
        resolved = [self lookupViaLaunchServices:bundleID attemptLog:attempts];
        if (resolved.length) {
            FFLog(@"container: %@ → %@ (LaunchServices)", bundleID, resolved);
            [self remember:resolved forKey:key];
            return resolved;
        }
    }

    // 2. MobileContainerManager query.
    resolved = [self lookupViaMCM:bundleID kind:kind attemptLog:attempts];
    if (resolved.length) {
        FFLog(@"container: %@ → %@ (MCM)", bundleID, resolved);
        [self remember:resolved forKey:key];
        return resolved;
    }

    // 3. worse_query container index (identifier → path) and its reverse.
    resolved = [self lookupViaWorseQueryIndex:bundleID kind:kind attemptLog:attempts];
    if (resolved.length) {
        FFLog(@"container: %@ → %@ (worse_query index)", bundleID, resolved);
        [self remember:resolved forKey:key];
        return resolved;
    }

    // 4. Plain filesystem metadata scan (last resort; needs a readable root).
    resolved = [self lookupViaMetadataScan:bundleID kind:kind attemptLog:attempts];
    if (resolved.length) {
        FFLog(@"container: %@ → %@ (metadata scan)", bundleID, resolved);
        [self remember:resolved forKey:key];
        return resolved;
    }

    NSString *detail = [attempts componentsJoinedByString:@" | "];
    FFLog(@"container: %@ NOT FOUND — %@", bundleID, detail);
    if (error) {
        *error = FFMakeError(FFErrorAppNotFound,
                             @"container de %@ não encontrado (app instalado?). Tentativas: %@",
                             bundleID, detail.length ? detail : @"nenhuma");
    }
    return nil;
}

- (void)remember:(NSString *)path forKey:(NSString *)key {
    [_lock lock];
    _cache[key] = path;
    [_lock unlock];
}

/*! A resolved path is usable when its shape is right and it can be stat'ed,
    OR when the shape is right but the sandbox still refuses stat — because a
    worse_query grant issued later will open it. Never discard a shape-valid
    LaunchServices path just because open() is denied before a grant. */
- (BOOL)isUsableContainerPath:(NSString *)path kind:(FFContainerKind)kind {
    if (path.length == 0) return NO;
    NSString *canonical = [FFLaunchServicesStore canonicalContainerPath:path];
    if (kind == FFContainerKindData) {
        if (![FFLaunchServicesStore isDataContainerPath:canonical]) return NO;
    }
    struct stat info;
    if (lstat(canonical.fileSystemRepresentation, &info) == 0) {
        return (info.st_mode & S_IFMT) == S_IFDIR;
    }
    return YES;  // shape-valid; access comes from the sandbox grant
}

- (BOOL)pathIsDirectory:(NSString *)path {
    if (path.length == 0) return NO;
    struct stat info;
    if (lstat(path.fileSystemRepresentation, &info) != 0) return NO;
    return (info.st_mode & S_IFMT) == S_IFDIR;
}

#pragma mark - 1. LaunchServices store

- (NSString *)lookupViaLaunchServices:(NSString *)bundleID
                           attemptLog:(NSMutableArray<NSString *> *)attempts {
    FFLaunchServicesSnapshot *snapshot = [FFLaunchServicesStore snapshot];
    if (snapshot == nil) {
        [attempts addObject:@"LaunchServices: store indisponível"];
        return nil;
    }
    NSString *path = [snapshot containerPathForBundleID:bundleID];
    if (path.length == 0) {
        [attempts addObject:[NSString stringWithFormat:
            @"LaunchServices: sem entrada (layout %@, %lu containers)",
            snapshot.layoutLabel, (unsigned long)snapshot.mappedContainerCount]];
        return nil;
    }
    NSString *canonical = [FFLaunchServicesStore canonicalContainerPath:path];
    if (![FFLaunchServicesStore isDataContainerPath:canonical]) {
        [attempts addObject:@"LaunchServices: caminho fora do container de dados"];
        return nil;
    }
    return canonical;
}

#pragma mark - 2. MCM

- (NSString *)lookupViaMCM:(NSString *)bundleID
                      kind:(FFContainerKind)kind
                attemptLog:(NSMutableArray<NSString *> *)attempts {
    if (!MCMBridgeAvailable()) {
        [attempts addObject:@"MCM: símbolos indisponíveis"];
        return nil;
    }

    NSString *lookupError = nil;
    if (kind == FFContainerKindData) {
        NSString *path = MCMActivateContainerPath(2, bundleID, NO, &lookupError);
        if (path.length && [self isUsableContainerPath:path kind:FFContainerKindData]) return path;
        [attempts addObject:[NSString stringWithFormat:@"MCM data: %@", lookupError ?: @"sem caminho"]];
        return nil;
    }

    NSString *path = MCMActivateContainerPath(1, bundleID, NO, &lookupError);
    if (path.length) {
        NSString *app = [self firstAppBundleInDirectory:path bundleID:bundleID];
        if (app.length) return app;
        [attempts addObject:@"MCM bundle: container sem .app"];
        return nil;
    }
    [attempts addObject:[NSString stringWithFormat:@"MCM bundle: %@", lookupError ?: @"sem caminho"]];
    return nil;
}

#pragma mark - 3. worse_query index

- (NSString *)lookupViaWorseQueryIndex:(NSString *)bundleID
                                  kind:(FFContainerKind)kind
                            attemptLog:(NSMutableArray<NSString *> *)attempts {
    if (FFSandboxCurrentBackend() != FFSandboxBackendWorseQuery) {
        [attempts addObject:@"worse_query index: backend inativo"];
        return nil;
    }

    NSDictionary<NSString *, NSString *> *map = worse_query_identifier_paths();
    NSString *path = map[bundleID];
    if (path.length == 0) {
        NSDictionary<NSString *, NSString *> *reverse = worse_query_path_identifiers();
        for (NSString *candidate in reverse) {
            if ([reverse[candidate] isEqualToString:bundleID]) { path = candidate; break; }
        }
    }
    if (path.length == 0) {
        [attempts addObject:@"worse_query index: sem entrada"];
        return nil;
    }

    if (kind == FFContainerKindBundle) {
        NSString *uuid = path.lastPathComponent;
        NSString *bundleRoot = [FFBundleContainerRoot stringByAppendingPathComponent:uuid];
        NSString *app = [self firstAppBundleInDirectory:bundleRoot bundleID:bundleID];
        if (app.length) return app;
        [attempts addObject:@"worse_query index: sem bundle container correspondente"];
        return nil;
    }

    NSString *canonical = [FFLaunchServicesStore canonicalContainerPath:path];
    if ([FFLaunchServicesStore isDataContainerPath:canonical]) return canonical;
    [attempts addObject:@"worse_query index: caminho fora do container de dados"];
    return nil;
}

#pragma mark - 4. metadata scan

- (NSString *)lookupViaMetadataScan:(NSString *)bundleID
                               kind:(FFContainerKind)kind
                         attemptLog:(NSMutableArray<NSString *> *)attempts {
    NSString *root = (kind == FFContainerKindData) ? FFDataContainerRoot : FFBundleContainerRoot;
    BOOL worseQuery = FFSandboxCurrentBackend() == FFSandboxBackendWorseQuery;

    NSArray<NSString *> *entries = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:root error:NULL];

    // One token on the app-data root is held for the whole scan: under
    // bad_query/kernel that token also covers the plain reads of the
    // containers below it (path-scoped tokens), so the scan does not need a
    // grant per application. On worse_query the root is not a container and the
    // grant is skipped (-6) — that backend resolves via LaunchServices.
    int64_t rootGrant = -1;
    if (entries.count == 0 && !worseQuery) {
        // Walk up until bad_query accepts a path; an accepted ancestor covers
        // the whole subtree, so the listing then works.
        NSString *cursor = root;
        while (cursor.length > 1) {
            rootGrant = FFSandboxGrantPath(cursor, NO, NULL);
            if (rootGrant < 0) {
                cursor = [cursor stringByDeletingLastPathComponent];
                continue;
            }
            entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:NULL];
            if (entries.count > 0) break;
            FFSandboxReleaseHandle(rootGrant);
            rootGrant = -1;
            cursor = [cursor stringByDeletingLastPathComponent];
        }
    }
    if (entries.count == 0 && worseQuery) {
        entries = FFPathleakListNames(root, 2000000);
    }
    if (entries.count == 0) {
        [attempts addObject:@"metadata scan: diretório ilegível"];
        return nil;
    }

    NSString *result = nil;
    @try {
        NSArray<NSString *> *sorted = [entries sortedArrayUsingSelector:@selector(compare:)];
        NSUInteger inspected = 0;
        for (NSString *entry in sorted) {
            if (inspected++ > 600) break;   // bound the scan on huge devices
            if ([[NSUUID alloc] initWithUUIDString:entry] == nil) continue;
            NSString *directory = [root stringByAppendingPathComponent:entry];
            NSString *metadataPath = [directory stringByAppendingPathComponent:FFMCMetadataFileName];

            NSDictionary *metadata = FFReadPlist(metadataPath);
            if (metadata == nil) {
                int64_t containerGrant = FFSandboxGrantPath(directory, NO, NULL);
                metadata = FFReadPlist(metadataPath);
                if (containerGrant >= 0) FFSandboxReleaseHandle(containerGrant);
            }
            NSString *identifier = metadata[@"MCMMetadataIdentifier"];
            if (identifier.length == 0 || ![identifier isEqualToString:bundleID]) continue;

            if (kind == FFContainerKindData) {
                NSString *canonical = [FFLaunchServicesStore canonicalContainerPath:directory];
                if ([FFLaunchServicesStore isDataContainerPath:canonical]) {
                    result = canonical;
                    break;
                }
                continue;
            }
            NSString *app = [self firstAppBundleInDirectory:directory bundleID:bundleID];
            if (app.length) {
                result = app;
                break;
            }
        }
    } @finally {
        if (rootGrant >= 0) FFSandboxReleaseHandle(rootGrant);
    }

    if (result.length == 0) [attempts addObject:@"metadata scan: nenhum match"];
    return result;
}
#pragma mark - Helpers

- (NSString *)firstAppBundleInDirectory:(NSString *)directory bundleID:(NSString *)bundleID {
    NSArray<NSString *> *children = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:directory error:NULL];
    if (children.count == 0) return nil;

    NSString *preferredName = [[bundleID componentsSeparatedByString:@"."] lastObject];
    NSString *fallback = nil;
    for (NSString *child in children) {
        if (![child.pathExtension.lowercaseString isEqualToString:@"app"]) continue;
        NSString *candidate = [directory stringByAppendingPathComponent:child];
        if (![self pathIsDirectory:candidate]) continue;
        if (preferredName.length &&
            [child.lowercaseString hasPrefix:preferredName.lowercaseString]) {
            return candidate;
        }
        if (fallback == nil) fallback = candidate;
    }
    return fallback;
}

@end
