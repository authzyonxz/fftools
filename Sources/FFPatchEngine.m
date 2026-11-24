//
//  FFPatchEngine.m
//  FFPatch
//

#import "FFPatchEngine.h"
#import "FFCore.h"
#import "FFSandbox.h"
#import "FFContainerStore.h"
#import "FFLicense.h"

#import <sys/stat.h>
#import <unistd.h>
#import <fcntl.h>
#import <errno.h>

static NSString *const FFJournalSchemaKey     = @"schema";
static NSString *const FFJournalStatusKey     = @"status";
static NSString *const FFJournalRecordsKey    = @"records";
static NSString *const FFJournalCreatedDirsKey = @"createdDirectories";
static NSString *const FFJournalContainerKey  = @"containerRoot";
static NSString *const FFJournalFingerprintKey = @"containerFingerprint";
static NSString *const FFJournalFunctionKey   = @"functionID";
static NSString *const FFJournalGameKey       = @"gameID";
static NSString *const FFJournalBundleKey     = @"bundleID";
static NSString *const FFJournalDateKey       = @"createdAt";

static NSString *const FFJournalStatusPrepared  = @"prepared";
static NSString *const FFJournalStatusApplied   = @"applied";
static NSString *const FFJournalStatusRestored  = @"restored";
static NSString *const FFJournalStatusRolledBack = @"rolledBack";

static NSInteger const FFJournalSchemaVersion = 1;

static NSRecursiveLock *FFPatchEngineOperationLock(void) {
    static NSRecursiveLock *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSRecursiveLock new];
    });
    return lock;
}

#pragma mark - Rule model

@interface FFRule : NSObject
@property (nonatomic, copy) NSString *relativePath;
@property (nonatomic, copy) NSString *sourcePath;
@property (nonatomic, copy) NSString *targetPath;
@property (nonatomic, strong) NSData *replacementData;
@property (nonatomic, copy) NSString *replacementDigest;
@property (nonatomic, assign) BOOL existedBefore;
@property (nonatomic, copy, nullable) NSString *backupFileName;
@property (nonatomic, copy, nullable) NSString *originalDigest;
@end

@implementation FFRule
@end

#pragma mark - Receipt

@implementation FFPatchReceipt
@end

@implementation FFPatchApplyStats
@end

#pragma mark - Engine

@implementation FFPatchEngine

+ (instancetype)sharedEngine {
    static FFPatchEngine *engine;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        engine = [FFPatchEngine new];
    });
    return engine;
}

#pragma mark Paths

- (NSString *)transactionsRoot {
    static NSString *path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        path = [FFPatchRootDirectory() stringByAppendingPathComponent:@"Transactions"];
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    });
    return path;
}

- (NSString *)receiptsRoot {
    static NSString *path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        path = [FFPatchRootDirectory() stringByAppendingPathComponent:@"Receipts"];
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    });
    return path;
}

- (NSString *)keyForFunction:(FFFunction *)function game:(FFGame *)game {
    return [NSString stringWithFormat:@"%@__%@", function.funcID, game.gameID];
}

- (NSString *)receiptPathForFunction:(FFFunction *)function game:(FFGame *)game {
    NSString *key = [self keyForFunction:function game:game];
    NSString *folder = [[self receiptsRoot] stringByAppendingPathComponent:key];
    return [folder stringByAppendingPathExtension:@"plist"];
}

- (NSString *)fingerprintForContainerPath:(NSString *)path {
    return FFSHA256HexOfData([path dataUsingEncoding:NSUTF8StringEncoding]);
}

#pragma mark Receipts / state

- (FFPatchReceipt *)receiptForFunction:(FFFunction *)function game:(FFGame *)game {
    NSDictionary *plist = FFReadPlist([self receiptPathForFunction:function game:game]);
    if (plist == nil) return nil;
    FFPatchReceipt *receipt = [FFPatchReceipt new];
    receipt.functionID = plist[@"functionID"] ?: function.funcID;
    receipt.gameID = plist[@"gameID"] ?: game.gameID;
    receipt.bundleID = plist[@"bundleID"] ?: game.bundleID;
    receipt.journalPath = plist[@"journalPath"] ?: @"";
    receipt.status = plist[@"status"] ?: @"";
    receipt.fileCount = [plist[@"fileCount"] unsignedIntegerValue];
    if ([plist[@"appliedAt"] isKindOfClass:[NSDate class]]) {
        receipt.appliedAt = plist[@"appliedAt"];
    }
    return receipt;
}

- (FFFunctionState)stateForFunction:(FFFunction *)function game:(FFGame *)game {
    FFPatchReceipt *receipt = [self receiptForFunction:function game:game];
    if (receipt == nil) return FFFunctionStateIdle;
    return [receipt.status isEqualToString:FFJournalStatusApplied]
        ? FFFunctionStateApplied : FFFunctionStateIdle;
}

