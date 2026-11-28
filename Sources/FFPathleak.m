

#import "FFPathleak.h"
#import "FFCore.h"

#import <sys/mount.h>
#import <sys/fsgetpath.h>
#import <sys/param.h>

static NSString *FFPathleakNormalize(NSString *directory) {
    NSString *clean = directory;
    while (clean.length > 1 && [clean hasSuffix:@"/"]) {
        clean = [clean substringToIndex:clean.length - 1];
    }
    return clean;
}

static NSString *FFPathleakStripPrivate(NSString *path) {
    if ([path hasPrefix:@"/private/"]) return [path substringFromIndex:@"/private".length];
    return path;
}

static BOOL FFPathleakFileSystemID(NSString *directory, fsid_t *outID) {
    struct statfs info;
    if (statfs(directory.fileSystemRepresentation, &info) == 0) {
        *outID = info.f_fsid;
        return YES;
    }
    if (statfs("/private/var", &info) == 0) {
        *outID = info.f_fsid;
        return YES;
    }
    if (statfs("/var", &info) == 0) {
        *outID = info.f_fsid;
        return YES;
    }
    return NO;
}

static BOOL FFPathleakInodeExists(fsid_t id, uint64_t inode) {
    char buffer[PATH_MAX];
    return fsgetpath(buffer, sizeof(buffer), &id, inode) > 0;
}

static uint64_t FFPathleakCeiling(fsid_t id, uint64_t ceiling) {
    const uint64_t coarseStep = 8192;
    uint64_t probe = ceiling;
    while (probe > coarseStep) {
        if (FFPathleakInodeExists(id, probe)) break;
        probe -= coarseStep;
    }
    if (probe <= coarseStep) return ceiling;

    uint64_t refined = probe;
    uint64_t cursor = probe + 1;
    uint64_t limit = MIN(ceiling, probe + coarseStep);
    while (cursor <= limit) {
        if (FFPathleakInodeExists(id, cursor)) {
            refined = cursor;
        } else if (cursor - refined > 4096) {
            break;
        }
        cursor++;
    }
    return refined;
}

#pragma mark - Cache

static NSMutableDictionary<NSString *, NSDictionary *> *FFPathleakCache(void) {
    static NSMutableDictionary<NSString *, NSDictionary *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });
    return cache;
}

static NSArray<NSString *> *FFPathleakMemoLookup(NSString *directory) {
    @synchronized (FFPathleakCache()) {
        NSDictionary *entry = FFPathleakCache()[directory];
        if (entry == nil) return nil;
        NSDate *stamp = entry[@"at"];
        if (stamp == nil || [[NSDate date] timeIntervalSinceDate:stamp] >= 120.0) {
            [FFPathleakCache() removeObjectForKey:directory];
            return nil;
        }
        return entry[@"paths"];
    }
}

static void FFPathleakMemoStore(NSString *directory, NSArray<NSString *> *paths) {
    @synchronized (FFPathleakCache()) {
        FFPathleakCache()[directory] = @{@"at": [NSDate date], @"paths": paths ?: @[]};
    }
}

#pragma mark - Public

NSArray<NSString *> *FFPathleakListPaths(NSString *directory, NSUInteger maxInodes) {
    NSString *clean = FFPathleakNormalize(directory);
    if (clean.length == 0) return @[];

    NSArray<NSString *> *memoised = FFPathleakMemoLookup(clean);
    if (memoised != nil) return memoised;

    fsid_t filesystemID;
    if (!FFPathleakFileSystemID(clean, &filesystemID)) return @[];

    uint64_t ceiling = maxInodes > 0 ? maxInodes : 2000000;
    uint64_t effectiveCeiling = FFPathleakCeiling(filesystemID, ceiling);
    NSString *prefix = FFPathleakStripPrivate(clean);

    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    char buffer[PATH_MAX];
    for (uint64_t inode = 1; inode <= effectiveCeiling; inode++) {
        @autoreleasepool {
            if (inode % 8192 == 0 && [NSThread isMainThread]) break;
            long length = fsgetpath(buffer, sizeof(buffer), &filesystemID, inode);
            if (length <= 0) continue;
            NSString *path = FFPathleakStripPrivate([NSString stringWithUTF8String:buffer]);
            if (path.length == 0 || ![path hasPrefix:prefix]) continue;
            NSString *rest = [path substringFromIndex:prefix.length];
            if (![rest hasPrefix:@"/"]) continue;
            rest = [rest substringFromIndex:1];
            if (rest.length == 0 || [rest containsString:@"/"]) continue;
            [paths addObject:path];
        }
    }
    FFLog(@"pathleak: %@ → %lu entrada(s) (até inode %llu)",
          clean.lastPathComponent, (unsigned long)paths.count, effectiveCeiling);
    FFPathleakMemoStore(clean, paths);
    return paths;
}

NSArray<NSString *> *FFPathleakListNames(NSString *directory, NSUInteger maxInodes) {
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSString *path in FFPathleakListPaths(directory, maxInodes)) {
        NSString *name = path.lastPathComponent;
        if (name.length) [names addObject:name];
    }
    return names;
}
