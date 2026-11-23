//
//  FFCore.m
//  FFPatch
//

#import "FFCore.h"

#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <unistd.h>
#import <fcntl.h>
#import <errno.h>
#import <string.h>

NSString *const FFErrorDomain = @"com.daddy.ffpatch.error";

NSError *FFMakeError(FFErrorCode code, NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    return [NSError errorWithDomain:FFErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"erro desconhecido"}];
}

NSString *FFUserMessageForError(NSError *error) {
    if (error == nil) return @"Erro desconhecido";
    if (![error.domain isEqualToString:FFErrorDomain]) {
        if ([error.domain isEqualToString:NSPOSIXErrorDomain]) return @"Sem permissão no aparelho";
        return @"Falha inesperada";
    }
    switch ((FFErrorCode)error.code) {
        case FFErrorUnsupportedOS:       return @"Sistema não suportado";
        case FFErrorNoSandboxAccess:     return @"Sem permissão de acesso";
        case FFErrorAppNotFound:         return @"Jogo não instalado";
        case FFErrorPayloadMissing:      return @"Arquivo da função indisponível";
        case FFErrorInvalidPayload:      return @"Arquivo da função inválido";
        case FFErrorPathEscapesContainer:return @"Caminho inválido";
        case FFErrorSymlinkRefused:      return @"Arquivo protegido por link";
        case FFErrorAlreadyApplied:      return @"Função já está ativa";
        case FFErrorNotApplied:          return @"Função não está ativa";
        case FFErrorApplyFailed:         return @"Não foi possível aplicar";
        case FFErrorRestoreFailed:       return @"Não foi possível restaurar";
        case FFErrorVerifyFailed:        return @"Verificação falhou";
        case FFErrorBackupMissing:       return @"Backup não encontrado";
        case FFErrorContainerChanged:    return @"Reinstale o jogo para continuar";
        case FFErrorTargetIsDirectory:   return @"Alvo inválido";
        case FFErrorDuplicateTarget:     return @"Arquivo duplicado";
        case FFErrorTargetNotFound:      return @"Arquivo não encontrado no jogo";
        default:                         return @"Falha na operação";
    }
}

#pragma mark - Logging

static NSString *FFLogFile(void) {
    static NSString *path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *root = FFPatchRootDirectory();
        path = [root stringByAppendingPathComponent:@"ffpatch.log"];
    });
    return path;
}

NSString *FFLogFilePath(void) {
    return FFLogFile();
}

void FFLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    if (line.length == 0) return;

    NSLog(@"[ffpatch] %@", line);

    static NSLock *lock;
    static BOOL ready;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSLock new];
    });
    [lock lock];
    if (!ready) {
        [[NSFileManager defaultManager] createDirectoryAtPath:
            [FFPatchRootDirectory() stringByAppendingPathComponent:@"Logs"]
                                  withIntermediateDirectories:YES attributes:nil error:NULL];
        ready = YES;
    }
    NSString *stamp = [[NSISO8601DateFormatter new] stringFromDate:[NSDate date]];
    NSString *record = [NSString stringWithFormat:@"%@ %@\n", stamp ?: @"", line];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:FFLogFile()];
    if (handle == nil) {
        [record writeToFile:FFLogFile() atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    } else {
        @try {
            [handle seekToEndOfFile];
            [handle writeData:[record dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];
        } @catch (__unused NSException *exception) {
        }
    }
    [lock unlock];
}

#pragma mark - OS / device

static NSString *FFSysctlString(const char *name) {
    size_t size = 0;
    if (sysctlbyname(name, NULL, &size, NULL, 0) != 0 || size == 0) return nil;
    char *buffer = calloc(1, size);
    if (buffer == NULL) return nil;
    NSString *value = nil;
    if (sysctlbyname(name, buffer, &size, NULL, 0) == 0) {
        value = [NSString stringWithUTF8String:buffer];
    }
    free(buffer);
    return value;
}

int FFOSMajorNumber(void) {
    return (int)[[NSProcessInfo processInfo] operatingSystemVersion].majorVersion;
}

int FFOSMinorNumber(void) {
    return (int)[[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
}

int FFOSPatchNumber(void) {
    return (int)[[NSProcessInfo processInfo] operatingSystemVersion].patchVersion;
}

NSString *FFOSVersionString(void) {
    return [[NSProcessInfo processInfo] operatingSystemVersionString] ?: @"?";
}

NSString *FFOSBuildString(void) {
    static NSString *build;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        build = FFSysctlString("kern.osversion") ?: @"";
    });
    return build;
}

NSString *FFDeviceModelIdentifier(void) {
    static NSString *model;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname info;
        if (uname(&info) == 0) {
            model = [NSString stringWithUTF8String:info.machine];
        }
        if (model.length == 0) model = FFSysctlString("hw.machine") ?: @"?";
    });
    return model;
}

