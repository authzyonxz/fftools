//
//  FFManifest.m
//  FFPatch
//

#import "FFManifest.h"
#import "FFCore.h"
#import "FFContainerStore.h"

@implementation FFGame

+ (instancetype)gameFromDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        if (error) *error = FFMakeError(FFErrorInvalidPayload, @"jogo inválido no manifest");
        return nil;
    }
    NSString *gameID = dictionary[@"id"];
    NSString *displayName = dictionary[@"name"];
    NSString *bundleID = dictionary[@"bundle"];
    if (gameID.length == 0 || displayName.length == 0 || bundleID.length == 0) {
        if (error) *error = FFMakeError(FFErrorInvalidPayload,
                                        @"jogo sem id/name/bundle no manifest");
        return nil;
    }
    FFGame *game = [FFGame new];
    game.gameID = gameID;
    game.displayName = displayName;
    game.bundleID = bundleID;
    game.iconName = dictionary[@"icon"] ?: @"ff_normal";
    NSString *rootKind = dictionary[@"root"] ?: @"data";
    game.rootKind = [rootKind isEqualToString:@"bundle"] ? @"bundle" : @"data";
    game.containerKind = [game.rootKind isEqualToString:@"bundle"]
        ? FFContainerKindBundle : FFContainerKindData;
    return game;
}

@end

@implementation FFFunction
@end

@implementation FFGroup
@end

@implementation FFManifest

+ (instancetype)loadFromBundle:(NSBundle *)bundle error:(NSError **)error {
    NSBundle *hostBundle = bundle ?: [NSBundle mainBundle];
    NSString *root = [hostBundle.bundlePath stringByAppendingPathComponent:@"Payloads"];
    NSString *manifestPath = [root stringByAppendingPathComponent:@"manifest.json"];

    NSData *data = [NSData dataWithContentsOfFile:manifestPath];
    if (data.length == 0) {
        if (error) *error = FFMakeError(FFErrorPayloadMissing,
                                        @"manifest não encontrado em %@", manifestPath);
        return nil;
    }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) *error = FFMakeError(FFErrorInvalidPayload, @"manifest.json inválido");
        return nil;
    }
    return [self manifestFromDictionary:json payloadRoot:root error:error];
}

+ (void)applyLocateDictionary:(id)rawLocate toFunction:(FFFunction *)function {
    function.locateMode = FFLocateModePath;
    function.locateMaxMatches = 8;

    NSDictionary *locate = nil;
    if ([rawLocate isKindOfClass:[NSString class]]) {
        locate = @{@"mode": rawLocate};
    } else if ([rawLocate isKindOfClass:[NSDictionary class]]) {
        locate = rawLocate;
    }
    if (locate == nil) return;

    NSString *mode = [locate[@"mode"] isKindOfClass:[NSString class]] ? locate[@"mode"] : @"path";
    if ([mode isEqualToString:@"name"]) {
        function.locateMode = FFLocateModeName;
    } else if ([mode isEqualToString:@"path-or-name"]) {
        function.locateMode = FFLocateModePathOrName;
    } else {
        function.locateMode = FFLocateModePath;
    }

    NSArray *names = locate[@"names"];
    if ([names isKindOfClass:[NSArray class]]) {
        NSMutableArray<NSString *> *clean = [NSMutableArray array];
        for (id entry in names) {
            if (![entry isKindOfClass:[NSString class]]) continue;
            NSString *name = (NSString *)entry;
            if (name.length == 0 || [name containsString:@"/"]) continue;
            [clean addObject:name];
        }
        function.locateNames = clean;
    }

    NSArray *roots = locate[@"roots"];
    if ([roots isKindOfClass:[NSArray class]]) {
        NSMutableArray<NSString *> *clean = [NSMutableArray array];
        for (id entry in roots) {
            if (![entry isKindOfClass:[NSString class]]) continue;
            NSString *root = (NSString *)entry;
            if (!FFRelativePathIsSafe(root)) continue;
            [clean addObject:root];
        }
        function.locateRoots = clean;
    }

    NSNumber *maxMatches = [locate[@"maxMatches"] isKindOfClass:[NSNumber class]]
        ? locate[@"maxMatches"] : nil;
    if (maxMatches != nil) {
        NSInteger value = maxMatches.integerValue;
        if (value > 0) function.locateMaxMatches = (NSUInteger)MIN(value, 64);
    }
}
+ (instancetype)emptyManifest {
    NSMutableArray<FFGame *> *games = [NSMutableArray array];
    for (NSDictionary *entry in @[
        @{@"id": @"freefireth", @"name": @"Free Fire Normal",
          @"bundle": @"com.dts.freefireth", @"icon": @"ic_game_normal", @"root": @"data"},
        @{@"id": @"freefiremax", @"name": @"Free Fire Max",
          @"bundle": @"com.dts.freefiremax", @"icon": @"ic_game_max", @"root": @"data"},
    ]) {
        FFGame *game = [FFGame gameFromDictionary:entry error:NULL];
        if (game != nil) [games addObject:game];
    }
    FFManifest *manifest = [FFManifest new];
    manifest.games = games;
    manifest.groups = @[];
    manifest.payloadRoot = @"";
    return manifest;
}

