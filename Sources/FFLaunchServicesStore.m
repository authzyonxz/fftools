//
//  FFLaunchServicesStore.m
//  FFPatch
//

#import "FFLaunchServicesStore.h"
#import "FFCore.h"
#import "FFSandbox.h"

#import <sys/stat.h>

#import "FFPathleak.h"
#import "Vendor/mcm_bridge.h"

static const uint32_t FFMaxStringID = 0x01000000;
static const NSUInteger FFMinimumStoreBytes = 0x1000;
static const NSUInteger FFMaximumStoreBytes = 64 * 1024 * 1024;
static const NSUInteger FFMaxBundleRecords = 20000;   // records per layout
static const size_t FFMaxStringLength = 0x800;
static const size_t FFMaximumRecordSize = 0x25c;

typedef struct {
    const char *label;
    uint32_t bundleSize;
    int bundleIDOffset;
    int containerOffset;
    int nameOffset;
    int displayNameOffset;
    int bundlePathOffset;
    uint32_t pluginSize;
    int pluginBundleIDOffset;
    int pluginContainerOffset;
} FFLSLayout;

static const FFLSLayout kFFLayouts[] = {
    { "27.0",   0x250, 0x0c, 0x68, 0x6c, 0x74, 0x00, 0x118, 0x00, 0x54 },
    { "26",     0x23c, 0x0c, 0x64, 0x68, 0x70, 0x00, 0x104, 0x00, 0x50 },
    { "26.5",   0x23c, 0x0c, 0x60, 0x64, 0x6c, 0x00, 0x104, 0x00, 0x4c },
    { "26.5b",  0x23c, 0x08, 0x60, 0x64, 0x6c, 0x00, 0x104, 0x00, 0x4c },
    { "27.2",   0x25c, 0x0c, 0x6c, 0x70, 0x78, 0x00, 0x120, 0x00, 0x58 },
    { "27.2b",  0x25c, 0x10, 0x6c, 0x70, 0x78, 0x00, 0x120, 0x04, 0x58 },
    { "27.2c",  0x25c, 0x0c, 0x6c, 0x70, 0x78, 0x00, 0x120, 0x04, 0x58 },
    { "27.2d",  0x25c, 0x10, 0x6c, 0x70, 0x78, 0x00, 0x120, 0x00, 0x58 },
    { "27.3",   0x25c, 0x0c, 0x6c, 0x70, 0x78, 0x00, 0x120, 0x00, 0x58 },
    { "27.3b",  0x25c, 0x14, 0x70, 0x74, 0x7c, 0x00, 0x120, 0x08, 0x5c },
    { "27.3c",  0x25c, 0x18, 0x70, 0x74, 0x7c, 0x00, 0x120, 0x0c, 0x5c },
};
static const size_t kFFLayoutCount = sizeof(kFFLayouts) / sizeof(kFFLayouts[0]);

#pragma mark - Snapshot

@implementation FFLaunchServicesSnapshot

- (NSString *)containerPathForBundleID:(NSString *)bundleID {
    if (bundleID.length == 0) return nil;
    for (NSString *path in self.containerBundleIDs) {
        if ([self.containerBundleIDs[path] isEqualToString:bundleID]) return path;
    }
    return nil;
}

- (NSString *)bundleIDForContainerPath:(NSString *)path {
    NSString *canonical = [FFLaunchServicesStore canonicalContainerPath:path];
    return self.containerBundleIDs[canonical];
}

@end

#pragma mark - Byte helpers

static inline uint32_t FFrd32(const uint8_t *bytes, size_t offset) {
    return (uint32_t)bytes[offset]
        | ((uint32_t)bytes[offset + 1] << 8)
        | ((uint32_t)bytes[offset + 2] << 16)
        | ((uint32_t)bytes[offset + 3] << 24);
}

static inline BOOL FFisValidRef(uint32_t ref) {
    return ref != 0 && (ref & 3) == 0 && (ref >> 2) < FFMaxStringID;
}

static inline void FFsetBit(uint8_t *bits, uint32_t stringID) {
    size_t index = stringID / 8;
    if (index >= (FFMaxStringID / 8)) return;
    bits[index] |= (uint8_t)(1u << (stringID % 8));
}

static inline BOOL FFbitIsSet(const uint8_t *bits, uint32_t stringID) {
    size_t index = stringID / 8;
    if (index >= (FFMaxStringID / 8)) return NO;
    return (bits[index] & (uint8_t)(1u << (stringID % 8))) != 0;
}

