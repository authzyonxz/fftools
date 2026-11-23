//
//  FFSandbox.m
//  FFPatch
//

#import "FFSandbox.h"
#import "FFCore.h"

#import "Vendor/bad_query.h"
#import "Vendor/worse_query.h"
#import "Vendor/sandbox_escape.h"
#import "Vendor/kexploit_opa334.h"
#import "Vendor/kutils.h"

#import <errno.h>

#pragma mark - Policy (mirrors 3106 ExploitSupportPolicy)

static BOOL FFSupportsKernelExploit(int major, int minor, int patch, BOOL isA10) {
    if (minor < 0 || patch < 0) return NO;
    // A10 Fusion hangs inside the kernel chain on iOS 17 — refused by chip.
    if (isA10 && major == 17) return NO;
    if (major == 17) return minor <= 7;
    if (major == 18) return minor < 7 || (minor == 7 && patch <= 1);
    return NO;
}

static BOOL FFSupportsBadQuery(int major, int minor, int patch) {
    if (major != 26 || minor < 0 || patch < 0) return NO;
    return minor < 6 || (minor == 6 && patch <= 1);
}

static NSArray<NSString *> *FFVerifiedIOS27Builds(void) {
    // 27.3 beta 2 (24C5049d) patched worse_query. Only beta 1 is verified.
    static NSArray<NSString *> *builds;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        builds = @[@"24C5037i"];
    });
    return builds;
}

static BOOL FFSupportsWorseQuery(int major, int minor, int patch, NSString *build) {
    if (minor < 0 || patch < 0) return NO;
    if (major == 26) return minor == 7 && patch <= 2;
    if (major == 27) {
        if (minor <= 2) return YES;
        if (minor == 3) {
            return patch == 0 && [FFVerifiedIOS27Builds() containsObject:build ?: @""];
        }
    }
    return NO;
}

static BOOL FFIsIOS18KernelPatched(int major, int minor, int patch) {
    if (major != 18) return NO;
    if (minor > 7) return YES;
    return minor == 7 && patch >= 2;
}

FFSandboxBackend FFSandboxCurrentBackend(void) {
    static FFSandboxBackend backend;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        int major = FFOSMajorNumber(), minor = FFOSMinorNumber(), patch = FFOSPatchNumber();
        if (FFSupportsKernelExploit(major, minor, patch, FFDeviceIsA10())) {
            backend = FFSandboxBackendKernel;
        } else if (FFSupportsWorseQuery(major, minor, patch, FFOSBuildString())) {
            backend = FFSandboxBackendWorseQuery;
        } else if (FFSupportsBadQuery(major, minor, patch)) {
            backend = FFSandboxBackendBadQuery;
        } else {
            backend = FFSandboxBackendUnsupported;
        }
        FFLog(@"sandbox: backend=%@ (iOS %@ build %@ model %@)",
              FFSandboxBackendName(backend),
              FFOSVersionString(), FFOSBuildString(), FFDeviceModelIdentifier());
    });
    return backend;
}

NSString *FFSandboxBackendName(FFSandboxBackend backend) {
    switch (backend) {
        case FFSandboxBackendKernel:     return @"kernel";
        case FFSandboxBackendBadQuery:   return @"bad_query";
        case FFSandboxBackendWorseQuery: return @"worse_query";
        default:                          return @"unsupported";
    }
}

NSString *FFSandboxBackendNameCurrent(void) {
    return FFSandboxBackendName(FFSandboxCurrentBackend());
}

BOOL FFSandboxOSIsSupported(void) {
    return FFSandboxCurrentBackend() != FFSandboxBackendUnsupported;
}

