//
//  FFLicense.m
//  FFPatch
//

#import "FFLicense.h"
#import "FFCore.h"
#import "FFSandbox.h"
#import "Vendor/LogosAPI/APIClient.h"

NSNotificationName const FFLicenseDidUpdateNotification = @"FFLicenseDidUpdateNotification";

static NSString *FFLicenseStringFromAPI(const char *value) {
    if (value == NULL || value[0] == '\0') return nil;
    NSString *result = [NSString stringWithUTF8String:value];
    return result.length ? result : nil;
}

@interface FFLicense ()
@property (nonatomic, assign, readwrite) BOOL apiValidated;
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

    return license;
}

- (void)startWithCompletion:(dispatch_block_t)completion {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            apiclient_set_token("YkSXOtvqlVQy/9oPcI7bv1rTn2fveQzSGfqdvg5f20CNi0nwolEDstMEOrlEsxHyiUUj4M/7hRwYD6VApIf9c3kkgQYy6dWE/B69+eT5F0g=");
            apiclient_set_language("en");
            apiclient_paid(^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.apiValidated = YES;
                    self.status = @"ATIVA";
                    self.key = FFLicenseStringFromAPI(apiclient_get_key()) ?: @"";
                    self.packageName = FFLicenseStringFromAPI(apiclient_get_package_name()) ?: @"—";
                    self.duration = FFLicenseStringFromAPI(apiclient_get_expired_at_local())
                        ?: FFLicenseStringFromAPI(apiclient_get_expired_at()) ?: @"—";
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:FFLicenseDidUpdateNotification object:self];
                    if (completion) completion();
                });
            });
        });
    });
}

- (NSString *)summaryText {
    return [NSString stringWithFormat:@"%@ · %@ · %@", self.packageName, self.status, self.duration];
}

@end
