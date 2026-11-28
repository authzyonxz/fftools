#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "KAExternalClient.h"
#import "KASecurity.h"
#import "KAIntegrity.h"
#include <assert.h>

@implementation KAExternalClient
- (void)loginWithLicense:(NSString *)license remember:(BOOL)remember completion:(KACompletion)completion {}
- (void)authorizeOperation:(KACompletion)completion {}
- (NSDictionary *)validateCurrent:(NSError **)error { return nil; }
- (NSDictionary *)completeChallenge:(NSString *)purpose key:(SecKeyRef)key license:(NSString *)license error:(NSError **)error { return nil; }
- (void)revalidate:(KACompletion)completion {}
- (void)invalidate {}
- (void)forgetLicense {}
- (void)requestForFunction:(NSString *)function original:(BOOL)original completion:(void (^)(NSURLRequest *,NSError *))completion {}
@end
NSDictionary *KAVerifyGrant(NSString *jwt,NSString *session,NSString *installation,NSError **error) { return nil; }
static void changed(id object,SEL selector,KACompletion completion) {}
int main(void) { @autoreleasepool {
    assert(KAIntegrityCheck());
    Method method = class_getInstanceMethod(KAExternalClient.class,@selector(authorizeOperation:));
    IMP original = method_setImplementation(method,(IMP)changed);
    assert(!KAIntegrityCheck());
    method_setImplementation(method,original);
    assert(KAIntegrityCheck());
    puts("Authentication integrity: baseline, substituted method, restored method passed.");
} }
