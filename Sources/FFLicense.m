//
//  FFLicense.m
//  FFPatch
//

#import "FFLicense.h"
#import "FFCore.h"
#import "FFProtect.h"
#import "FFSandbox.h"
#import "Vendor/LogosAPI/APIClient.h"

NSNotificationName const FFLicenseDidUpdateNotification = @"FFLicenseDidUpdateNotification";

static NSString *FFLicenseDisplayExpiry(id value) {
    if (![value isKindOfClass:[NSString class]]) return @"—";
    NSString *candidate = [(NSString *)value stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (candidate.length == 0) return @"—";

    NSString *normalized = candidate.lowercaseString;
    NSSet<NSString *> *unlimitedValues = [NSSet setWithArray:
        @[@"unlimited", @"lifetime", @"permanent", @"ilimitada", @"vitalícia"]];
    if ([unlimitedValues containsObject:normalized]) return @"Ilimitada";

    NSArray<NSString *> *formats = @[
        @"yyyy-MM-dd'T'HH:mm:ssXXXXX", @"yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        @"yyyy-MM-dd HH:mm:ss", @"yyyy-MM-dd", @"yyyy/MM/dd",
        @"dd/MM/yyyy", @"MM/dd/yyyy", @"dd-MM-yyyy", @"yyyyMMdd",
        @"dd MMM yyyy", @"MMM d, yyyy"
    ];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.lenient = NO;
    for (NSString *format in formats) {
        formatter.dateFormat = format;
        if ([formatter dateFromString:candidate] != nil) return candidate;
    }
    return @"—";
}

static NSString *FFLicenseStringFromAPI(const char *value) {
    if (value == NULL || value[0] == '\0') return nil;
    NSString *result = [NSString stringWithUTF8String:value];
    return result.length ? result : nil;
}

@interface FFLicense ()
@property (nonatomic, assign, readwrite) BOOL apiValidated;
@property (nonatomic, assign, readwrite) BOOL apiValidationPending;
@property (nonatomic, strong) NSMutableArray *validationCompletions;
@property (nonatomic, assign) NSUInteger validationGeneration;
@property (nonatomic, assign) NSUInteger pendingApplyAuthorizations;
- (void)requestPaidStatusWithCompletion:(void (^)(BOOL, NSString *, NSString *))completion;
- (void)finishValidationWithSuccess:(BOOL)success
                            package:(NSString *)package
                             expiry:(NSString *)expiry
                        generation:(NSUInteger)generation;
@end

@implementation FFLicense

+ (NSString *)defaultCompatibleRanges {
    return @"iOS 17.0–17.7.x · 18.0–18.7.1 · 26.0–26.6.1 · 26.7–26.7.2 · 27.0–27.2 · 27.3 β1";
}

+ (instancetype)current {
    static FFLicense *license;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        license = [FFLicense create];
    });
    return license;
}

+ (instancetype)create {
    FFLicense *license = [FFLicense new];
    NSBundle *bundle = [NSBundle mainBundle];

    NSString *plistPath = [bundle.bundlePath stringByAppendingPathComponent:@"License.plist"];
    NSDictionary *configured = FFReadPlist(plistPath);

    license.key = @"";
    license.status = @"AGUARDANDO";
    license.duration = @"—";
    license.packageName = @"—";

    NSArray *ranges = configured[@"compatible"];
    if ([ranges isKindOfClass:[NSArray class]] && ranges.count) {
        license.compatibleRanges = [ranges componentsJoinedByString:@" · "];
    } else {
        license.compatibleRanges = [FFLicense defaultCompatibleRanges];
    }

    NSString *version = configured[@"version"] ?: (bundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"0.0.0");
    NSString *buildNumber = configured[@"build"] ?: (bundle.infoDictionary[@"CFBundleVersion"] ?: @"0");
    license.build = [NSString stringWithFormat:@"%@ (%@)", version, buildNumber];

    license.deviceModel = FFDeviceModelIdentifier();
    license.deviceOS = [NSString stringWithFormat:@"iOS %@", FFOSVersionString()];
    license.deviceBuild = FFOSBuildString().length ? FFOSBuildString() : @"—";
    license.sandboxBackend = FFSandboxBackendNameCurrent();

    if (!FFSandboxOSIsSupported()) {
        license.accessStatus = @"SISTEMA NÃO SUPORTADO";
    } else if ([license.sandboxBackend isEqualToString:@"kernel"]) {
        license.accessStatus = @"aguardando desbloqueio";
    } else {
        license.accessStatus = @"acesso ativo";
    }

    license.validationCompletions = [NSMutableArray array];
    return license;
}

