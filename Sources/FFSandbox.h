

#ifndef FF_SANDBOX_H
#define FF_SANDBOX_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FFSandboxBackend) {
    FFSandboxBackendUnsupported = -1,
    FFSandboxBackendKernel      = 0,
    FFSandboxBackendBadQuery    = 1,
    FFSandboxBackendWorseQuery  = 2,
};

FFSandboxBackend FFSandboxCurrentBackend(void);
NSString *FFSandboxBackendName(FFSandboxBackend backend);
NSString *FFSandboxBackendNameCurrent(void);

BOOL FFSandboxOSIsSupported(void);

NSString *FFSandboxUnsupportedReason(void);

int64_t FFSandboxGrantPath(NSString *path, BOOL writable, int *_Nullable errorCode);

void FFSandboxReleaseHandle(int64_t handle);

BOOL FFSandboxAccessActive(void);

BOOL FFSandboxActivate(NSString **_Nullable detailOut);

void FFSandboxWaitForActivation(void);

void FFSandboxClearKernelCrashGuard(void);

BOOL FFSandboxInvalidateCaches(void);

BOOL FFSandboxHostIsMobileHouseArrest(void);

NSString *_Nullable FFSandboxAppGroup(void);

BOOL FFSandboxPerformWithGrant(NSString *directory,
                               BOOL writable,
                               NSError *_Nullable (^body)(void),
                               NSError *_Nullable *_Nullable error);

NS_ASSUME_NONNULL_END

#endif
