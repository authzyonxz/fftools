

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

@interface FFPatchApplyStats : NSObject
@property (nonatomic, assign) NSUInteger fileCount;
@property (nonatomic, assign) BOOL usedContainerSearch;
@property (nonatomic, assign) NSUInteger scannedEntries;
@property (nonatomic, copy, nullable) NSString *searchSummary;
@end

@interface FFPatchEngine : NSObject

@property (nonatomic, strong, nullable) FFManifest *manifest;

+ (instancetype)sharedEngine;

- (NSUInteger)payloadFileCountForFunction:(FFFunction *)function game:(FFGame *)game;

- (FFFunctionState)stateForFunction:(FFFunction *)function game:(FFGame *)game;
- (nullable FFPatchReceipt *)receiptForFunction:(FFFunction *)function game:(FFGame *)game;
- (NSArray<NSString *> *)appliedFunctionIDsForGame:(FFGame *)game;
- (NSArray<NSString *> *)gamesWhereFunctionIsApplied:(FFFunction *)function;

- (BOOL)applyFunction:(FFFunction *)function
                 game:(FFGame *)game
                error:(NSError *_Nullable *_Nullable)error;

- (BOOL)applyFunction:(FFFunction *)function
                 game:(FFGame *)game
                stats:(FFPatchApplyStats *_Nullable *_Nullable)stats
                error:(NSError *_Nullable *_Nullable)error;

- (NSArray<NSString *> *)searchContainer:(NSString *)container
                                fileName:(NSString *)fileName
                                   roots:(NSArray<NSString *> *_Nullable)roots
                              maxMatches:(NSUInteger)maxMatches
                              scannedOut:(NSUInteger *_Nullable)scannedOut;

- (BOOL)restoreFunction:(FFFunction *)function
                   game:(FFGame *)game
                  error:(NSError *_Nullable *_Nullable)error;

- (BOOL)restoreAllWithError:(NSError *_Nullable *_Nullable)error
             restoredCount:(NSUInteger *_Nullable)restoredCount;

- (BOOL)restoreAllForGame:(FFGame *)game
                    error:(NSError *_Nullable *_Nullable)error
            restoredCount:(NSUInteger *_Nullable)restoredCount;

- (NSArray<FFPatchReceipt *> *)allReceipts;

@end

NS_ASSUME_NONNULL_END

#endif
