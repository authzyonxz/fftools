//
//  FFLicense.m
//  FFPatch
//

#import "FFLicense.h"
#import "FFCore.h"
#import "FFSandbox.h"
#import "KASecurity.h"

NSNotificationName const FFLicenseDidUpdateNotification = @"FFLicenseDidUpdateNotification";

@interface FFLicense ()
@property (atomic, assign, readwrite) BOOL apiValidated;
@property (nonatomic, strong) KAExternalClient *client;
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
    [[NSNotificationCenter defaultCenter] addObserver:license selector:@selector(didLock:) name:KAExternalDidLockNotification object:nil];
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

- (void)adoptClient:(KAExternalClient *)client license:(NSDictionary *)license {
    self.client = client;
    self.apiValidated = YES;
    self.status = @"ATIVA";
    self.key = @"";
    self.packageName = @"EXTERNAL";
    NSDate *expiry = [NSDate dateWithTimeIntervalSince1970:[license[@"expiresAt"] doubleValue] / 1000.0];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    self.duration = [formatter stringFromDate:expiry];
    [[NSNotificationCenter defaultCenter] postNotificationName:FFLicenseDidUpdateNotification object:self];
}

- (void)didLock:(NSNotification *)notification {
    if (notification.object != self.client) return;
    self.apiValidated = NO;
    self.status = @"VALIDAÇÃO NECESSÁRIA";
    [[NSNotificationCenter defaultCenter] postNotificationName:FFLicenseDidUpdateNotification object:self];
}

- (BOOL)ensureAuthorizedWithError:(NSError **)error {
    // Blocking adapter only for existing background operations. Never block UIKit.
    if (NSThread.isMainThread || !self.apiValidated || !self.client) {
        if (error) *error = KAError(@"SESSION_EXPIRED");
        return NO;
    }
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSError *failure = nil;
    __block BOOL valid = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.client authorizeOperation:^(NSDictionary *license, NSError *apiError) {
            failure = apiError;
            valid = license != nil && apiError == nil;
            dispatch_semaphore_signal(done);
        }];
    });
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 70 * NSEC_PER_SEC)) != 0) {
        if (error) *error = KAError(@"NETWORK");
        return NO;
    }
    if (!valid && error) *error = failure ?: KAError(@"SESSION_EXPIRED");
    return valid && self.apiValidated;
}

- (NSString *)summaryText {
    return [NSString stringWithFormat:@"%@ · %@ · %@", self.packageName, self.status, self.duration];
}

@end
