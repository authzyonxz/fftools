//
//  FFManifest.h
//  FFPatch — payload manifest and function catalogue.
//
//  Raw-container payload layout (no .3105 packages anywhere):
//
//    Resources/Payloads/manifest.json
//    Resources/Payloads/<payloadDirectory>/<gameID>/<caminho relativo ao container>
//
//  Example: Resources/Payloads/hs_alto/freefireth/Documents/cfg/aim.bin
//           → <container de com.dts.freefireth>/Documents/cfg/aim.bin
//
//  The payload tree mirrors the container 1:1. Whatever bytes the mod ships are
//  copied; the engine never interprets them.
//

#ifndef FF_MANIFEST_H
#define FF_MANIFEST_H

#import <Foundation/Foundation.h>
#import "FFContainerStore.h"

NS_ASSUME_NONNULL_BEGIN

@class FFGroup;
@class FFFunction;

@interface FFGame : NSObject
@property (nonatomic, copy) NSString *gameID;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *iconName;
/*! "data" (default) or "bundle". */
@property (nonatomic, copy) NSString *rootKind;
@property (nonatomic, assign) FFContainerKind containerKind;
+ (nullable instancetype)gameFromDictionary:(NSDictionary *)dictionary error:(NSError **)error;
@end

/*! How a payload file finds its target inside the container.
 *
 *  path         → the payload tree mirrors the container (exact relative path).
 *  name         → the engine scans the container and replaces every file whose
 *                 name matches; zero matches is an error.
 *  path-or-name → exact path if that file already exists, otherwise scan by
 *                 name, otherwise create the exact path (marker/pipeline mode).
 */
typedef NS_ENUM(NSInteger, FFLocateMode) {
    FFLocateModePath = 0,
    FFLocateModeName = 1,
    FFLocateModePathOrName = 2,
};

@interface FFFunction : NSObject
@property (nonatomic, copy) NSString *funcID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *payloadDirectory;
@property (nonatomic, weak, nullable) FFGroup *group;

@property (nonatomic, assign) FFLocateMode locateMode;
/*! File names to search for. Empty = use the payload file names. */
@property (nonatomic, copy, nullable) NSArray<NSString *> *locateNames;
/*! Container-relative roots to scan (e.g. Documents, Library). Empty = whole container. */
@property (nonatomic, copy, nullable) NSArray<NSString *> *locateRoots;
/*! Hard cap on replaced files per payload file (default 8). */
@property (nonatomic, assign) NSUInteger locateMaxMatches;
@end

@interface FFGroup : NSObject
@property (nonatomic, copy) NSString *groupID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) BOOL exclusive;
@property (nonatomic, strong) NSArray<FFFunction *> *functions;
@end

@interface FFManifest : NSObject

@property (nonatomic, strong) NSArray<FFGame *> *games;
@property (nonatomic, strong) NSArray<FFGroup *> *groups;
@property (nonatomic, copy) NSString *payloadRoot;

+ (nullable instancetype)loadFromBundle:(nullable NSBundle *)bundle
                                  error:(NSError *_Nullable *_Nullable)error;

- (nullable FFGame *)gameWithID:(NSString *)gameID;
- (nullable FFFunction *)functionWithID:(NSString *)funcID;
- (nullable FFGroup *)groupForFunction:(FFFunction *)function;
- (NSArray<FFFunction *> *)functionsInGroup:(FFGroup *)group;
- (NSArray<FFFunction *> *)siblingsOfFunction:(FFFunction *)function;

/*! Absolute paths of every payload file for (function, game). Empty when the
    payload directory does not exist. `relativePaths` receives the
    container-relative paths in the same order. */
- (NSArray<NSString *> *)payloadFilesForFunction:(FFFunction *)function
                                            game:(FFGame *)game
                                     relativePaths:(NSArray<NSString *> *_Nullable *_Nullable)relativePaths
                                            error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END

#endif /* FF_MANIFEST_H */