- (NSArray<NSString *> *)appliedFunctionIDsForGame:(FFGame *)game {
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    for (FFPatchReceipt *receipt in [self allReceipts]) {
        if (![receipt.status isEqualToString:FFJournalStatusApplied]) continue;
        if (![receipt.gameID isEqualToString:game.gameID]) continue;
        [identifiers addObject:receipt.functionID];
    }
    return identifiers;
}

- (NSArray<NSString *> *)gamesWhereFunctionIsApplied:(FFFunction *)function {
    NSMutableArray<NSString *> *gameIDs = [NSMutableArray array];
    for (FFPatchReceipt *receipt in [self allReceipts]) {
        if (![receipt.status isEqualToString:FFJournalStatusApplied]) continue;
        if (![receipt.functionID isEqualToString:function.funcID]) continue;
        [gameIDs addObject:receipt.gameID];
    }
    return gameIDs;
}

- (NSArray<FFPatchReceipt *> *)allReceipts {
    NSMutableArray<FFPatchReceipt *> *receipts = [NSMutableArray array];
    NSArray<NSString *> *entries = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:[self receiptsRoot] error:NULL];
    for (NSString *entry in entries) {
        if (![entry.pathExtension isEqualToString:@"plist"]) continue;
        NSDictionary *plist = FFReadPlist([[self receiptsRoot] stringByAppendingPathComponent:entry]);
        if (plist == nil) continue;
        FFPatchReceipt *receipt = [FFPatchReceipt new];
        receipt.functionID = plist[@"functionID"] ?: @"";
        receipt.gameID = plist[@"gameID"] ?: @"";
        receipt.bundleID = plist[@"bundleID"] ?: @"";
        receipt.journalPath = plist[@"journalPath"] ?: @"";
        receipt.status = plist[@"status"] ?: @"";
        receipt.fileCount = [plist[@"fileCount"] unsignedIntegerValue];
        if ([plist[@"appliedAt"] isKindOfClass:[NSDate class]]) {
            receipt.appliedAt = plist[@"appliedAt"];
        }
        [receipts addObject:receipt];
    }
    return receipts;
}

- (NSUInteger)payloadFileCountForFunction:(FFFunction *)function game:(FFGame *)game {
    NSArray<NSString *> *relatives = nil;
    NSArray<NSString *> *files = [self.manifest payloadFilesForFunction:function
                                                                   game:game
                                                          relativePaths:&relatives
                                                                  error:NULL];
    return files.count;
}

#pragma mark - Apply

- (BOOL)applyFunction:(FFFunction *)function game:(FFGame *)game error:(NSError **)error {
    return [self applyFunction:function game:game stats:NULL error:error];
}