BOOL FFDeviceIsA10(void) {
    static NSArray<NSString *> *a10Identifiers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        a10Identifiers = @[
            // A10 Fusion
            @"iPhone9,1", @"iPhone9,3", @"iPhone9,4",
            @"iPad7,1", @"iPad7,2", @"iPad7,3", @"iPad7,4",
            @"iPad7,5", @"iPad7,6", @"iPad7,11", @"iPad7,12",
            @"iPod9,1"
        ];
    });
    NSString *model = FFDeviceModelIdentifier();
    if (model.length == 0) return NO;
    return [a10Identifiers containsObject:model];
}

#pragma mark - Digests

NSString *FFSHA256HexOfData(NSData *data) {
    if (data == nil) return nil;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        [hex appendFormat:@"%02x", digest[index]];
    }
    return hex;
}

NSString *FFSHA256HexOfFile(NSString *path, NSError **error) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (handle == nil) {
        if (error) *error = FFMakeError(FFErrorVerifyFailed, @"não abriu %@", path.lastPathComponent);
        return nil;
    }
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    while (1) {
        NSData *chunk = nil;
        @try {
            chunk = [handle readDataOfLength:1024 * 1024];
        } @catch (__unused NSException *exception) {
            chunk = nil;
        }
        if (chunk.length == 0) break;
        CC_SHA256_Update(&context, chunk.bytes, (CC_LONG)chunk.length);
        if (chunk.length < 1024 * 1024) break;
    }
    @try { [handle closeFile]; } @catch (__unused NSException *exception) {}
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        [hex appendFormat:@"%02x", digest[index]];
    }
    return hex;
}

#pragma mark - Safe IO

static NSDictionary *FFExistingAttributes(NSString *path) {
    return [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL] ?: @{};
}

static NSString *FFStagingPathFor(NSString *target, NSString *tag) {
    NSString *directory = [target stringByDeletingLastPathComponent];
    NSString *name = [NSString stringWithFormat:@".ffpatch-%@-%@", tag, NSUUID.UUID.UUIDString];
    return [directory stringByAppendingPathComponent:name];
}

BOOL FFSafeWriteFile(NSString *path, NSData *data, NSError **error) {
    if (path.length == 0 || data == nil) {
        if (error) *error = FFMakeError(FFErrorApplyFailed, @"destino inválido");
        return NO;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *directory = [path stringByDeletingLastPathComponent];
    if (![fileManager fileExistsAtPath:directory]) {
        if (![fileManager createDirectoryAtPath:directory
                     withIntermediateDirectories:YES
                                      attributes:nil
                                           error:error]) {
            return NO;
        }
    }

    NSDictionary *attributeSource = FFExistingAttributes(path);
    NSNumber *permissions = attributeSource[NSFilePosixPermissions];
    NSString *protection = attributeSource[NSFileProtectionKey];

    NSString *staging = FFStagingPathFor(path, @"write");
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    if (permissions != nil) attributes[NSFilePosixPermissions] = permissions;
    if (protection != nil) attributes[NSFileProtectionKey] = protection;

    if (![fileManager createFileAtPath:staging contents:data attributes:attributes.count ? attributes : nil]) {
        if (error) *error = FFMakeError(FFErrorApplyFailed, @"não criou arquivo temporário");
        return NO;
    }

    int descriptor = open(staging.fileSystemRepresentation, O_RDONLY);
    if (descriptor >= 0) {
        if (permissions != nil) {
            mode_t mode = (mode_t)permissions.unsignedIntValue;
            fchmod(descriptor, mode);
        }
        fsync(descriptor);
        close(descriptor);
    }

    if (rename(staging.fileSystemRepresentation, path.fileSystemRepresentation) != 0) {
        int saved = errno;
        [fileManager removeItemAtPath:staging error:NULL];
        if (error) {
            *error = FFMakeError(FFErrorApplyFailed, @"rename falhou (%d: %s)",
                                 saved, strerror(saved));
        }
        return NO;
    }
    return YES;
}

BOOL FFSafeCopyFile(NSString *source, NSString *path, NSError **error) {
    NSString *staging = FFStagingPathFor(path, @"copy");
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager copyItemAtPath:source toPath:staging error:error]) {
        [fileManager removeItemAtPath:staging error:NULL];
        return NO;
    }
    NSDictionary *attributeSource = FFExistingAttributes(path);
    NSNumber *permissions = attributeSource[NSFilePosixPermissions];
    if (permissions != nil) {
        [fileManager setAttributes:@{NSFilePosixPermissions: permissions}
                      ofItemAtPath:staging
                             error:NULL];
    }
    int descriptor = open(staging.fileSystemRepresentation, O_RDONLY);
    if (descriptor >= 0) {
        fsync(descriptor);
        close(descriptor);
    }
    if (rename(staging.fileSystemRepresentation, path.fileSystemRepresentation) != 0) {
        int saved = errno;
        [fileManager removeItemAtPath:staging error:NULL];
        if (error) {
            *error = FFMakeError(FFErrorRestoreFailed, @"rename falhou (%d: %s)",
                                 saved, strerror(saved));
        }
        return NO;
    }
    return YES;
}

