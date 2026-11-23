//
//  FFContainerStore.m
//  FFPatch
//

#import "FFContainerStore.h"
#import "FFCore.h"
#import "FFSandbox.h"

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
    if (cached.length > 0 && [self pathIsDirectory:cached]) return cached;

    NSMutableArray<NSString *> *attempts = [NSMutableArray array];
    NSString *resolved = nil;

    // 1. worse_query container index (iOS 26.7+ / 27).
    resolved = [self lookupViaWorseQueryIndex:bundleID kind:kind attemptLog:attempts];
    if (resolved.length) {
        FFLog(@"container: %@ → %@ (worse_query index)", bundleID, resolved);
        [self remember:resolved forKey:key];
        return resolved;
    }

    // 2. MobileContainerManager query (activation optional — the path alone is
    //    useful because the write itself goes through the sandbox grant).
    resolved = [self lookupViaMCM:bundleID kind:kind attemptLog:attempts];
    if (resolved.length) {
        FFLog(@"container: %@ → %@ (MCM)", bundleID, resolved);
        [self remember:resolved forKey:key];
        return resolved;
    }

    // 3. Metadata plist scan.
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

- (BOOL)pathIsDirectory:(NSString *)path {
    if (path.length == 0) return NO;
    struct stat info;
    if (lstat(path.fileSystemRepresentation, &info) != 0) return NO;
    if ((info.st_mode & S_IFMT) != S_IFDIR) return NO;
    int descriptor = open(path.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (descriptor < 0) return NO;
    close(descriptor);
    return YES;
}

#pragma mark - 1. worse_query index

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
        [attempts addObject:@"worse_query index: sem entrada"];
        return nil;
    }

    // The index only carries data containers. For a bundle container we have to
    // go from <uuid> to the .app inside /var/containers/Bundle/Application.
    if (kind == FFContainerKindBundle) {
        NSString *uuid = path.lastPathComponent;
        NSString *bundleRoot = [FFBundleContainerRoot stringByAppendingPathComponent:uuid];
        NSString *app = [self firstAppBundleInDirectory:bundleRoot bundleID:bundleID];
        if (app.length) return app;
        [attempts addObject:@"worse_query index: sem bundle container correspondente"];
        return nil;
    }

    if ([self pathIsDirectory:path]) return path;
    [attempts addObject:@"worse_query index: caminho não abre"];
    return nil;
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
        if (path.length && [self pathIsDirectory:path]) return path;
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

#pragma mark - 3. metadata plist scan

- (NSString *)lookupViaMetadataScan:(NSString *)bundleID
                               kind:(FFContainerKind)kind
                         attemptLog:(NSMutableArray<NSString *> *)attempts {
    NSString *root = (kind == FFContainerKindData) ? FFDataContainerRoot : FFBundleContainerRoot;

    // The parent directory is owned by containermanagerd; ask for a grant so
    // the enumeration itself is not denied.
    int64_t handle = FFSandboxGrantPath(root, NO, NULL);
    NSArray<NSString *> *entries = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:root error:NULL];
    if (handle >= 0) FFSandboxReleaseHandle(handle);

    if (entries.count == 0) {
        [attempts addObject:@"metadata scan: diretório ilegível"];
        return nil;
    }

    NSArray<NSString *> *sorted = [entries sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *entry in sorted) {
        NSString *directory = [root stringByAppendingPathComponent:entry];
        NSString *metadataPath = [directory stringByAppendingPathComponent:FFMCMetadataFileName];
        NSDictionary *metadata = FFReadPlist(metadataPath);
        NSString *identifier = metadata[@"MCMMetadataIdentifier"];
        if (identifier.length == 0) continue;
        if (![identifier isEqualToString:bundleID]) continue;

        if (kind == FFContainerKindData) {
            if ([self pathIsDirectory:directory]) return directory;
            continue;
        }
        NSString *app = [self firstAppBundleInDirectory:directory bundleID:bundleID];
        if (app.length) return app;
    }

    [attempts addObject:@"metadata scan: nenhum match"];
    return nil;
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