- (BOOL)applyFunction:(FFFunction *)function
                 game:(FFGame *)game
                stats:(FFPatchApplyStats **)stats
                error:(NSError **)error {
    NSRecursiveLock *operationLock = FFPatchEngineOperationLock();
    [operationLock lock];
    @try {
    if (![FFLicense current].apiValidated) {
        if (error) *error = FFMakeError(FFErrorAccessDenied, @"A API não autorizou esta ativação");
        return NO;
    }
    if (!FFSandboxOSIsSupported()) {
        if (error) *error = FFMakeError(FFErrorUnsupportedOS, @"%@", FFSandboxUnsupportedReason());
        return NO;
    }
    FFPatchReceipt *existing = [self receiptForFunction:function game:game];
    if (existing != nil && [existing.status isEqualToString:FFJournalStatusApplied]) {
        if (error) {
            *error = FFMakeError(FFErrorAlreadyApplied,
                                 @"%@ já está injetado em %@", function.name, game.displayName);
        }
        return NO;
    }

    NSError *localError = nil;
    NSArray<NSString *> *relativePaths = nil;
    NSArray<NSString *> *payloadFiles = [self.manifest payloadFilesForFunction:function
                                                                          game:game
                                                                 relativePaths:&relativePaths
                                                                         error:&localError];
    if (payloadFiles.count == 0 || payloadFiles.count != relativePaths.count) {
        if (error) *error = localError ?: FFMakeError(FFErrorPayloadMissing,
                                                      @"payload vazio para %@", function.name);
        return NO;
    }

    NSString *container = [[FFContainerStore sharedStore] containerForBundleID:game.bundleID
                                                                          kind:game.containerKind
                                                                         error:&localError];
    if (container.length == 0) {
        if (error) *error = localError ?: FFMakeError(FFErrorAppNotFound,
                                                      @"%@ não encontrado", game.displayName);
        return NO;
    }
    NSString *fingerprint = [self fingerprintForContainerPath:container];

    // ---- build rules -------------------------------------------------------
    NSMutableArray<FFRule *> *rules = [NSMutableArray array];
    NSMutableSet<NSString *> *targets = [NSMutableSet set];
    NSUInteger scannedEntries = 0;
    BOOL usedContainerSearch = NO;
    NSMutableArray<NSString *> *searchLog = [NSMutableArray array];

    for (NSUInteger index = 0; index < payloadFiles.count; index++) {
        NSString *declaredRelative = relativePaths[index];
        NSString *payloadPath = payloadFiles[index];

        if (!FFRelativePathIsSafe(declaredRelative)) {
            if (error) *error = FFMakeError(FFErrorInvalidPayload,
                                            @"caminho inseguro no payload: %@", declaredRelative);
            return NO;
        }

        NSData *replacement = [NSData dataWithContentsOfFile:payloadPath];
        if (replacement.length == 0) {
            if (error) *error = FFMakeError(FFErrorInvalidPayload,
                                            @"payload vazio: %@", declaredRelative);
            return NO;
        }

        NSMutableArray<NSString *> *candidateRelatives = [NSMutableArray array];

        if (function.locateMode == FFLocateModePath) {
            [candidateRelatives addObject:declaredRelative];
        } else {
            NSString *searchName = payloadPath.lastPathComponent;
            if (index < function.locateNames.count) searchName = function.locateNames[index];

            BOOL exactExists = NO;
            if (function.locateMode == FFLocateModePathOrName) {
                struct stat exactInfo;
                NSString *exactPath = [container stringByAppendingPathComponent:declaredRelative];
                exactExists = lstat(exactPath.fileSystemRepresentation, &exactInfo) == 0 &&
                              !S_ISDIR(exactInfo.st_mode);
            }

            if (exactExists) {
                [candidateRelatives addObject:declaredRelative];
            } else {
                NSUInteger scanned = 0;
                NSArray<NSString *> *matches = [self searchContainer:container
                                                            fileName:searchName
                                                               roots:function.locateRoots
                                                          maxMatches:function.locateMaxMatches
                                                          scannedOut:&scanned];
                scannedEntries += scanned;
                if (matches.count > 0) {
                    [candidateRelatives addObjectsFromArray:matches];
                    usedContainerSearch = YES;
                    [searchLog addObject:[NSString stringWithFormat:@"%@ → %lu match(es) / %lu entradas",
                                          searchName, (unsigned long)matches.count,
                                          (unsigned long)scanned]];
                } else if (function.locateMode == FFLocateModePathOrName) {
                    // Nothing to find yet: create the declared path so the
                    // pipeline keeps working with marker payloads.
                    [candidateRelatives addObject:declaredRelative];
                } else {
                    if (error) {
                        *error = FFMakeError(FFErrorTargetNotFound,
                                             @"nenhum arquivo \"%@\" no container de %@ "
                                             @"(%lu entradas varridas)",
                                             searchName, game.displayName, (unsigned long)scanned);
                    }
                    return NO;
                }
            }
        }

        for (NSString *relativePath in candidateRelatives) {
            NSString *target = FFResolveContainedPath(container, relativePath, &localError);
            if (target.length == 0) {
                if (error) *error = localError;
                return NO;
            }
            if ([targets containsObject:target]) continue;
            [targets addObject:target];

            if (FFPathContainsSymlink(container, relativePath)) {
                if (error) *error = FFMakeError(FFErrorSymlinkRefused,
                                                @"%@ passa por um symlink", relativePath);
                return NO;
            }

            struct stat info;
            BOOL exists = lstat(target.fileSystemRepresentation, &info) == 0;
            if (exists) {
                if (S_ISDIR(info.st_mode)) {
                    if (error) *error = FFMakeError(FFErrorTargetIsDirectory,
                                                    @"%@ é um diretório no container", relativePath);
                    return NO;
                }
                if (S_ISLNK(info.st_mode)) {
                    if (error) *error = FFMakeError(FFErrorSymlinkRefused,
                                                    @"%@ é um symlink no container", relativePath);
                    return NO;
                }
            }

            FFRule *rule = [FFRule new];
            rule.relativePath = relativePath;
            rule.sourcePath = payloadPath;
            rule.targetPath = target;
            rule.replacementData = replacement;
            rule.replacementDigest = FFSHA256HexOfData(replacement);
            rule.existedBefore = exists;
            [rules addObject:rule];
        }
    }

    if (rules.count == 0) {
        if (error) *error = FFMakeError(FFErrorPayloadMissing,
                                        @"nenhum arquivo resolvido para %@", function.name);
        return NO;
    }

    if (stats != NULL) {
        FFPatchApplyStats *report = [FFPatchApplyStats new];
        report.fileCount = rules.count;
        report.usedContainerSearch = usedContainerSearch;
        report.scannedEntries = scannedEntries;
        report.searchSummary = searchLog.count ? [searchLog componentsJoinedByString:@"; "] : nil;
        *stats = report;
    }
    // ---- transaction directory --------------------------------------------
    NSString *transactionDirectory = [[[self transactionsRoot]
        stringByAppendingPathComponent:[self keyForFunction:function game:game]]
        stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:transactionDirectory
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&localError]) {
        if (error) *error = localError ?: FFMakeError(FFErrorApplyFailed, @"sem diretório de transação");
        return NO;
    }

    // ---- back up the current bytes ----------------------------------------
    for (NSUInteger index = 0; index < rules.count; index++) {
        FFRule *rule = rules[index];
        if (!rule.existedBefore) continue;
        NSString *backupName = [NSString stringWithFormat:@"%lu.original", (unsigned long)index];
        NSString *backupPath = [transactionDirectory stringByAppendingPathComponent:backupName];
        if (![[NSFileManager defaultManager] copyItemAtPath:rule.targetPath
                                                     toPath:backupPath
                                                      error:&localError]) {
            if (error) *error = localError ?: FFMakeError(FFErrorApplyFailed,
                                                          @"backup de %@ falhou", rule.relativePath);
            return NO;
        }
        rule.backupFileName = backupName;
        rule.originalDigest = FFSHA256HexOfFile(backupPath, NULL);
        if (rule.originalDigest.length == 0) {
            if (error) *error = FFMakeError(FFErrorApplyFailed,
                                            @"backup ilegível: %@", rule.relativePath);
            return NO;
        }
    }

    // ---- prepared journal --------------------------------------------------
    NSMutableArray<NSDictionary *> *recordDictionaries = [NSMutableArray array];
    for (NSUInteger index = 0; index < rules.count; index++) {
        FFRule *rule = rules[index];
        NSMutableDictionary *record = [NSMutableDictionary dictionary];
        record[@"index"] = @(index);
        record[@"relativePath"] = rule.relativePath;
        record[@"targetPath"] = rule.targetPath;
        record[@"existed"] = @(rule.existedBefore);
        record[@"replacementDigest"] = rule.replacementDigest;
        if (rule.backupFileName.length) record[@"backupFile"] = rule.backupFileName;
        if (rule.originalDigest.length) record[@"originalDigest"] = rule.originalDigest;
        [recordDictionaries addObject:record];
    }

    NSMutableDictionary *journal = [NSMutableDictionary dictionary];
    journal[FFJournalSchemaKey] = @(FFJournalSchemaVersion);
    journal[FFJournalStatusKey] = FFJournalStatusPrepared;
    journal[FFJournalFunctionKey] = function.funcID;
    journal[FFJournalGameKey] = game.gameID;
    journal[FFJournalBundleKey] = game.bundleID;
    journal[FFJournalContainerKey] = container;
    journal[FFJournalFingerprintKey] = fingerprint;
    journal[FFJournalDateKey] = [NSDate date];
    journal[FFJournalRecordsKey] = recordDictionaries;
    journal[FFJournalCreatedDirsKey] = @[];

    NSString *journalPath = [transactionDirectory stringByAppendingPathComponent:@"journal.plist"];
    if (!FFWritePlist(journal, journalPath, &localError)) {
        if (error) *error = localError;
        return NO;
    }

    // ---- create missing directories ---------------------------------------
    NSMutableArray<FFRule *> *ordered = [
        [rules sortedArrayUsingComparator:^NSComparisonResult(id leftObject, id rightObject) {
            FFRule *left = (FFRule *)leftObject;
            FFRule *right = (FFRule *)rightObject;
            NSUInteger leftDepth = left.relativePath.pathComponents.count;
            NSUInteger rightDepth = right.relativePath.pathComponents.count;
            if (leftDepth == rightDepth) return [left.relativePath compare:right.relativePath];
            return leftDepth < rightDepth ? NSOrderedAscending : NSOrderedDescending;
        }] mutableCopy];

    NSMutableArray<NSString *> *createdDirectories = [NSMutableArray array];
    for (FFRule *rule in ordered) {
        NSString *parent = [container stringByAppendingPathComponent:
            [rule.relativePath stringByDeletingLastPathComponent]];
        if (rule.relativePath.pathComponents.count <= 1) parent = container;
        if (![self ensureDirectory:parent container:container created:createdDirectories error:&localError]) {
            [self rollbackRules:rules
           transactionDirectory:transactionDirectory
                      container:container
             createdDirectories:createdDirectories
                       journal:journal
                   journalPath:journalPath];
            if (error) *error = localError;
            return NO;
        }
    }

    // ---- write with per-directory grants ----------------------------------
    for (NSUInteger index = 0; index < ordered.count; index++) {
        FFRule *rule = ordered[index];
        NSString *parent = rule.targetPath.stringByDeletingLastPathComponent;

        __block NSError *writeError = nil;
        BOOL wrote = FFSandboxPerformWithGrant(parent, YES, ^NSError * {
            NSError *error = nil;
            if (!FFSafeWriteFile(rule.targetPath, rule.replacementData, &error)) {
                return error ?: FFMakeError(FFErrorApplyFailed,
                                            @"escrita falhou em %@", rule.relativePath);
            }
            NSString *landed = FFSHA256HexOfFile(rule.targetPath, NULL);
            if (![landed isEqualToString:rule.replacementDigest]) {
                return FFMakeError(FFErrorVerifyFailed,
                                   @"SHA-256 não bateu em %@", rule.relativePath);
            }
            return nil;
        }, &writeError);

        if (!wrote) {
            [self rollbackRules:rules
           transactionDirectory:transactionDirectory
                      container:container
             createdDirectories:createdDirectories
                       journal:journal
                   journalPath:journalPath];
            if (error) *error = writeError;
            return NO;
        }
    }

    // ---- commit ------------------------------------------------------------
    journal[FFJournalStatusKey] = FFJournalStatusApplied;
    journal[FFJournalCreatedDirsKey] = createdDirectories;
    if (!FFWritePlist(journal, journalPath, &localError)) {
        [self rollbackRules:rules
       transactionDirectory:transactionDirectory
                  container:container
         createdDirectories:createdDirectories
                   journal:journal
               journalPath:journalPath];
        if (error) *error = localError;
        return NO;
    }

    NSDictionary *receipt = @{
        @"functionID": function.funcID,
        @"gameID": game.gameID,
        @"bundleID": game.bundleID,
        @"journalPath": journalPath,
        @"status": FFJournalStatusApplied,
        @"fileCount": @(rules.count),
        @"appliedAt": [NSDate date],
    };
    if (!FFWritePlist(receipt, [self receiptPathForFunction:function game:game], NULL)) {
        [self rollbackRules:rules
       transactionDirectory:transactionDirectory
                  container:container
         createdDirectories:createdDirectories
                   journal:journal
               journalPath:journalPath];
        if (error) *error = FFMakeError(FFErrorApplyFailed, @"não gravou o recibo");
        return NO;
    }

    FFLog(@"apply: %@ → %@ OK (%lu arquivos, container %@)",
          function.name, game.displayName, (unsigned long)rules.count, container);
    return YES;
    } @finally {
        [operationLock unlock];
    }
}