static size_t FFfirstHeapOffset(const uint8_t *bytes, size_t length) {
    static const uint8_t marker[8] = {'<', 's', 't', 'r', 'i', 'n', 'g', '>'};
    if (length < sizeof(marker)) return 0;
    size_t last = length - sizeof(marker);
    for (size_t index = 0; index <= last; index++) {
        if (bytes[index] != marker[0]) continue;
        BOOL matched = YES;
        for (size_t offset = 1; offset < sizeof(marker); offset++) {
            if (bytes[index + offset] != marker[offset]) { matched = NO; break; }
        }
        if (matched) return index;
    }
    return 0;
}

static NSString *FFdecodeString(const uint8_t *bytes, size_t length, size_t offset) {
    if (offset >= length || length - offset < 8) return nil;
    uint32_t stringLength = FFrd32(bytes, offset + 4);
    if (stringLength == 0 || stringLength >= FFMaxStringLength) return nil;
    if ((size_t)stringLength >= length - offset - 8) return nil;
    if (stringLength % 4 != 0 && bytes[offset + 8 + stringLength] != 0) return nil;
    size_t start = offset + 8;
    for (size_t index = 0; index < stringLength; index++) {
        if (bytes[start + index] == 0) return nil;
    }
    return [[NSString alloc] initWithBytes:bytes + start
                                    length:stringLength
                                  encoding:NSUTF8StringEncoding];
}

static void FFstorePathString(NSString *value,
                              uint32_t stringID,
                              NSMutableDictionary<NSNumber *, NSString *> *table,
                              NSMutableSet<NSNumber *> *conflicts) {
    NSNumber *key = @(stringID);
    NSString *existing = table[key];
    if (existing != nil) {
        if (![existing isEqualToString:value]) {
            [conflicts addObject:key];
            [table removeObjectForKey:key];
        }
    } else if (![conflicts containsObject:key]) {
        table[key] = value;
    }
}

static NSString *FFsafeDisplayName(NSString *value) {
    if (value.length == 0) return nil;
    NSMutableString *clean = [NSMutableString stringWithCapacity:value.length];
    for (NSUInteger index = 0; index < value.length; index++) {
        unichar character = [value characterAtIndex:index];
        if (character < 0x20 || (character >= 0x7f && character < 0xa0)) {
            [clean appendString:@"\uFFFD"];
        } else {
            [clean appendFormat:@"%C", character];
        }
    }
    NSString *trimmed = [clean stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return nil;
    if ([trimmed hasPrefix:@"/"] || [trimmed containsString:@".app/"]) return nil;
    return trimmed;
}

#pragma mark - Store

@interface FFLaunchServicesStore (FFPrivate)
+ (NSString *)signatureForStorePath:(NSString *)path;
+ (BOOL)rememberedStoreSignatureMatches:(NSString *)signature;
@end

@implementation FFLaunchServicesStore

static NSLock *FFLSLock(void) {
    static NSLock *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSLock new];
    });
    return lock;
}

static FFLaunchServicesSnapshot *FFLSCachedSnapshot;
static NSString *FFLSCachedSignature;
static NSDate *FFLSMissAt;

+ (NSString *)canonicalContainerPath:(NSString *)path {
    if (path.length == 0) return @"";
    NSString *clean = path;
    while (clean.length > 1 && [clean hasSuffix:@"/"]) {
        clean = [clean substringToIndex:clean.length - 1];
    }
    if ([clean isEqualToString:@"/var"] || [clean hasPrefix:@"/var/"]) {
        clean = [@"/private" stringByAppendingString:clean];
    }
    return clean;
}

+ (BOOL)isDataContainerPath:(NSString *)path {
    if (path.length == 0) return NO;
    NSArray<NSString *> *prefixes = @[
        @"/private/var/mobile/Containers/Data/Application/",
        @"/private/var/mobile/Containers/Data/PluginKitPlugin/",
    ];
    for (NSString *prefix in prefixes) {
        if (![path hasPrefix:prefix]) continue;
        if (path.length != prefix.length + 36) continue;
        NSString *uuid = [path substringFromIndex:prefix.length];
        return [[NSUUID alloc] initWithUUIDString:uuid] != nil;
    }
    return NO;
}

