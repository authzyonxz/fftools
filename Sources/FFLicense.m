//
//  FFLicense.m
//  FFPatch
//

#import "FFLicense.h"
#import "FFCore.h"
#import "FFSandbox.h"

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

    // Optional per-build license file shipped inside the app bundle.
    NSString *plistPath = [bundle.bundlePath stringByAppendingPathComponent:@"License.plist"];
    NSDictionary *configured = FFReadPlist(plistPath);

    NSString *configuredKey = configured[@"key"];
    license.key = configuredKey.length ? configuredKey : @"FFPT-3107-LOCAL-0000";

    id expiryRaw = configured[@"expiresAt"];
    NSDate *expiry = [expiryRaw isKindOfClass:[NSDate class]] ? (NSDate *)expiryRaw : nil;
    NSString *duration = configured[@"duration"];
    if ([expiry isKindOfClass:[NSDate class]]) {
        NSTimeInterval remaining = [expiry timeIntervalSinceNow];
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.dateFormat = @"dd/MM/yyyy";
        NSString *formatted = [formatter stringFromDate:expiry];
        if (remaining <= 0) {
            license.status = @"EXPIRADA";
            license.duration = [NSString stringWithFormat:@"expirou em %@", formatted];
        } else {
            NSInteger days = (NSInteger)(remaining / 86400.0);
            license.status = days <= 3 ? @"EXPIRANDO" : @"ATIVA";
            license.duration = [NSString stringWithFormat:@"%ld dias restantes — expira em %@",
                                (long)MAX(days, 1), formatted];
        }
    } else {
        license.status = configured[@"status"] ?: @"ATIVA (local)";
        license.duration = duration.length ? duration : @"ilimitada nesta build";
    }

    license.packageName = configured[@"package"]
        ?: bundle.bundleIdentifier
        ?: @"com.external.app";

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

- (NSString *)summaryText {
    return [NSString stringWithFormat:
        @"chave %@ · %@ · %@", self.key, self.status, self.build];
}

@end