#pragma mark - Container search

- (NSArray<NSString *> *)searchContainer:(NSString *)container
                                fileName:(NSString *)fileName
                                   roots:(NSArray<NSString *> *)roots
                              maxMatches:(NSUInteger)maxMatches
                              scannedOut:(NSUInteger *)scannedOut {
    if (fileName.length == 0) return @[];
    if (maxMatches == 0) maxMatches = 8;

    NSSet<NSString *> *skipDirectories = [NSSet setWithArray:@[
        @"Caches", @"tmp", @"SplashBoard", @"Saved Application State",
        @"com.apple.nsurlsessiond", @".Trash", @"Snapshots", @"Logs"
    ]];
    NSUInteger maxDepth = 8;
    NSUInteger entryBudget = 400000;

    NSMutableArray<NSString *> *queue = [NSMutableArray array];
    NSMutableArray<NSNumber *> *depths = [NSMutableArray array];

    for (NSString *root in roots) {
        NSString *path = [container stringByAppendingPathComponent:root];
        BOOL isDirectory = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
            [queue addObject:root];
            [depths addObject:@(0)];
        }
    }
    if (queue.count == 0) {
        [queue addObject:@""];
        [depths addObject:@(0)];
    }

    NSMutableArray<NSString *> *matches = [NSMutableArray array];
    NSUInteger scanned = 0;
    NSString *needle = fileName.lowercaseString;
    NSUInteger cursor = 0;

    while (cursor < queue.count && matches.count < maxMatches && scanned < entryBudget) {
        NSString *relativeDirectory = queue[cursor];
        NSUInteger depth = depths[cursor].unsignedIntegerValue;
        cursor++;
        if (depth > maxDepth) continue;

        NSString *absolute = relativeDirectory.length
            ? [container stringByAppendingPathComponent:relativeDirectory]
            : container;

        NSArray<NSString *> *entries = [[NSFileManager defaultManager]
            contentsOfDirectoryAtPath:absolute error:NULL];
        if (entries == nil) {
            // Denied without a grant: ask for one and retry the listing once.
            int64_t handle = FFSandboxGrantPath(absolute, NO, NULL);
            entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:absolute error:NULL];
            if (handle >= 0) FFSandboxReleaseHandle(handle);
        }
        if (entries == nil) continue;

        for (NSString *entry in entries) {
            scanned++;
            if (scanned >= entryBudget) break;
            if ([entry hasPrefix:@"."]) continue;

            NSString *relative = relativeDirectory.length
                ? [relativeDirectory stringByAppendingPathComponent:entry]
                : entry;
            NSString *absoluteEntry = [absolute stringByAppendingPathComponent:entry];

            struct stat info;
            if (lstat(absoluteEntry.fileSystemRepresentation, &info) != 0) continue;
            if (S_ISLNK(info.st_mode)) continue;

            if (S_ISDIR(info.st_mode)) {
                if ([skipDirectories containsObject:entry]) continue;
                [queue addObject:relative];
                [depths addObject:@(depth + 1)];
                continue;
            }
            if (S_ISREG(info.st_mode) && [entry.lowercaseString isEqualToString:needle]) {
                [matches addObject:relative];
                if (matches.count >= maxMatches) break;
            }
        }
    }

    if (scannedOut) *scannedOut = scanned;
    FFLog(@"search: \"%@\" → %lu match(es), %lu entradas varridas",
          fileName, (unsigned long)matches.count, (unsigned long)scanned);
    return matches;
}