#pragma mark - Path hygiene

BOOL FFRelativePathIsSafe(NSString *relativePath) {
    if (relativePath.length == 0) return NO;
    if ([relativePath hasPrefix:@"/"]) return NO;
    NSArray<NSString *> *components = [relativePath componentsSeparatedByString:@"/"];
    for (NSString *component in components) {
        if (component.length == 0) return NO;
        if ([component isEqualToString:@"."] || [component isEqualToString:@".."]) return NO;
    }
    return YES;
}

NSString *FFResolveContainedPath(NSString *root, NSString *relativePath, NSError **error) {
    if (root.length == 0) {
        if (error) *error = FFMakeError(FFErrorInvalidPayload, @"raiz do container vazia");
        return nil;
    }
    if (!FFRelativePathIsSafe(relativePath)) {
        if (error) *error = FFMakeError(FFErrorPathEscapesContainer,
                                        @"caminho inseguro: %@", relativePath);
        return nil;
    }
    NSString *rootCanonical = [root hasSuffix:@"/"] ? root : [root stringByAppendingString:@"/"];
    NSString *target = [rootCanonical stringByAppendingString:relativePath];
    NSString *targetCanonical = [target stringByResolvingSymlinksInPath];
    NSString *rootResolved = [root stringByResolvingSymlinksInPath];
    if (![targetCanonical hasPrefix:rootResolved]) {
        if (error) *error = FFMakeError(FFErrorPathEscapesContainer,
                                        @"saiu do container: %@", relativePath);
        return nil;
    }
    return target;
}

BOOL FFPathContainsSymlink(NSString *root, NSString *relativePath) {
    NSArray<NSString *> *components = [relativePath componentsSeparatedByString:@"/"];
    NSString *cursor = root;
    for (NSString *component in components) {
        cursor = [cursor stringByAppendingPathComponent:component];
        NSDictionary *attributes = [[NSFileManager defaultManager]
            attributesOfItemAtPath:cursor error:NULL];
        if (attributes == nil) {
            // Missing component: nothing else to inspect, the caller may create it.
            return NO;
        }
        if ([attributes[NSFileType] isEqualToString:NSFileTypeSymbolicLink]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Plists

NSDictionary *FFReadPlist(NSString *path) {
    if (path.length == 0) return nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) return nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListImmutable
                                                          format:NULL
                                                           error:NULL];
    return [plist isKindOfClass:[NSDictionary class]] ? plist : nil;
}

BOOL FFWritePlist(NSDictionary *plist, NSString *path, NSError **error) {
    if (plist == nil || path.length == 0) {
        if (error) *error = FFMakeError(FFErrorInvalidPayload, @"plist inválido");
        return NO;
    }
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:error];
    if (data == nil) return NO;
    return FFSafeWriteFile(path, data, error);
}

#pragma mark - Own container root

NSString *FFPatchRootDirectory(void) {
    static NSString *root;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray<NSString *> *library = NSSearchPathForDirectoriesInDomains(
            NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *base = library.firstObject ?: NSTemporaryDirectory();
        root = [base stringByAppendingPathComponent:@"Application Support/FFPatch"];
        [fileManager createDirectoryAtPath:root
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:NULL];
    });
    return root;
}