+ (BOOL)looksLikeBundleIdentifier:(NSString *)value {
    if (value.length <= 2 || ![value containsString:@"."]) return NO;
    if ([value hasPrefix:@"."] || value.UTF8String == NULL) return NO;
    if ([value lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 255) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"];
    return [value rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

+ (void)invalidateSnapshot {
    [FFLSLock() lock];
    FFLSCachedSnapshot = nil;
    FFLSCachedSignature = nil;
    FFLSMissAt = nil;
    [FFLSLock() unlock];
}

#pragma mark - Directory helpers (grant-aware)

/*! Plain listing only — used where a token is already held or where a walk
    would be wasted (the caller decides whether pathleak is warranted). */
static NSArray<NSString *> *FFLSListDirectoryCheap(NSString *directory) {
    if (directory.length == 0) return @[];
    NSArray<NSString *> *names = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:directory error:NULL];
    return names ?: @[];
}

static NSArray<NSString *> *FFLSListDirectory(NSString *directory) {
    if (directory.length == 0) return @[];
    NSArray<NSString *> *names = FFLSListDirectoryCheap(directory);
    if (names.count > 0) return names;

    // Never grant here: the roots walked below are parent directories, and a
    // grant on a non-container path returns -6/-4 while still costing a swap.
    // fsgetpath itself needs no token, so the inode walk works on every
    // backend where the plain listing is denied (26.x bad_query included).
    return FFPathleakListNames(directory, 2000000);
}

static NSData *FFLSReadFile(NSString *path) {
    if (path.length == 0) return nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length > 0) return data;

    NSString *parent = [path stringByDeletingLastPathComponent];
    int64_t handle = FFSandboxGrantPath(parent, NO, NULL);
    data = [NSData dataWithContentsOfFile:path];
    if (handle >= 0) FFSandboxReleaseHandle(handle);
    return data;
}

static BOOL FFLSHasMagic(NSString *path) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (handle == nil) return NO;
    NSData *header = nil;
    @try {
        header = [handle readDataOfLength:4];
    } @catch (__unused NSException *exception) {
        header = nil;
    }
    @try { [handle closeFile]; } @catch (__unused NSException *exception) {}
    if (header.length < 4) return NO;
    const uint8_t *bytes = header.bytes;
    return bytes[0] == 0x62 && bytes[1] == 0x64 && bytes[2] == 0x73 && bytes[3] == 0x6c;
}

typedef struct {
    __unsafe_unretained NSString *path;
    __unsafe_unretained NSString *parent;
    unsigned long long size;
    double modifiedAt;
} FFLSCandidate;

static void FFLSInspectDirectory(NSString *directory, NSMutableArray<NSDictionary *> *found) {
    NSMutableSet<NSString *> *visited = nil;
    (void)visited;
    for (NSString *name in FFLSListDirectoryCheap(directory)) {
        if (![name hasPrefix:@"com.apple.LaunchServices-"] || ![name hasSuffix:@".csstore"]) continue;
        NSString *path = [directory stringByAppendingPathComponent:name];
        NSDictionary *attributes = [[NSFileManager defaultManager]
            attributesOfItemAtPath:path error:NULL];
        if (attributes == nil) continue;
        unsigned long long size = [attributes[NSFileSize] unsignedLongLongValue];
        if (size < FFMinimumStoreBytes || size > FFMaximumStoreBytes) continue;
        if (!FFLSHasMagic(path)) continue;
        [found addObject:@{
            @"path": path,
            @"parent": directory,
            @"size": @(size),
            @"mtime": attributes[NSFileModificationDate] ?: [NSDate date],
        }];
    }
}