#pragma mark - Directory creation
- (BOOL)ensureDirectory:(NSString *)directory
              container:(NSString *)container
                created:(NSMutableArray<NSString *> *)created
                  error:(NSError **)error {
    if (directory.length == 0) return YES;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:directory isDirectory:&isDirectory]) {
        if (!isDirectory) {
            if (error) *error = FFMakeError(FFErrorApplyFailed,
                                            @"%@ existe e não é diretório",
                                            directory.lastPathComponent);
            return NO;
        }
        return YES;
    }

    NSString *parent = directory.stringByDeletingLastPathComponent;
    if (parent.length == 0 || [parent isEqualToString:directory]) return NO;
    if (![self ensureDirectory:parent container:container created:created error:error]) return NO;

    __block NSError *createError = nil;
    BOOL createdNow = FFSandboxPerformWithGrant(parent, YES, ^NSError * {
        NSError *fmError = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
                                       withIntermediateDirectories:NO
                                                        attributes:nil
                                                             error:&fmError]) {
            return fmError ?: FFMakeError(FFErrorApplyFailed,
                                          @"não criou %@", directory.lastPathComponent);
        }
        return nil;
    }, &createError);

    if (!createdNow) {
        if (error) *error = createError;
        return NO;
    }

    if (created != nil && [directory hasPrefix:container]) {
        NSString *relative = [directory substringFromIndex:MIN(directory.length, container.length)];
        if ([relative hasPrefix:@"/"]) relative = [relative substringFromIndex:1];
        if (relative.length) [created addObject:relative];
    }
    return YES;
}

