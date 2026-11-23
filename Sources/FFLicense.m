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
    if ([unlimitedValues containsObject:normalized]) {
        return @"Ilimitada";
    }

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

@interface FFLicense ()
@property (nonatomic, assign, readwrite) BOOL apiValidated;
@property (nonatomic, assign, readwrite) BOOL apiValidationPending;
@property (nonatomic, strong) NSMutableArray *validationCompletions;
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

    license.key = [configured[@"key"] isKindOfClass:[NSString class]]
        ? configured[@"key"] : @"";
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

- (void)validateWithCompletion:(void (^)(BOOL))completion {
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
        if (completion) [self.validationCompletions addObject:[completion copy]];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:FFLicenseDidUpdateNotification object:self];
    });

    NSString *authPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"APIAuth.plist"];
    NSDictionary *auth = FFReadPlist(authPath);
    NSString *encoded = [auth[@"tokenMasked"] isKindOfClass:[NSString class]] ? auth[@"tokenMasked"] : nil;
    NSData *masked = encoded.length ? [[NSData alloc] initWithBase64EncodedString:encoded options:0] : nil;
    NSData *plain = masked.length ? FFMaskedData(masked.bytes, masked.length) : nil;
    NSString *token = plain.length ? [[NSString alloc] initWithData:plain encoding:NSUTF8StringEncoding] : nil;
    if (token.length == 0) {
        [self finishValidationWithSuccess:NO package:@"—" expiry:@"—"];
        return;
    }

    APIClient *client = [APIClient sharedAPIClient];
    [client setToken:token];
    [client strictMode:YES];
    [client silentMode:YES];
    [client hideUI:YES];

    // Start the Lite client first. The package check runs only from its init callback.
    [client start:^{
        FFLog(@"auth: Logos API Lite starting");
    } init:^{
        FFLog(@"auth: Logos API Lite initialized");
        [client onCheckPackage:^(NSDictionary *header) {
            (void)header;
            NSString *package = [client getPackageName];
            NSString *expiry = FFLicenseDisplayExpiry([client getExpiryDate]);
            [self finishValidationWithSuccess:YES
                                      package:package.length ? package : @"—"
                                       expiry:expiry];
        } onFailure:^(NSDictionary *error) {
            (void)error;
            [self finishValidationWithSuccess:NO package:@"—" expiry:@"—"];
        }];
    }];

    // Do not leave launch waiting forever if the client cannot reach its service.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (self.apiValidationPending) {
            FFLog(@"auth: Logos API Lite timed out");
            [self finishValidationWithSuccess:NO package:@"—" expiry:@"—"];
        }
    });
}

- (void)finishValidationWithSuccess:(BOOL)success package:(NSString *)package expiry:(NSString *)expiry {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *completions = nil;
        @synchronized (self) {
            if (!self.apiValidationPending) return;
            self.apiValidated = success;
            self.packageName = package.length ? package : @"—";
            self.duration = expiry.length ? expiry : @"—";
            self.status = success ? @"ATIVA" : @"NÃO VALIDADA";
            self.apiValidationPending = NO;
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

- (NSString *)summaryText {
    return [NSString stringWithFormat:@"%@ · %@ · %@", self.packageName, self.status, self.duration];
}

@end