+ (instancetype)manifestFromDictionary:(NSDictionary *)dictionary
                           payloadRoot:(NSString *)payloadRoot
                                 error:(NSError **)error {
    FFManifest *manifest = [FFManifest new];
    manifest.payloadRoot = payloadRoot;

    NSMutableArray<FFGame *> *games = [NSMutableArray array];
    for (NSDictionary *entry in dictionary[@"games"] ?: @[]) {
        FFGame *game = [FFGame gameFromDictionary:entry error:error];
        if (game == nil) return nil;
        [games addObject:game];
    }
    if (games.count == 0) {
        if (error) *error = FFMakeError(FFErrorInvalidPayload, @"manifest sem jogos");
        return nil;
    }
    manifest.games = games;

    NSMutableArray<FFGroup *> *groups = [NSMutableArray array];
    NSMutableSet<NSString *> *seenIDs = [NSMutableSet set];
    for (NSDictionary *entry in dictionary[@"groups"] ?: @[]) {
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        FFGroup *group = [FFGroup new];
        group.groupID = entry[@"id"] ?: @"";
        group.title = entry[@"title"] ?: @"";
        group.exclusive = [entry[@"exclusive"] boolValue];
        NSMutableArray<FFFunction *> *functions = [NSMutableArray array];
        for (NSDictionary *rawFunction in entry[@"functions"] ?: @[]) {
            if (![rawFunction isKindOfClass:[NSDictionary class]]) continue;
            FFFunction *function = [FFFunction new];
            function.funcID = rawFunction[@"id"] ?: @"";
            function.name = rawFunction[@"name"] ?: @"";
            function.subtitle = rawFunction[@"subtitle"] ?: @"";
            function.payloadDirectory = rawFunction[@"payload"] ?: function.funcID;
            [self applyLocateDictionary:rawFunction[@"locate"] toFunction:function];

            NSArray *games = rawFunction[@"games"];
            if ([games isKindOfClass:[NSArray class]]) {
                NSMutableArray<NSString *> *supported = [NSMutableArray array];
                for (id entry in games) {
                    if ([entry isKindOfClass:[NSString class]] && [entry length] > 0) {
                        [supported addObject:entry];
                    }
                }
                function.supportedGames = supported;
            }
            NSString *status = rawFunction[@"status"];
            function.publicationStatus = [status isKindOfClass:[NSString class]] && status.length
                ? status : @"active";
            if (function.funcID.length == 0 || function.name.length == 0) continue;
            if ([seenIDs containsObject:function.funcID]) {
                if (error) *error = FFMakeError(FFErrorInvalidPayload,
                                                @"id de função duplicado: %@", function.funcID);
                return nil;
            }
            [seenIDs addObject:function.funcID];
            function.group = group;
            [functions addObject:function];
        }
        group.functions = functions;
        if (group.groupID.length && functions.count) [groups addObject:group];
    }
    if (groups.count == 0) {
        if (error) *error = FFMakeError(FFErrorInvalidPayload, @"manifest sem funções");
        return nil;
    }
    manifest.groups = groups;
    return manifest;
}