#pragma mark - Rollback

- (void)rollbackRules:(NSArray<FFRule *> *)rules
   transactionDirectory:(NSString *)transactionDirectory
              container:(NSString *)container
     createdDirectories:(NSArray<NSString *> *)createdDirectories
                journal:(NSMutableDictionary *)journal
            journalPath:(NSString *)journalPath {
    // Newest first so nested writes unwind in the same order they landed.
    for (FFRule *rule in [rules reverseObjectEnumerator]) {
        NSString *parent = rule.targetPath.stringByDeletingLastPathComponent;
        if (rule.existedBefore && rule.backupFileName.length) {
            NSString *backup = [transactionDirectory stringByAppendingPathComponent:rule.backupFileName];
            FFSandboxPerformWithGrant(parent, YES, ^NSError * {
                NSError *error = nil;
                FFSafeCopyFile(backup, rule.targetPath, &error);
                return error;
            }, NULL);
        } else {
            FFSandboxPerformWithGrant(parent, YES, ^NSError * {
                [[NSFileManager defaultManager] removeItemAtPath:rule.targetPath error:NULL];
                return nil;
            }, NULL);
        }
    }

    // Remove directories this transaction created, deepest first, only when
    // they are empty — anything the game itself put in them stays.
    for (NSString *relative in [createdDirectories reverseObjectEnumerator]) {
        NSString *absolute = [container stringByAppendingPathComponent:relative];
        BOOL isDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:absolute isDirectory:&isDirectory]) continue;
        if (!isDirectory) continue;
        NSArray<NSString *> *contents = [[NSFileManager defaultManager]
            contentsOfDirectoryAtPath:absolute error:NULL];
        if (contents.count == 0) {
            [[NSFileManager defaultManager] removeItemAtPath:absolute error:NULL];
        }
    }

    journal[FFJournalStatusKey] = FFJournalStatusRolledBack;
    FFWritePlist(journal, journalPath, NULL);
    FFLog(@"rollback: transação desfeita");
}

