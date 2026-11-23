//
//  FFPatchEngine.h
//  FFPatch — transactional raw-container file substitution.
//
//  Ported from the 3106 patch transaction (PatchTransaction.swift) to
//  Objective-C. What changed: instead of .3105 patch packages with rules, the
//  unit is a raw payload tree that mirrors the target container — one byte
//  blob per target file, copied in and restored from a verified backup.
//
//  Apply:
//    1. resolve container of the game bundle id
//    2. back up every existing target (SHA-256 recorded) into a transaction dir
//    3. write a prepared journal
//    4. write every payload file through a staging file + rename, verifying the
//       SHA-256 of what landed on disk
//    5. mark the journal applied and drop a receipt
//  Any failure rolls the transaction back to the exact prior bytes.
//
//  Restore:
//    verifies the container fingerprint and every backup digest, snapshots the
//    current bytes (so a failed restore cannot lose data), puts the originals
//    back, deletes files that did not exist before, removes created dirs.
//

#ifndef FF_PATCH_ENGINE_H
#define FF_PATCH_ENGINE_H

#import <Foundation/Foundation.h>
#import "FFManifest.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FFFunctionState) {
    FFFunctionStateIdle    = 0,
    FFFunctionStateApplied = 1,
};

@interface FFPatchReceipt : NSObject
@property (nonatomic, copy) NSString *functionID;
@property (nonatomic, copy) NSString *gameID;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *journalPath;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, assign) NSUInteger fileCount;
@property (nonatomic, strong, nullable) NSDate *appliedAt;
@end

/*! What one apply actually did — fed to the STATUS alert and the log. */
@interface FFPatchApplyStats : NSObject
@property (nonatomic, assign) NSUInteger fileCount;
@property (nonatomic, assign) BOOL usedContainerSearch;
@property (nonatomic, assign) NSUInteger scannedEntries;
@property (nonatomic, copy, nullable) NSString *searchSummary;
@end

@interface FFPatchEngine : NSObject

@property (nonatomic, strong, nullable) FFManifest *manifest;

+ (instancetype)sharedEngine;

/*! Number of files a function would touch for the given game (0 = payload
    missing). Cheap: it does not resolve the container. */
- (NSUInteger)payloadFileCountForFunction:(FFFunction *)function game:(FFGame *)game;

- (FFFunctionState)stateForFunction:(FFFunction *)function game:(FFGame *)game;
- (nullable FFPatchReceipt *)receiptForFunction:(FFFunction *)function game:(FFGame *)game;
- (NSArray<NSString *> *)appliedFunctionIDsForGame:(FFGame *)game;
- (NSArray<NSString *> *)gamesWhereFunctionIsApplied:(FFFunction *)function;

/*! Applies one function to one game. Rolls back on any failure. */
- (BOOL)applyFunction:(FFFunction *)function
                 game:(FFGame *)game
                error:(NSError *_Nullable *_Nullable)error;

/*! Same, and reports whether the container had to be scanned by file name. */
- (BOOL)applyFunction:(FFFunction *)function
                 game:(FFGame *)game
                stats:(FFPatchApplyStats *_Nullable *_Nullable)stats
                error:(NSError *_Nullable *_Nullable)error;

/*! Container scan used by locate=name / path-or-name. Returns container-relative
    paths of every regular file named `fileName` (case-insensitive), capped at
    `maxMatches`, skipping caches. */
- (NSArray<NSString *> *)searchContainer:(NSString *)container
                                fileName:(NSString *)fileName
                                   roots:(NSArray<NSString *> *_Nullable)roots
                              maxMatches:(NSUInteger)maxMatches
                              scannedOut:(NSUInteger *_Nullable)scannedOut;

/*! Restores one function on one game to the pre-apply bytes. */
- (BOOL)restoreFunction:(FFFunction *)function
                   game:(FFGame *)game
                  error:(NSError *_Nullable *_Nullable)error;

/*! Restores every applied function on every game. */
- (BOOL)restoreAllWithError:(NSError *_Nullable *_Nullable)error
             restoredCount:(NSUInteger *_Nullable)restoredCount;

/*! Restores every applied function of one game (used when switching payloads). */
- (BOOL)restoreAllForGame:(FFGame *)game
                    error:(NSError *_Nullable *_Nullable)error
            restoredCount:(NSUInteger *_Nullable)restoredCount;

- (NSArray<FFPatchReceipt *> *)allReceipts;

@end

NS_ASSUME_NONNULL_END

#endif /* FF_PATCH_ENGINE_H */