NSString *FFSandboxUnsupportedReason(void) {
    int major = FFOSMajorNumber(), minor = FFOSMinorNumber(), patch = FFOSPatchNumber();
    if (FFDeviceIsA10() && major == 17) {
        return @"A10 Fusion + iOS 17 não é suportado (a cadeia de kernel trava o aparelho).";
    }
    if (FFIsIOS18KernelPatched(major, minor, patch)) {
        return @"iOS 18.7.2+ tem o kernel exploit corrigido pela Apple (CVE-2025-43510/43520). "
               @"Nenhuma build futura deste projeto suporta essa versão.";
    }
    if (major == 27 && minor == 3) {
        return [NSString stringWithFormat:
            @"iOS 27.3 só é aceito na build %@ (beta 1). A partir do beta 2 a Apple corrigiu a técnica.",
            [FFVerifiedIOS27Builds() componentsJoinedByString:@", "]];
    }
    return [NSString stringWithFormat:
        @"Sistema não suportado: iOS %@ (build %@). Faixas verificadas: "
        @"17.0–17.7.x · 18.0–18.7.1 · 26.0–26.6.1 · 26.7–26.7.2 · 27.0–27.2 · 27.3 beta 1.",
        FFOSVersionString(), FFOSBuildString()];
}

#pragma mark - Grants

NSString *FFSandboxAppGroup(void) {
    return worse_query_app_group();
}

int64_t FFSandboxGrantPath(NSString *path, BOOL writable, int *errorCode) {
    if (path.length == 0) {
        if (errorCode) *errorCode = -1;
        return -1;
    }
    NSString *clean = path;
    while (clean.length > 1 && [clean hasSuffix:@"/"]) {
        clean = [clean substringToIndex:clean.length - 1];
    }
    const char *raw = clean.fileSystemRepresentation;
    int64_t handle = -1;

    switch (FFSandboxCurrentBackend()) {
        case FFSandboxBackendKernel:
            // No grant object: the kernel escape already removed the sandbox
            // restriction. -1 means "not needed", not "failed".
            handle = -1;
            break;
        case FFSandboxBackendBadQuery:
            handle = bad_query((char *)raw, true, NULL, false);
            break;
        case FFSandboxBackendWorseQuery: {
            handle = writable ? worse_query_grant_ex(raw, 1) : worse_query_grant(raw);
            if (handle == -5) {
                // App Group Library/Caches in a state the swap cannot start
                // from. Repair once and ask again.
                if (worse_query_reset_access_cache()) {
                    handle = writable ? worse_query_grant_ex(raw, 1) : worse_query_grant(raw);
                }
            }
            break;
        }
        default:
            handle = -1;
            break;
    }

    if (errorCode) *errorCode = (int)handle;
    if (handle < 0 && FFSandboxCurrentBackend() != FFSandboxBackendKernel) {
        FFLog(@"sandbox: grant refused path=%@ writable=%d code=%lld backend=%@",
              clean, (int)writable, handle, FFSandboxBackendNameCurrent());
    }
    return handle;
}

void FFSandboxReleaseHandle(int64_t handle) {
    if (handle < 0) return;
    switch (FFSandboxCurrentBackend()) {
        case FFSandboxBackendBadQuery:
            bad_query_release(handle);
            break;
        case FFSandboxBackendWorseQuery:
            worse_query_release(handle);
            break;
        default:
            break;
    }
}

#pragma mark - Probe / activation

static NSLock *FFProbeLock(void) {
    static NSLock *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSLock new];
    });
    return lock;
}