#pragma mark - Restore

- (BOOL)restoreFunction:(FFFunction *)function game:(FFGame *)game error:(NSError **)error {
    NSRecursiveLock *operationLock = FFPatchEngineOperationLock();
    [operationLock lock];
    @try {
    FFPatchReceipt *receipt = [self receiptForFunction:function game:game];
    if (receipt == nil || ![receipt.status isEqualToString:FFJournalStatusApplied]) {
        if (error) {
            *error = FFMakeError(FFErrorNotApplied,
                                 @"%@ não está injetado em %@", function.name, game.displayName);
        }
        return NO;
    }
    if (receipt.journalPath.length == 0) {
        if (error) *error = FFMakeError(FFErrorBackupMissing, @"recibo sem journal");
        return NO;
    }

    NSDictionary *journal = FFReadPlist(receipt.journalPath);
    if (journal == nil) {
        if (error) *error = FFMakeError(FFErrorBackupMissing,
                                        @"journal ausente: %@", receipt.journalPath.lastPathComponent);
        return NO;
    }
    if (![journal[FFJournalStatusKey] isEqualToString:FFJournalStatusApplied]) {
        if (error) *error = FFMakeError(FFErrorNotApplied, @"journal não está aplicado");
        return NO;
    }

    NSString *container = [[FFContainerStore sharedStore] containerForBundleID:game.bundleID
                                                                          kind:game.containerKind
                                                                         error:error];
    if (container.length == 0) return NO;

    NSString *fingerprint = [self fingerprintForContainerPath:container];
    NSString *expected = journal[FFJournalFingerprintKey];
    if (expected.length && ![expected isEqualToString:fingerprint]) {
        if (error) {
            *error = FFMakeError(FFErrorContainerChanged,
                                 @"o container mudou desde a injeção (fingerprint). Reinstale o jogo ou "
                                 @"restaure manualmente antes de continuar.");
        }
        return NO;
    }

    NSString *transactionDirectory = [receipt.journalPath stringByDeletingLastPathComponent];
    NSArray<NSDictionary *> *records = journal[FFJournalRecordsKey] ?: @[];
    NSArray<NSString *> *createdDirectories = journal[FFJournalCreatedDirsKey] ?: @[];

    // ---- snapshot the current bytes ---------------------------------------
    NSString *recoveryDirectory = [transactionDirectory stringByAppendingPathComponent:
        [NSString stringWithFormat:@".recovery-%@", NSUUID.UUID.UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:recoveryDirectory
                              withIntermediateDirectories:NO attributes:nil error:NULL];

    NSMutableArray<NSDictionary *> *snapshots = [NSMutableArray array];
    for (NSUInteger index = 0; index < records.count; index++) {
        NSDictionary *record = records[index];
        NSString *target = [container stringByAppendingPathComponent:record[@"relativePath"]];
        struct stat info;
        if (lstat(target.fileSystemRepresentation, &info) != 0) continue;
        NSString *snapshotPath = [recoveryDirectory stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%lu.current", (unsigned long)index]];
        if (![[NSFileManager defaultManager] copyItemAtPath:target toPath:snapshotPath error:NULL]) {
            continue;
        }
        [snapshots addObject:@{@"target": target, @"snapshot": snapshotPath}];
    }

    BOOL failed = NO;
    NSError *restoreError = nil;

    // ---- put the originals back -------------------------------------------
    for (NSDictionary *record in [records reverseObjectEnumerator]) {
        NSString *relativePath = record[@"relativePath"];
        NSString *target = [container stringByAppendingPathComponent:relativePath];
        BOOL existed = [record[@"existed"] boolValue];
        NSString *parent = target.stringByDeletingLastPathComponent;

        if (existed) {
            NSString *backupName = record[@"backupFile"];
            NSString *expectedDigest = record[@"originalDigest"];
            NSString *backup = [transactionDirectory stringByAppendingPathComponent:backupName ?: @""];
            NSString *backupDigest = FFSHA256HexOfFile(backup, NULL);
            if (backupDigest.length == 0 || ![backupDigest isEqualToString:expectedDigest ?: @""]) {
                restoreError = FFMakeError(FFErrorBackupMissing,
                                           @"backup corrompido: %@", relativePath);
                failed = YES;
                break;
            }
            __block NSError *copyError = nil;
            BOOL copied = FFSandboxPerformWithGrant(parent, YES, ^NSError * {
                NSError *error = nil;
                FFSafeCopyFile(backup, target, &error);
                return error;
            }, &copyError);
            if (!copied) {
                restoreError = copyError;
                failed = YES;
                break;
            }
        } else {
            __block NSError *deleteError = nil;
            FFSandboxPerformWithGrant(parent, YES, ^NSError * {
                NSError *error = nil;
                if ([[NSFileManager defaultManager] fileExistsAtPath:target]) {
                    if (![[NSFileManager defaultManager] removeItemAtPath:target error:&error]) {
                        return error ?: FFMakeError(FFErrorRestoreFailed,
                                                    @"não removeu %@", relativePath);
                    }
                }
                return nil;
            }, &deleteError);
            if (deleteError != nil) {
                restoreError = deleteError;
                failed = YES;
                break;
            }
        }
    }

    if (failed) {
        // Put the snapshot back so a failed restore leaves the device exactly
        // as it was before the attempt.
        for (NSDictionary *snapshot in [snapshots reverseObjectEnumerator]) {
            NSString *target = snapshot[@"target"];
            NSString *snapshotPath = snapshot[@"snapshot"];
            NSString *parent = target.stringByDeletingLastPathComponent;
            FFSandboxPerformWithGrant(parent, YES, ^NSError * {
                NSError *error = nil;
                FFSafeCopyFile(snapshotPath, target, &error);
                return error;
            }, NULL);
        }
        [[NSFileManager defaultManager] removeItemAtPath:recoveryDirectory error:NULL];
        if (error) *error = restoreError;
        return NO;
    }

    // ---- drop directories created by the apply when empty ------------------
    for (NSString *relative in [createdDirectories reverseObjectEnumerator]) {
        NSString *absolute = [container stringByAppendingPathComponent:relative];
        BOOL isDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:absolute isDirectory:&isDirectory]) continue;
        if (!isDirectory) continue;
        NSArray<NSString *> *contents = [[NSFileManager defaultManager]
            contentsOfDirectoryAtPath:absolute error:NULL];
        if (contents.count == 0) {
            [[NSFileManager defaultManager] removeItemAtPath:absolute error:NULL];
        }
    }
    [[NSFileManager defaultManager] removeItemAtPath:recoveryDirectory error:NULL];

    // ---- commit the restore ------------------------------------------------
    NSMutableDictionary *mutableJournal = [journal mutableCopy];
    mutableJournal[FFJournalStatusKey] = FFJournalStatusRestored;
    FFWritePlist(mutableJournal, receipt.journalPath, NULL);

    NSDictionary *updatedReceipt = @{
        @"functionID": function.funcID,
        @"gameID": game.gameID,
        @"bundleID": game.bundleID,
        @"journalPath": receipt.journalPath,
        @"status": FFJournalStatusRestored,
        @"fileCount": @(records.count),
        @"appliedAt": [NSDate date],
    };
    FFWritePlist(updatedReceipt, [self receiptPathForFunction:function game:game], NULL);

    FFLog(@"restore: %@ ← %@ OK (%lu arquivos)",
          function.name, game.displayName, (unsigned long)records.count);
    return YES;
    } @finally {
        [operationLock unlock];
    }
}

