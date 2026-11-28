

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

@property (nonatomic, copy) NSString *rootKind;
@property (nonatomic, assign) FFContainerKind containerKind;
+ (nullable instancetype)gameFromDictionary:(NSDictionary *)dictionary error:(NSError **)error;
@end

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

@property (nonatomic, copy, nullable) NSArray<NSString *> *locateNames;

@property (nonatomic, copy, nullable) NSArray<NSString *> *locateRoots;

@property (nonatomic, assign) NSUInteger locateMaxMatches;

@property (nonatomic, copy) NSArray<NSString *> *supportedGames;

@property (nonatomic, copy) NSString *publicationStatus;
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

+ (nullable instancetype)manifestFromDictionary:(NSDictionary *)dictionary
                                    payloadRoot:(NSString *)payloadRoot
                                          error:(NSError *_Nullable *_Nullable)error;

+ (instancetype)emptyManifest;

- (nullable FFGame *)gameWithID:(NSString *)gameID;
- (nullable FFFunction *)functionWithID:(NSString *)funcID;
- (nullable FFGroup *)groupForFunction:(FFFunction *)function;
- (NSArray<FFFunction *> *)functionsInGroup:(FFGroup *)group;
- (NSArray<FFFunction *> *)siblingsOfFunction:(FFFunction *)function;

- (NSArray<NSString *> *)payloadFilesForFunction:(FFFunction *)function
                                            game:(FFGame *)game
                                     relativePaths:(NSArray<NSString *> *_Nullable *_Nullable)relativePaths
                                            error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END

#endif