+ (NSArray<NSDictionary *> *)candidates {
    NSMutableArray<NSDictionary *> *found = [NSMutableArray array];

    // Remembered store first (fast path; validated by magic/size on read).
    NSString *remembered = [[NSUserDefaults standardUserDefaults]
        stringForKey:@"FFLaunchServicesStorePath"];
    if (remembered.length > 0) {
        NSDictionary *attributes = [[NSFileManager defaultManager]
            attributesOfItemAtPath:remembered error:NULL];
        unsigned long long size = [attributes[NSFileSize] unsignedLongLongValue];
        if (size >= FFMinimumStoreBytes && size <= FFMaximumStoreBytes && FFLSHasMagic(remembered)) {
            return @[@{
                @"path": remembered,
                @"parent": [remembered stringByDeletingLastPathComponent],
                @"size": @(size),
                @"mtime": attributes[NSFileModificationDate] ?: [NSDate date],
            }];
        }
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"FFLaunchServicesStorePath"];
    }

    // Route 1: MCM class 10 for com.apple.lsd — a real container target, so a
    // token can be minted for its Library/Caches (the directory lsd writes to).
    if (MCMBridgeAvailable()) {
        NSString *metadataError = nil;
        NSString *lsdContainer = MCMActivateContainerPath(10, @"com.apple.lsd", NO, &metadataError);
        if (lsdContainer.length > 0) {
            NSString *caches = [lsdContainer stringByAppendingPathComponent:@"Library/Caches"];
            int64_t handle = FFSandboxGrantPath(caches, NO, NULL);
            FFLSInspectDirectory(caches, found);
            if (handle >= 0) FFSandboxReleaseHandle(handle);
        }
    }

    // Route 2: the daemon/system container trees. Listing the tree root is not
    // granted (it is a parent, -6); each container's Caches is a mintable target.
    NSArray<NSString *> *daemonRoots = @[
        @"/var/mobile/Containers/Data/InternalDaemon",
        @"/var/mobile/Containers/Data/System",
    ];
    for (NSString *root in daemonRoots) {
        if (found.count > 0) break;
        NSArray<NSString *> *containers = FFLSListDirectory(root);
        if (containers.count == 0) continue;
        for (NSString *container in containers) {
            NSString *path = [root stringByAppendingPathComponent:container];
            NSString *caches = [path stringByAppendingPathComponent:@"Library/Caches"];
            int64_t cacheGrant = FFSandboxGrantPath(caches, NO, NULL);
            FFLSInspectDirectory(caches, found);
            if (cacheGrant >= 0) FFSandboxReleaseHandle(cacheGrant);
            if (found.count > 0) break;   // first daemon with a store wins
        }
    }

    // Route 3: legacy locations. Grant the directory when it happens to be a
    // container target; on failure keep going with a plain read.
    for (NSString *legacy in @[@"/var/db/lsd", @"/var/mobile/Library/Caches"]) {
        int64_t handle = FFSandboxGrantPath(legacy, NO, NULL);
        FFLSInspectDirectory(legacy, found);
        if (handle >= 0) FFSandboxReleaseHandle(handle);
    }

    return found;
}

