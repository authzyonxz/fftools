

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
    FFErrorAccessDenied        = 18,
};

FOUNDATION_EXPORT NSError *FFMakeError(FFErrorCode code, NSString *format, ...) NS_FORMAT_FUNCTION(2, 3);

NSString *FFUserMessageForError(NSError *_Nullable error);

void FFLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
NSString *FFLogFilePath(void);

int FFOSMajorNumber(void);
int FFOSMinorNumber(void);
int FFOSPatchNumber(void);
NSString *FFOSVersionString(void);
NSString *FFOSBuildString(void);
NSString *FFDeviceModelIdentifier(void);
BOOL FFDeviceIsA10(void);

NSString *FFSHA256HexOfData(NSData *data);
NSString *FFSHA256HexOfFile(NSString *path, NSError *_Nullable *_Nullable error);

BOOL FFSafeWriteFile(NSString *path, NSData *data, NSError *_Nullable *_Nullable error);

BOOL FFSafeCopyFile(NSString *source, NSString *path, NSError *_Nullable *_Nullable error);

BOOL FFRelativePathIsSafe(NSString *relativePath);

NSString *_Nullable FFResolveContainedPath(NSString *root,
                                           NSString *relativePath,
                                           NSError *_Nullable *_Nullable error);

BOOL FFPathContainsSymlink(NSString *root, NSString *relativePath);

NSDictionary *_Nullable FFReadPlist(NSString *path);
BOOL FFWritePlist(NSDictionary *plist, NSString *path, NSError *_Nullable *_Nullable error);

NSString *FFPatchRootDirectory(void);

NS_ASSUME_NONNULL_END

#endif