- (FFGame *)gameWithID:(NSString *)gameID {
    for (FFGame *game in self.games) {
        if ([game.gameID isEqualToString:gameID]) return game;
    }
    return nil;
}

- (FFFunction *)functionWithID:(NSString *)funcID {
    for (FFGroup *group in self.groups) {
        for (FFFunction *function in group.functions) {
            if ([function.funcID isEqualToString:funcID]) return function;
        }
    }
    return nil;
}

- (FFGroup *)groupForFunction:(FFFunction *)function {
    for (FFGroup *group in self.groups) {
        if ([group.functions containsObject:function]) return group;
    }
    return nil;
}

- (NSArray<FFFunction *> *)functionsInGroup:(FFGroup *)group {
    return group.functions ?: @[];
}

- (NSArray<FFFunction *> *)siblingsOfFunction:(FFFunction *)function {
    FFGroup *group = [self groupForFunction:function];
    if (group == nil) return @[];
    NSMutableArray<FFFunction *> *siblings = [NSMutableArray array];
    for (FFFunction *candidate in group.functions) {
        if (candidate != function) [siblings addObject:candidate];
    }
    return siblings;
}

- (NSArray<NSString *> *)payloadFilesForFunction:(FFFunction *)function
                                            game:(FFGame *)game
                                   relativePaths:(NSArray<NSString *> **)relativePaths
                                            error:(NSError **)error {
    NSString *directory = [self.payloadRoot
        stringByAppendingPathComponent:function.payloadDirectory ?: function.funcID];
    directory = [directory stringByAppendingPathComponent:game.gameID];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:directory isDirectory:&isDirectory] || !isDirectory) {
        if (error) {
            *error = FFMakeError(FFErrorPayloadMissing,
                                 @"payload ausente: %@/%@ para %@",
                                 function.payloadDirectory, game.gameID, function.name);
        }
        return @[];
    }

    NSMutableArray<NSString *> *files = [NSMutableArray array];
    NSMutableArray<NSString *> *relatives = [NSMutableArray array];
    [self walkDirectory:directory
              prefixPath:@""
                onFile:^(NSString *absolute, NSString *relative) {
        [files addObject:absolute];
        [relatives addObject:relative];
    }];
    if (relativePaths) *relativePaths = relatives;
    return files;
}

- (void)walkDirectory:(NSString *)directory
           prefixPath:(NSString *)prefix
               onFile:(void (^)(NSString *absolute, NSString *relative))onFile {
    NSArray<NSString *> *entries = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:directory error:NULL];
    for (NSString *entry in [entries sortedArrayUsingSelector:@selector(compare:)]) {
        if ([entry hasPrefix:@"."]) continue;
        NSString *absolute = [directory stringByAppendingPathComponent:entry];
        NSString *relative = prefix.length ? [prefix stringByAppendingPathComponent:entry] : entry;
        NSDictionary *attributes = [[NSFileManager defaultManager]
            attributesOfItemAtPath:absolute error:NULL];
        NSString *type = attributes[NSFileType];
        if ([type isEqualToString:NSFileTypeDirectory]) {
            [self walkDirectory:absolute prefixPath:relative onFile:onFile];
        } else if ([type isEqualToString:NSFileTypeRegular]) {
            onFile(absolute, relative);
        }
        // Symlinks inside a payload are ignored on purpose: they would let a
        // package point a target somewhere outside the container.
    }
}

@end
