

#import "FFProtect.h"
#import "FFCore.h"

#import <dlfcn.h>
#import <stdlib.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <sys/proc.h>
#import <unistd.h>

#ifndef P_TRACED
#define P_TRACED 0x00000800
#endif

static const unsigned char FFMaskByte = 0x5B;

static unsigned char FFMaskAt(size_t index) {
    return (unsigned char)(FFMaskByte ^ ((index * 31) & 0xFF));
}

NSString *FFMaskedString(const unsigned char *bytes, size_t length) {
    if (bytes == NULL || length == 0) return nil;
    NSMutableData *plain = [NSMutableData dataWithLength:length];
    unsigned char *out = plain.mutableBytes;
    for (size_t index = 0; index < length; index++) {
        out[index] = bytes[index] ^ FFMaskAt(index);
    }
    NSString *string = [[NSString alloc] initWithData:plain encoding:NSUTF8StringEncoding];
    return string.length ? string : nil;
}

NSData *FFMaskedData(const unsigned char *bytes, size_t length) {
    if (bytes == NULL || length == 0) return nil;
    NSMutableData *plain = [NSMutableData dataWithLength:length];
    unsigned char *out = plain.mutableBytes;
    for (size_t index = 0; index < length; index++) {
        out[index] = bytes[index] ^ FFMaskAt(index);
    }
    return plain;
}

static NSData *FFConfigBlob(NSString *key) {
    NSString *plistPath = [[[NSBundle mainBundle] bundlePath]
        stringByAppendingPathComponent:@"Catalog.plist"];
    NSDictionary *config = FFReadPlist(plistPath);
    NSString *encoded = config[key];
    if (![encoded isKindOfClass:[NSString class]] || encoded.length == 0) return nil;
    NSData *masked = [[NSData alloc] initWithBase64EncodedString:encoded options:0];
    if (masked.length == 0) return nil;
    return FFMaskedData(masked.bytes, masked.length);
}

NSString *FFCatalogBaseURL(void) {
    static NSString *baseURL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSData *plain = FFConfigBlob(@"baseURLMasked");
        if (plain.length == 0) {

            NSString *plistPath = [[[NSBundle mainBundle] bundlePath]
                stringByAppendingPathComponent:@"Catalog.plist"];
            NSDictionary *config = FFReadPlist(plistPath);
            NSString *plainURL = config[@"baseURL"];
            baseURL = [plainURL isKindOfClass:[NSString class]] ? plainURL : nil;
        } else {
            baseURL = [[NSString alloc] initWithData:plain encoding:NSUTF8StringEncoding];
        }
        while (baseURL.length > 1 && [baseURL hasSuffix:@"/"]) {
            baseURL = [baseURL substringToIndex:baseURL.length - 1];
        }
    });
    return baseURL.length ? baseURL : nil;
}

NSData *FFMasterSecret(void) {
    static NSData *secret;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSData *plain = FFConfigBlob(@"masterSecretMasked");
        if (plain.length == 0) {
            NSString *plistPath = [[[NSBundle mainBundle] bundlePath]
                stringByAppendingPathComponent:@"Catalog.plist"];
            NSDictionary *config = FFReadPlist(plistPath);
            NSString *text = config[@"masterSecret"];
            if ([text isKindOfClass:[NSString class]] && text.length >= 16) {
                plain = [text dataUsingEncoding:NSUTF8StringEncoding];
            }
        }
        secret = plain.length >= 16 ? plain : nil;
    });
    return secret;
}

BOOL FFIsBeingTraced(void) {
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info;
    memset(&info, 0, sizeof(info));
    size_t size = sizeof(info);
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) return NO;
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

void FFProtectInstall(void) {

    if (getenv("FFPATCH_DEBUG") != NULL) {
        FFLog(@"protect: FFPATCH_DEBUG set — anti-debug desligado");
        return;
    }
#ifdef FF_ENABLE_ANTIDEBUG
    if (FFIsBeingTraced()) {
        FFLog(@"protect: processo sendo rastreado — encerrando");
        exit(0);
    }

    typedef int (*FFPtraceFn)(int request, pid_t pid, void *addr, int data);
    void *handle = dlopen(NULL, RTLD_NOW);
    if (handle != NULL) {
        FFPtraceFn ptraceFn = (FFPtraceFn)dlsym(handle, "ptrace");
        if (ptraceFn != NULL) {
            (void)ptraceFn(31                     , 0, NULL, 0);
        }
    }
    FFLog(@"protect: anti-debug instalado");
#endif
}
