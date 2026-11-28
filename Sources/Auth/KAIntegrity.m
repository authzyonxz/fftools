#import "KAIntegrity.h"
#import "KAExternalClient.h"
#import "KASecurity.h"
#import "KAPolicy.h"
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <dlfcn.h>

typedef struct { SEL selector; IMP implementation; unsigned char digest[CC_SHA256_DIGEST_LENGTH]; } KAGuard;
static KAGuard guards[4];
static unsigned char cryptoDigest[CC_SHA256_DIGEST_LENGTH], policyDigest[CC_SHA256_DIGEST_LENGTH];
static BOOL initialized;
static void *ownImage;
static BOOL KADigest(const void *address, unsigned char *digest) {
    unsigned char bytes[64]; vm_size_t count = 0;
    if (vm_read_overwrite(mach_task_self(), (vm_address_t)address, sizeof(bytes),
        (vm_address_t)bytes, &count) != KERN_SUCCESS || count != sizeof(bytes)) return NO;
    CC_SHA256(bytes,sizeof(bytes),digest); return YES;
}
static BOOL KASame(const void *address, const unsigned char *expected) {
    Dl_info info = {0}; unsigned char actual[CC_SHA256_DIGEST_LENGTH];
    if (!dladdr(address,&info) || info.dli_fbase != ownImage || !KADigest(address,actual)) return NO;
    unsigned difference = 0;
    for (unsigned i=0;i<sizeof(actual);i++) difference |= actual[i] ^ expected[i];
    return difference == 0;
}
@interface KAIntegrityBootstrap : NSObject @end
@implementation KAIntegrityBootstrap
+ (void)load {
    Dl_info info = {0}; if (!dladdr((const void *)KAIntegrityCheck,&info)) return;
    ownImage = info.dli_fbase;
    SEL selectors[] = {@selector(loginWithLicense:remember:completion:), @selector(authorizeOperation:),
        NSSelectorFromString(@"validateCurrent:"), NSSelectorFromString(@"completeChallenge:key:license:error:")};
    for (unsigned i=0;i<4;i++) {
        Method method = class_getInstanceMethod(KAExternalClient.class,selectors[i]);
        if (!method) return;
        guards[i].selector = selectors[i]; guards[i].implementation = method_getImplementation(method);
        if (!KADigest((const void *)guards[i].implementation,guards[i].digest)) return;
    }
    initialized = KADigest((const void *)KAVerifyGrant,cryptoDigest) && KADigest((const void *)KAPolicyAccept,policyDigest);
}
@end
BOOL KAIntegrityCheck(void) {
    if (!initialized) return NO;
    for (unsigned i=0;i<4;i++) {
        Method method = class_getInstanceMethod(KAExternalClient.class,guards[i].selector);
        IMP current = method ? method_getImplementation(method) : NULL;
        if (current != guards[i].implementation || !KASame((const void *)current,guards[i].digest)) return NO;
    }
    return KASame((const void *)KAVerifyGrant,cryptoDigest) && KASame((const void *)KAPolicyAccept,policyDigest);
}
