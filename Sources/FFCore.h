//
//  FFCore.h
//  FFPatch — raw-container patch engine for Free Fire (com.dts.freefireth / com.dts.freefiremax)
//
//  Objective-C / C only. No Swift, no SwiftUI, no Combine.
//  The whole app lives in a dylib (see Sources/entry.m); the IPA's MH_EXECUTE
//  main binary is a 20-line dlopen stub (Sources/launcher/main.c).
//
//  Derived from 3106 / 3105 container-management base (GPL-3.0). See NOTICE.md.
//

#ifndef FF_CORE_H
#define FF_CORE_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const FFErrorDomain;

typedef NS_ENUM(NSInteger, FFErrorCode) {
    FFErrorUnsupportedOS       = 1,
    FFErrorNoSandboxAccess     = 2,
    FFErrorAppNotFound         = 3,
    FFErrorPayloadMissing      = 4,
    FFErrorInvalidPayload      = 5,
    FFErrorPathEscapesContainer = 6,
    FFErrorSymlinkRefused      = 7,
    FFErrorAlreadyApplied      = 8,
    FFErrorNotApplied          = 9,
    FFErrorApplyFailed         = 10,
    FFErrorRestoreFailed       = 11,
    FFErrorVerifyFailed        = 12,
    FFErrorBackupMissing       = 13,
    FFErrorContainerChanged    = 14,
    FFErrorTargetIsDirectory   = 15,
    FFErrorDuplicateTarget     = 16,
    FFErrorTargetNotFound      = 17,
};

FOUNDATION_EXPORT NSError *FFMakeError(FFErrorCode code, NSString *format, ...) NS_FORMAT_FUNCTION(2, 3);

/*! One short, user-facing line for an NSError (pt-BR). The technical detail
    stays in the log / detail row; the alert never dumps a wall of text. */
NSString *FFUserMessageForError(NSError *_Nullable error);

/*! Minimal file logger (NSLog + a rotating file inside our own container). */
void FFLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
NSString *FFLogFilePath(void);

/* ---- OS / device ---- */
int FFOSMajorNumber(void);
int FFOSMinorNumber(void);
int FFOSPatchNumber(void);
NSString *FFOSVersionString(void);
NSString *FFOSBuildString(void);
NSString *FFDeviceModelIdentifier(void);
BOOL FFDeviceIsA10(void);

/* ---- digests / safe IO ---- */
NSString *FFSHA256HexOfData(NSData *data);
NSString *FFSHA256HexOfFile(NSString *path, NSError *_Nullable *_Nullable error);

/*! Writes `data` to `path` through a hidden staging file in the same directory,
    copies the POSIX permissions of an existing target, fsyncs and renames.
    Returns NO and fills `error` on any failure. */
BOOL FFSafeWriteFile(NSString *path, NSData *data, NSError *_Nullable *_Nullable error);

/*! Same as above but copies the file at `source` (staging + rename). */
BOOL FFSafeCopyFile(NSString *source, NSString *path, NSError *_Nullable *_Nullable error);

/* ---- path hygiene ---- */
/*! Rejects absolute paths, empty components and any ".." component. */
BOOL FFRelativePathIsSafe(NSString *relativePath);

/*! Joins `relativePath` under `root` after validating it, then verifies that no
    component of the resulting path is a symlink. Returns nil + error. */
NSString *_Nullable FFResolveContainedPath(NSString *root,
                                           NSString *relativePath,
                                           NSError *_Nullable *_Nullable error);

/*! YES when some component strictly below `root` is a symlink. */
BOOL FFPathContainsSymlink(NSString *root, NSString *relativePath);

/* ---- plists ---- */
NSDictionary *_Nullable FFReadPlist(NSString *path);
BOOL FFWritePlist(NSDictionary *plist, NSString *path, NSError *_Nullable *_Nullable error);

/*! Application Support/FFPatch directory inside our own data container. */
NSString *FFPatchRootDirectory(void);

NS_ASSUME_NONNULL_END

#endif /* FF_CORE_H */