static BOOL FFSandboxProbeUncached(void) {
    switch (FFSandboxCurrentBackend()) {
        case FFSandboxBackendKernel:
            return sandbox_access_is_active() == 1;

        case FFSandboxBackendBadQuery: {
            int64_t handle = FFSandboxGrantPath(@"/var/mobile/Containers/Data", YES, NULL);
            BOOL ok = handle >= 0;
            if (ok) FFSandboxReleaseHandle(handle);
            return ok;
        }

        case FFSandboxBackendWorseQuery: {
            NSString *group = worse_query_app_group();
            if (group.length == 0) {
                FFLog(@"sandbox: sem App Group — worse_query não roda");
                return NO;
            }
            NSString *groupPath = nil;
            NSURL *groupURL = [[NSFileManager defaultManager]
                containerURLForSecurityApplicationGroupIdentifier:group];
            if (groupURL.path.length) {
                groupPath = groupURL.path;
            } else {
                groupPath = [@"/var/mobile/Containers/Shared/AppGroup" stringByAppendingPathComponent:group];
            }
            int64_t handle = FFSandboxGrantPath(groupPath, YES, NULL);
            if (handle >= 0) {
                FFSandboxReleaseHandle(handle);
                return YES;
            }
            handle = FFSandboxGrantPath(@"/var/mobile/Containers/Data", YES, NULL);
            if (handle >= 0) {
                FFSandboxReleaseHandle(handle);
                return YES;
            }
            return NO;
        }

        default:
            return NO;
    }
}

static BOOL FFProbeCachedValue = NO;
static NSDate *FFProbeCachedAt = nil;
static BOOL FFProbeCachedValid = NO;

BOOL FFSandboxAccessActive(void) {
    [FFProbeLock() lock];
    if (FFProbeCachedValid && FFProbeCachedAt != nil &&
        [[NSDate date] timeIntervalSinceDate:FFProbeCachedAt] < 30.0) {
        BOOL cached = FFProbeCachedValue;
        [FFProbeLock() unlock];
        return cached;
    }
    [FFProbeLock() unlock];

    BOOL value = FFSandboxProbeUncached();

    [FFProbeLock() lock];
    FFProbeCachedValue = value;
    FFProbeCachedAt = [NSDate date];
    FFProbeCachedValid = YES;
    [FFProbeLock() unlock];

    FFLog(@"sandbox: probe %@ (%@)", value ? @"OK" : @"FAILED", FFSandboxBackendNameCurrent());
    return value;
}

BOOL FFSandboxInvalidateCaches(void) {
    [FFProbeLock() lock];
    FFProbeCachedValid = NO;
    FFProbeCachedAt = nil;
    [FFProbeLock() unlock];
    if (FFSandboxCurrentBackend() == FFSandboxBackendWorseQuery) {
        worse_query_forget_all();
        worse_query_invalidate_caches();
    }
    return YES;
}