- (BOOL)restoreAllWithError:(NSError **)error restoredCount:(NSUInteger *)restoredCount {
    NSRecursiveLock *operationLock = FFPatchEngineOperationLock();
    [operationLock lock];
    @try {
    NSUInteger count = 0;
    for (FFPatchReceipt *receipt in [self allReceipts]) {
        if (![receipt.status isEqualToString:FFJournalStatusApplied]) continue;
        NSString *gameID = receipt.gameID;
        NSString *functionID = receipt.functionID;
        if (gameID.length == 0 || functionID.length == 0) continue;
        for (FFGame *game in self.manifest.games) {
            if (![game.gameID isEqualToString:gameID]) continue;
            for (FFGroup *group in self.manifest.groups) {
                for (FFFunction *function in group.functions) {
                    if (![function.funcID isEqualToString:functionID]) continue;
                    if ([self restoreFunction:function game:game error:error]) count++;
                }
            }
        }
    }
    if (restoredCount) *restoredCount = count;
    return YES;
    } @finally {
        [operationLock unlock];
    }
}

- (BOOL)restoreAllForGame:(FFGame *)game error:(NSError **)error restoredCount:(NSUInteger *)restoredCount {
    NSRecursiveLock *operationLock = FFPatchEngineOperationLock();
    [operationLock lock];
    @try {
    NSUInteger count = 0;
    for (NSString *functionID in [self appliedFunctionIDsForGame:game]) {
        for (FFGroup *group in self.manifest.groups) {
            for (FFFunction *function in group.functions) {
                if (![function.funcID isEqualToString:functionID]) continue;
                if ([self restoreFunction:function game:game error:error]) count++;
            }
        }
    }
    if (restoredCount) *restoredCount = count;
    return YES;
    } @finally {
        [operationLock unlock];
    }
}

@end
