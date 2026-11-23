//
//  FFSandbox.h
//  FFPatch — sandbox-grant routing ported from the 3106 base (GPL-3.0).
//
//  Backends, by OS:
//    kernel      iOS 17.0–17.7.x, 18.0–18.7.1   kexploit_opa334 + sandbox_escape
//    bad_query   iOS 26.0–26.6.1                bad_query grant
//    worse_query iOS 26.7–26.7.2, 27.0–27.2, 27.3 build 24C5037i
//  Anything else is unsupported and refused before a single write happens.
//

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

/*! Backend selected purely from the running OS version + build number. */
FFSandboxBackend FFSandboxCurrentBackend(void);
NSString *FFSandboxBackendName(FFSandboxBackend backend);
NSString *FFSandboxBackendNameCurrent(void);

/*! YES when the current OS version/build is one of the verified lines. */
BOOL FFSandboxOSIsSupported(void);

/*! Human-readable explanation for an unsupported device (pt-BR). */
NSString *FFSandboxUnsupportedReason(void);

/*! Grants a sandbox extension for `path`. Returns a handle >= 0, or a negative
    error code. On the kernel backend no grant exists and -1 is returned on
    purpose: access comes from the escape itself. */
int64_t FFSandboxGrantPath(NSString *path, BOOL writable, int *_Nullable errorCode);

void FFSandboxReleaseHandle(int64_t handle);

/*! Cheap-ish probe (cached for 30 s). */
BOOL FFSandboxAccessActive(void);

/*! Heavy activation. On the kernel backend this runs kexploit + escape and may
    take 10–30 s. Call from a background thread only. Returns YES when container
    access is usable afterwards. */
BOOL FFSandboxActivate(NSString **_Nullable detailOut);

/*! Waits for any in-flight sandbox activation or uncached probe to finish. */
void FFSandboxWaitForActivation(void);

/*! Drops the cached probe result and every cached worse_query token. */
BOOL FFSandboxInvalidateCaches(void);

/*! App-Group entitlement string the signer gave us, or nil. Only worse_query
    needs it. */
NSString *_Nullable FFSandboxAppGroup(void);

/*! Convenience wrapper around grant + body + release with the worse_query
    retry path (EPERM/EACCES → forget tokens → grant again → retry once). */
BOOL FFSandboxPerformWithGrant(NSString *directory,
                               BOOL writable,
                               NSError *_Nullable (^body)(void),
                               NSError *_Nullable *_Nullable error);

NS_ASSUME_NONNULL_END

#endif /* FF_SANDBOX_H */