+ (FFLaunchServicesSnapshot *)parseData:(NSData *)data {
    if (data.length < FFMinimumStoreBytes || data.length > FFMaximumStoreBytes) return nil;
    const uint8_t *bytes = data.bytes;
    size_t length = data.length;
    if (length < 4) return nil;
    if (!(bytes[0] == 0x62 && bytes[1] == 0x64 && bytes[2] == 0x73 && bytes[3] == 0x6c)) return nil;

    size_t heapOffset = FFfirstHeapOffset(bytes, length);
    size_t bitsetBytes = FFMaxStringID / 8;
    uint8_t *neededStrings = calloc(bitsetBytes, 1);
    uint8_t *stringsInHeap = calloc(bitsetBytes, 1);
    if (neededStrings == NULL || stringsInHeap == NULL) {
        free(neededStrings);
        free(stringsInHeap);
        return nil;
    }

    typedef struct {
        uint32_t *refs;
        size_t count;
        size_t capacity;
    } FFRefList;

    FFRefList bundleRecords[kFFLayoutCount];
    FFRefList pluginRecords[kFFLayoutCount];
    memset(bundleRecords, 0, sizeof(bundleRecords));
    memset(pluginRecords, 0, sizeof(pluginRecords));
    for (size_t index = 0; index < kFFLayoutCount; index++) {
        bundleRecords[index].capacity = FFMaxBundleRecords * 5;
        bundleRecords[index].refs = calloc(bundleRecords[index].capacity, sizeof(uint32_t));
        pluginRecords[index].capacity = FFMaxBundleRecords * 2;
        pluginRecords[index].refs = calloc(pluginRecords[index].capacity, sizeof(uint32_t));
    }

    FFLaunchServicesSnapshot *result = nil;
    @try {
        // ---- pass 1: collect Bundle and plug-in records -------------------
        BOOL tooManyRecords = NO;
        size_t offset = 0;
        while (offset + 8 + FFMaximumRecordSize <= length && !tooManyRecords) {
            uint32_t size = FFrd32(bytes, offset + 4);
            for (size_t index = 0; index < kFFLayoutCount; index++) {
                const FFLSLayout *layout = &kFFLayouts[index];
                if (layout->pluginSize == size) {
                    FFRefList *list = &pluginRecords[index];
                    if (list->count + 2 <= list->capacity) {
                        uint32_t bundleRef = FFrd32(bytes, offset + 8 + layout->pluginBundleIDOffset);
                        uint32_t containerRef = FFrd32(bytes, offset + 8 + layout->pluginContainerOffset);
                        if (FFisValidRef(bundleRef) && FFisValidRef(containerRef)) {
                            list->refs[list->count++] = bundleRef;
                            list->refs[list->count++] = containerRef;
                            FFsetBit(neededStrings, bundleRef >> 2);
                            FFsetBit(neededStrings, containerRef >> 2);
                        }
                    }
                }
                if (layout->bundleSize == size) {
                    FFRefList *list = &bundleRecords[index];
                    if (list->count + 5 > list->capacity) {
                        tooManyRecords = YES;
                        break;
                    }
                    uint32_t refs[5] = {
                        FFrd32(bytes, offset + 8 + layout->bundleIDOffset),
                        FFrd32(bytes, offset + 8 + layout->nameOffset),
                        FFrd32(bytes, offset + 8 + layout->displayNameOffset),
                        FFrd32(bytes, offset + 8 + layout->containerOffset),
                        FFrd32(bytes, offset + 8 + layout->bundlePathOffset),
                    };
                    if (!FFisValidRef(refs[0])) continue;
                    for (size_t refIndex = 0; refIndex < 5; refIndex++) {
                        list->refs[list->count++] = refs[refIndex];
                        if (FFisValidRef(refs[refIndex])) {
                            FFsetBit(neededStrings, refs[refIndex] >> 2);
                        }
                    }
                }
            }
            offset += 4;
        }
        if (tooManyRecords) return nil;

        BOOL anyRecords = NO;
        for (size_t index = 0; index < kFFLayoutCount; index++) {
            if (bundleRecords[index].count > 0 || pluginRecords[index].count > 0) {
                anyRecords = YES;
                break;
            }
        }
        if (!anyRecords) return nil;

        // ---- pass 2: decode the string table ------------------------------
        NSMutableDictionary<NSNumber *, NSString *> *strings = [NSMutableDictionary dictionary];
        NSMutableDictionary<NSNumber *, NSString *> *pathStrings = [NSMutableDictionary dictionary];
        NSMutableSet<NSNumber *> *pathConflicts = [NSMutableSet set];
        NSUInteger decodedStrings = 0;
        NSUInteger decodedBytes = 0;

        offset = 0;
        while (offset + 8 <= length) {
            uint32_t stringID = FFrd32(bytes, offset);
            if (stringID == 0 || stringID >= FFMaxStringID || !FFbitIsSet(neededStrings, stringID)) {
                offset += 4;
                continue;
            }

            BOOL isInHeap = offset >= heapOffset;
            BOOL hadString = strings[@(stringID)] != nil;
            BOOL keepGeneral = !hadString ||
                (isInHeap && !FFbitIsSet(stringsInHeap, stringID));

            BOOL maybePath = NO;
            if (offset + 8 < length) {
                uint32_t peekLength = FFrd32(bytes, offset + 4);
                if (peekLength >= 6 && peekLength < FFMaxStringLength && bytes[offset + 8] == '/') {
                    maybePath = YES;
                }
            }
            if (!keepGeneral && !maybePath) {
                offset += 4;
                continue;
            }

            NSString *value = FFdecodeString(bytes, length, offset);
            if (value == nil) {
                offset += 4;
                continue;
            }

            if (maybePath) {
                if ([value containsString:@"/mobile/Containers/Data/"]) {
                    FFstorePathString(value, stringID, pathStrings, pathConflicts);
                }
            }

            if (keepGeneral && decodedStrings < 200000 &&
                decodedBytes + value.length <= 8 * 1024 * 1024) {
                strings[@(stringID)] = value;
                decodedStrings++;
                decodedBytes += value.length;
                if (isInHeap) FFsetBit(stringsInHeap, stringID);
            }
            offset += 4;
        }

        // ---- pass 3: resolve every layout, keep the best mapping ----------
        NSMutableDictionary<NSString *, NSString *> *bestContainers = nil;
        NSMutableDictionary<NSString *, NSString *> *bestDisplayNames = nil;
        NSString *bestLabel = nil;
        NSUInteger bestDisplayCount = 0;

        for (size_t index = 0; index < kFFLayoutCount; index++) {
            const FFLSLayout *layout = &kFFLayouts[index];
            NSMutableDictionary<NSString *, NSString *> *containers = [NSMutableDictionary dictionary];
            NSMutableSet<NSString *> *conflicts = [NSMutableSet set];
            NSMutableDictionary<NSString *, NSString *> *displayNames = [NSMutableDictionary dictionary];

            FFRefList *plugins = &pluginRecords[index];
            for (size_t pluginIndex = 0; pluginIndex + 1 < plugins->count; pluginIndex += 2) {
                uint32_t bundleRef = plugins->refs[pluginIndex];
                uint32_t containerRef = plugins->refs[pluginIndex + 1];
                NSString *bundleID = strings[@(bundleRef >> 2)];
                NSString *rawPath = pathStrings[@(containerRef >> 2)] ?: strings[@(containerRef >> 2)];
                if (bundleID == nil || rawPath == nil) continue;
                if (![self looksLikeBundleIdentifier:bundleID]) continue;
                NSString *path = [self canonicalContainerPath:rawPath];
                if (![self isDataContainerPath:path]) continue;
                if (![path containsString:@"/Data/PluginKitPlugin/"]) continue;
                NSString *existing = containers[path];
                if (existing != nil) {
                    if (![existing isEqualToString:bundleID]) [conflicts addObject:path];
                } else {
                    containers[path] = bundleID;
                }
            }

            FFRefList *records = &bundleRecords[index];
            for (size_t recordIndex = 0; recordIndex + 4 < records->count; recordIndex += 5) {
                uint32_t bundleRef = records->refs[recordIndex];
                NSString *bundleID = strings[@(bundleRef >> 2)];
                if (bundleID == nil || ![self looksLikeBundleIdentifier:bundleID]) continue;

                uint32_t containerRef = records->refs[recordIndex + 3];
                if (containerRef != 0 && (containerRef & 3) == 0) {
                    NSString *rawPath = pathStrings[@(containerRef >> 2)] ?: strings[@(containerRef >> 2)];
                    if (rawPath != nil) {
                        NSString *path = [self canonicalContainerPath:rawPath];
                        if ([self isDataContainerPath:path] &&
                            [path containsString:@"/Data/Application/"]) {
                            NSString *existing = containers[path];
                            if (existing != nil) {
                                if (![existing isEqualToString:bundleID]) [conflicts addObject:path];
                            } else {
                                containers[path] = bundleID;
                            }
                        }
                    }
                }

                uint32_t nameRef = records->refs[recordIndex + 1];
                uint32_t displayRef = records->refs[recordIndex + 2];
                NSString *bundleName = (nameRef & 3) != 0 ? nil : strings[@(nameRef >> 2)];
                NSString *displayName = (displayRef & 3) != 0 ? nil : strings[@(displayRef >> 2)];
                NSString *safeDisplay = FFsafeDisplayName(displayName);
                if (safeDisplay.length && displayNames[bundleID] == nil) {
                    displayNames[bundleID] = safeDisplay;
                }
                NSString *safeName = FFsafeDisplayName(bundleName);
                if (safeName.length && displayNames[bundleID] == nil) {
                    displayNames[bundleID] = safeName;
                }
                (void)layout;
            }

            for (NSString *conflict in conflicts) {
                [containers removeObjectForKey:conflict];
            }

            if (bestContainers == nil || containers.count > bestContainers.count ||
                (containers.count == bestContainers.count && displayNames.count > bestDisplayCount)) {
                bestContainers = [containers copy];
                bestDisplayNames = [displayNames copy];
                bestDisplayCount = displayNames.count;
                bestLabel = [NSString stringWithUTF8String:layout->label];
            }
        }

        if (bestContainers.count == 0) return nil;

        FFLaunchServicesSnapshot *snapshot = [FFLaunchServicesSnapshot new];
        snapshot.containerBundleIDs = bestContainers;
        snapshot.displayNames = bestDisplayNames ?: @{};
        snapshot.layoutLabel = bestLabel ?: @"?";
        snapshot.mappedContainerCount = bestContainers.count;
        result = snapshot;
    } @finally {
        for (size_t index = 0; index < kFFLayoutCount; index++) {
            free(bundleRecords[index].refs);
            free(pluginRecords[index].refs);
        }
        free(neededStrings);
        free(stringsInHeap);
    }
    return result;
}