BOOL FFSandboxActivate(NSString **detailOut) {
    if (!FFSandboxOSIsSupported()) {
        if (detailOut) *detailOut = FFSandboxUnsupportedReason();
        return NO;
    }

    FFSandboxBackend backend = FFSandboxCurrentBackend();
    FFLog(@"exploit: ===== %@ backend =====", FFSandboxBackendName(backend));

    if (backend == FFSandboxBackendKernel) {
        // Jailbroken devices patch the sandbox themselves: the chain result is
        // not attributable to us, so do not claim a state we cannot stand behind.
        BOOL looksJailbroken = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"] ||
                               [[NSFileManager defaultManager] fileExistsAtPath:@"/usr/lib/libsubstitute.dylib"] ||
                               [[NSFileManager defaultManager] fileExistsAtPath:@"/usr/lib/libhooker.dylib"] ||
                               [[NSFileManager defaultManager] fileExistsAtPath:@"/.installed_unc0ver"];
        if (looksJailbroken && sandbox_access_is_active() == 0) {
            if (detailOut) *detailOut = @"ambiente com jailbreak detectado — a cadeia de kernel "
                                        @"não roda com resultado confiável aqui.";
            FFLog(@"exploit: refused — jailbreak environment detected");
            return NO;
        }

        FFLog(@"kexploit: ===== STAGE 1/2: kernel r/w (kexploit_opa334) =====");
        int kernelResult = kexploit_opa334();
        if (kernelResult != 0) {
            if (detailOut) *detailOut = [NSString stringWithFormat:
                @"kernel exploit falhou (retorno %d). Build não suportada, offsets errados ou race perdida.",
                kernelResult];
            FFLog(@"kexploit: FAILED ret=%d", kernelResult);
            return NO;
        }
        FFLog(@"kexploit: OK — kernel r/w estabelecido");

        FFLog(@"kexploit: ===== STAGE 2/2: sandbox escape =====");
        uint64_t selfProcess = proc_self();
        if (selfProcess == 0) {
            if (detailOut) *detailOut = @"proc_self() retornou 0.";
            return NO;
        }
        int escapeResult = sandbox_escape(selfProcess);
        BOOL active = sandbox_access_is_active() == 1;
        FFLog(@"kexploit: sandbox_escape ret=%d probe=%d", escapeResult, (int)active);

        // Below iOS 26 the kernel r/w is useful even when the escape's own probe
        // samples badly, so a failed probe degrades instead of aborting.
        if (!active && escapeResult != 0) {
            if (detailOut) *detailOut = [NSString stringWithFormat:
                @"sandbox escape falhou (retorno %d).", escapeResult];
            return NO;
        }
        FFSandboxInvalidateCaches();
        if (detailOut) *detailOut = active ? @"kernel + sandbox escape ativos"
                                           : @"kernel r/w ativo (limitado)";
        return YES;
    }

    if (backend == FFSandboxBackendWorseQuery) {
        if (worse_query_app_group().length == 0) {
            if (detailOut) *detailOut = @"sem App Group. Assine com AltStore/SideStore/Sideloadly "
                                        @"ou com um App ID explícito com a capability App Groups.";
            return NO;
        }
        if (!worse_query_recover()) {
            FFLog(@"exploit: recover de Caches pediu atenção (seguindo)");
        }
    }

    BOOL ok = FFSandboxProbeUncached();
    if (detailOut) *detailOut = ok ? [NSString stringWithFormat:@"%@ ativo", FFSandboxBackendName(backend)]
                                   : [NSString stringWithFormat:@"%@ recusou o probe", FFSandboxBackendName(backend)];
    if (ok) FFSandboxInvalidateCaches();
    return ok;
}

#pragma mark - Grant + body helper

BOOL FFSandboxPerformWithGrant(NSString *directory,
                               BOOL writable,
                               NSError *(^body)(void),
                               NSError **error) {
    int grantCode = 0;
    int64_t handle = FFSandboxGrantPath(directory, writable, &grantCode);
    BOOL granted = handle >= 0 || FFSandboxCurrentBackend() == FFSandboxBackendKernel;

    if (!granted) {
        if (error) {
            *error = FFMakeError(FFErrorNoSandboxAccess,
                                 @"sem permissão de sandbox em %@ (código %d, backend %@)",
                                 directory.lastPathComponent, grantCode,
                                 FFSandboxBackendNameCurrent());
        }
        return NO;
    }

    NSError *bodyError = body();
    if (handle >= 0) FFSandboxReleaseHandle(handle);

    if (bodyError == nil) return YES;

    BOOL retryable = [bodyError.domain isEqualToString:NSPOSIXErrorDomain] &&
                     (bodyError.code == EPERM || bodyError.code == EACCES);
    if (!retryable || FFSandboxCurrentBackend() != FFSandboxBackendWorseQuery) {
        if (error) *error = bodyError;
        return NO;
    }

    // A stale token in the LRU is the usual suspect after a denied write.
    FFSandboxInvalidateCaches();
    handle = FFSandboxGrantPath(directory, writable, &grantCode);
    if (handle < 0) {
        if (error) {
            *error = FFMakeError(FFErrorNoSandboxAccess,
                                 @"re-concessão falhou em %@ (código %d)",
                                 directory.lastPathComponent, grantCode);
        }
        return NO;
    }
    NSError *retryError = body();
    FFSandboxReleaseHandle(handle);
    if (retryError == nil) return YES;
    if (error) *error = retryError;
    return NO;
}