- (void)requestPaidStatusWithCompletion:(void (^)(BOOL, NSString *, NSString *))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Keep the official API flow; select its supported English interface.
        apiclient_set_language("en");
        apiclient_set_token("b2GzBzvDVfMBlP96tm5q2SwHKJbPr1JzPwyOJs5f59qNi0nwolEDstMEOrlEsxHyiUUj4M/7hRwYD6VApIf9c3kkgQYy6dWE/B69+eT5F0g=");

        __block BOOL completed = NO;
        void (^finishOnce)(BOOL, NSString *, NSString *) = ^(BOOL success,
                                                               NSString *package,
                                                               NSString *expiry) {
            if (completed) return;
            completed = YES;
            if (completion) completion(success, package ?: @"—", expiry ?: @"—");
        };

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            finishOnce(NO, @"—", @"—");
        });

        apiclient_paid(^{
            NSString *package = FFLicenseStringFromAPI(apiclient_get_package_name());
            NSString *expiry = FFLicenseStringFromAPI(apiclient_get_expired_at_local());
            if (expiry.length == 0) {
                expiry = FFLicenseStringFromAPI(apiclient_get_expired_at());
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.key = FFLicenseStringFromAPI(apiclient_get_key()) ?: @"";
                finishOnce(YES, package, expiry);
            });
        });
    });
}

- (void)validateWithCompletion:(void (^)(BOOL))completion {
    __block NSUInteger generation = 0;
    @synchronized (self) {
        if (self.apiValidated) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{ completion(YES); });
            }
            return;
        }
        if (self.apiValidationPending) {
            if (completion) [self.validationCompletions addObject:[completion copy]];
            return;
        }
        self.apiValidationPending = YES;
        self.status = @"VALIDANDO";
        self.pendingApplyAuthorizations = 0;
        generation = ++self.validationGeneration;
        if (completion) [self.validationCompletions addObject:[completion copy]];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:FFLicenseDidUpdateNotification object:self];
    });

    [self requestPaidStatusWithCompletion:^(BOOL success, NSString *package, NSString *expiry) {
        [self finishValidationWithSuccess:success
                                  package:package
                                   expiry:expiry
                              generation:generation];
    }];
}

- (void)finishValidationWithSuccess:(BOOL)success
                            package:(NSString *)package
                             expiry:(NSString *)expiry
                        generation:(NSUInteger)generation {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *completions = nil;
        @synchronized (self) {
            if (!self.apiValidationPending || self.validationGeneration != generation) return;
            self.apiValidated = success;
            self.packageName = package.length ? package : @"—";
            self.duration = FFLicenseDisplayExpiry(expiry);
            self.status = success ? @"ATIVA" : @"NÃO VALIDADA";
            self.apiValidationPending = NO;
            self.pendingApplyAuthorizations = 0;
            completions = [self.validationCompletions copy];
            [self.validationCompletions removeAllObjects];
        }

        FFLog(@"auth: package validation %@", success ? @"OK" : @"failed");
        [[NSNotificationCenter defaultCenter] postNotificationName:FFLicenseDidUpdateNotification object:self];
        for (id item in completions) {
            void (^callback)(BOOL) = item;
            callback(success);
        }
    });
}

- (void)authorizeOperationWithCompletion:(void (^)(BOOL))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL authorized = NO;
        @synchronized (self) {
            // The SDK owns ongoing package/key enforcement after its initial login.
            // Starting paid() again here creates a second interactive login session.
            authorized = self.apiValidated && !self.apiValidationPending;
            self.pendingApplyAuthorizations = authorized ? 1 : 0;
        }
        if (completion) completion(authorized);
    });
}

- (BOOL)consumeApplyAuthorization {
    @synchronized (self) {
        if (!self.apiValidated || self.pendingApplyAuthorizations == 0) return NO;
        self.pendingApplyAuthorizations -= 1;
        return YES;
    }
}

- (void)revokeApplyAuthorization {
    @synchronized (self) {
        self.pendingApplyAuthorizations = 0;
    }
}

- (NSString *)summaryText {
    return [NSString stringWithFormat:@"%@ · %@ · %@", self.packageName, self.status, self.duration];
}

@end