+ (NSString *)signatureForStorePath:(NSString *)path {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    if (attributes == nil) return nil;
    return [NSString stringWithFormat:@"%@|%llu|%.0f", path,
            [attributes[NSFileSize] unsignedLongLongValue],
            [attributes[NSFileModificationDate] timeIntervalSince1970]];
}

+ (BOOL)rememberedStoreSignatureMatches:(NSString *)signature {
    if (signature.length == 0) return NO;
    NSArray<NSString *> *parts = [signature componentsSeparatedByString:@"|"];
    if (parts.count < 3) return NO;
    NSString *existing = [self signatureForStorePath:parts[0]];
    return existing != nil && [existing isEqualToString:signature];
}

+ (FFLaunchServicesSnapshot *)snapshot {
    [FFLSLock() lock];
    @try {
        // A cached snapshot is only trusted while the store file on disk did not
        // change (new app installed → lsd rewrites the file → new signature).
        if (FFLSCachedSnapshot != nil) {
            if ([self rememberedStoreSignatureMatches:FFLSCachedSignature]) {
                return FFLSCachedSnapshot;
            }
            FFLSCachedSnapshot = nil;
            FFLSCachedSignature = nil;
        }

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        // In-memory miss backoff (1 h) and persisted miss backoff (24 h): a
        // store that does not exist at launch must not be re-scanned on every
        // lookup, and a miss must survive a relaunch.
        if (FFLSMissAt != nil && [[NSDate date] timeIntervalSinceDate:FFLSMissAt] < 3600.0) {
            return nil;
        }
        id persistedMiss = [defaults objectForKey:@"FFLaunchServicesStoreMissedAt"];
        if ([persistedMiss isKindOfClass:[NSDate class]] &&
            [[NSDate date] timeIntervalSinceDate:(NSDate *)persistedMiss] < 86400.0) {
            return nil;
        }

        NSArray<NSDictionary *> *candidates = [self candidates];
        if (candidates.count == 0) {
            FFLSMissAt = [NSDate date];
            [defaults setObject:[NSDate date] forKey:@"FFLaunchServicesStoreMissedAt"];
            [defaults synchronize];
            FFLog(@"launchservices: store não encontrado (lsd indisponível)");
            return nil;
        }

        NSDictionary *newest = nil;
        for (NSDictionary *candidate in candidates) {
            if (newest == nil) { newest = candidate; continue; }
            NSDate *leftDate = candidate[@"mtime"];
            NSDate *rightDate = newest[@"mtime"];
            if ([leftDate compare:rightDate] == NSOrderedDescending ||
                ([leftDate isEqualToDate:rightDate] &&
                 [candidate[@"size"] unsignedLongLongValue] > [newest[@"size"] unsignedLongLongValue])) {
                newest = candidate;
            }
        }

        NSString *signature = [self signatureForStorePath:newest[@"path"]];
        if (signature == nil) {
            FFLSMissAt = [NSDate date];
            return nil;
        }
        if (FFLSCachedSignature != nil && [FFLSCachedSignature isEqualToString:signature] &&
            FFLSCachedSnapshot != nil) {
            return FFLSCachedSnapshot;
        }

        NSData *data = FFLSReadFile(newest[@"path"]);
        FFLaunchServicesSnapshot *snapshot = nil;
        if (data.length > 0) snapshot = [self parseData:data];
        FFLSCachedSignature = signature;
        if (snapshot == nil) {
            FFLSMissAt = [NSDate date];
            [defaults setObject:[NSDate date] forKey:@"FFLaunchServicesStoreMissedAt"];
            [defaults synchronize];
            FFLog(@"launchservices: parse falhou %@ bytes=%lu",
                  [newest[@"path"] lastPathComponent], (unsigned long)data.length);
            return nil;
        }
        FFLSCachedSnapshot = snapshot;
        [defaults setObject:newest[@"path"] forKey:@"FFLaunchServicesStorePath"];
        [defaults removeObjectForKey:@"FFLaunchServicesStoreMissedAt"];
        [defaults synchronize];
        FFLog(@"launchservices: layout=%@ containers=%lu names=%lu bytes=%lu",
              snapshot.layoutLabel, (unsigned long)snapshot.mappedContainerCount,
              (unsigned long)snapshot.displayNames.count, (unsigned long)data.length);
        return snapshot;
    } @finally {
        [FFLSLock() unlock];
    }
}
@end
