#import "KAExternalClient.h"
#import "KASecurity.h"
#import "KAPolicy.h"
#import <UIKit/UIKit.h>

@interface KAExternalClient () <NSURLSessionTaskDelegate>
@property(nonatomic) dispatch_queue_t worker;
@property(nonatomic) NSURLSession *network;
@property(nonatomic) NSString *sessionToken;
@property(nonatomic) NSString *grant;
@property(nonatomic) NSString *activeLicense;
@property(nonatomic) NSString *installationID;
@property(nonatomic) NSTimeInterval deadline;
@property(atomic) NSUInteger generation;
@end

@implementation KAExternalClient
- (instancetype)init {
    if ((self = [super init])) {
        _worker = dispatch_queue_create("org.keyauthv2.external.worker", DISPATCH_QUEUE_SERIAL);
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        config.URLCache = nil; config.HTTPCookieStorage = nil;
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 20;
        config.TLSMinimumSupportedProtocolVersion = tls_protocol_version_TLSv12;
        _network = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(invalidate) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}
// Never follow a redirect carrying license/session material, even on the same origin.
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
 willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler { completionHandler(nil); }
// Default platform TLS trust remains enabled. No "accept all certificates" delegate.
- (NSDictionary *)post:(NSString *)path body:(NSDictionary *)body error:(NSError **)error {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"https://keyauthv2.org/api/v2" stringByAppendingString:path]]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:error];
    if (!request.HTTPBody) return nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSData *bytes = nil; __block NSHTTPURLResponse *http = nil; __block NSError *failure = nil;
    NSURLSessionDataTask *task = [self.network dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {
        bytes = data; http = [response isKindOfClass:NSHTTPURLResponse.class] ? (id)response : nil;
        failure = networkError; dispatch_semaphore_signal(done);
    }];
    [task resume];
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 21 * NSEC_PER_SEC)) != 0) {
        [task cancel]; if (error) *error = KAError(@"NETWORK"); return nil;
    }
    if (failure || !http) { if (error) *error = KAError(@"NETWORK"); return nil; }
    if (http.statusCode == 429) { if (error) *error = KAError(@"RATE_LIMITED"); return nil; }
    if (bytes.length == 0 || bytes.length > 65536 || ![http.MIMEType.lowercaseString isEqual:@"application/json"]) {
        if (error) *error = KAError(@"INVALID_RESPONSE"); return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:bytes options:0 error:NULL];
    if (![object isKindOfClass:NSDictionary.class]) { if (error) *error = KAError(@"INVALID_RESPONSE"); return nil; }
    NSDictionary *json = object;
    if (![json[@"ok"] isEqual:@YES] || http.statusCode != 200) {
        id apiError = json[@"error"];
        NSString *code = [apiError isKindOfClass:NSDictionary.class] && [apiError[@"code"] isKindOfClass:NSString.class] ? apiError[@"code"] : @"INVALID_RESPONSE";
        if (error) *error = KAError(code); return nil;
    }
    if (![json[@"data"] isKindOfClass:NSDictionary.class]) { if (error) *error = KAError(@"INVALID_RESPONSE"); return nil; }
    return json[@"data"];
}
- (void)clearSession { self.grant = nil; self.sessionToken = nil; self.deadline = 0; self.activeLicense = nil; }
- (void)invalidate {
    NSAssert(NSThread.isMainThread, @"Use the main thread");
    self.generation += 1;
    dispatch_async(self.worker, ^{ [self clearSession]; });
    [[NSNotificationCenter defaultCenter] postNotificationName:KAExternalDidLockNotification object:self userInfo:@{@"allowAutomatic":@YES}];
}
- (void)forgetLicense {
    [self invalidate]; dispatch_async(self.worker, ^{ KADeleteLicense(); });
}
- (void)deliver:(KACompletion)completion value:(NSDictionary *)value error:(NSError *)error generation:(NSUInteger)generation {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.generation != generation) { completion(nil, KAError(@"CANCELLED")); return; }
        completion(value, error);
    });
}
- (NSDictionary *)completeChallenge:(NSString *)purpose key:(SecKeyRef)key
                           license:(NSString *)license error:(NSError **)error {
    NSString *path = [purpose isEqual:@"enrollment"] ? @"/installations/challenge" : @"/authorization/challenge";
    NSMutableDictionary *body = [@{@"token":self.sessionToken, @"package":@"external1", @"installationId":self.installationID} mutableCopy];
    if ([purpose isEqual:@"enrollment"]) {
        SecKeyRef pub = SecKeyCopyPublicKey(key);
        NSData *raw = pub ? CFBridgingRelease(SecKeyCopyExternalRepresentation(pub, NULL)) : nil;
        if (pub) CFRelease(pub);
        if (raw.length != 65) { if (error) *error = KAError(@"SECURE_KEY"); return nil; }
        body[@"publicKey"] = KAB64(raw);
    }
    NSDictionary *challenge = [self post:path body:body error:error]; if (!challenge) return nil;
    NSString *canonical = challenge[@"canonical"];
    if (![canonical isKindOfClass:NSString.class] || canonical.length > 8192 ||
        ![challenge[@"challengeId"] isKindOfClass:NSString.class] || ![challenge[@"challenge"] isKindOfClass:NSString.class] ||
        ![challenge[@"expiresAt"] isKindOfClass:NSNumber.class] || [challenge[@"expiresAt"] doubleValue] <= NSDate.date.timeIntervalSince1970) {
        if (error) *error = KAError(@"CHALLENGE_INVALID"); return nil;
    }
    NSData *message = [canonical dataUsingEncoding:NSUTF8StringEncoding];
    id fields = [NSJSONSerialization JSONObjectWithData:message options:0 error:NULL];
    if (![fields isKindOfClass:NSDictionary.class] || ![fields[@"purpose"] isEqual:purpose] ||
        ![fields[@"package"] isEqual:@"external1"] || ![fields[@"installationId"] isEqual:self.installationID] ||
        ![fields[@"challengeId"] isEqual:challenge[@"challengeId"]] || ![fields[@"challenge"] isEqual:challenge[@"challenge"]] ||
        ![fields[@"sessionHash"] isEqual:KAB64(KAHash([self.sessionToken dataUsingEncoding:NSUTF8StringEncoding]))]) {
        if (error) *error = KAError(@"CHALLENGE_INVALID"); return nil;
    }
    // Sign exact UTF-8 canonical bytes, not a reserialized JSON dictionary.
    NSData *signature = CFBridgingRelease(SecKeyCreateSignature(key, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, (__bridge CFDataRef)message, NULL));
    if (!signature) { if (error) *error = KAError(@"SECURE_KEY"); return nil; }
    NSMutableDictionary *proof = [@{@"token":self.sessionToken, @"challengeId":challenge[@"challengeId"],
        @"challenge":challenge[@"challenge"], @"signature":KAB64(signature)} mutableCopy];
    if (license) proof[@"key"] = license;
    return [self post:[purpose isEqual:@"enrollment"] ? @"/installations/complete" : @"/authorization/issue" body:proof error:error];
}
- (NSDictionary *)validateCurrent:(NSError **)error {
    if (!self.grant || !self.sessionToken || NSProcessInfo.processInfo.systemUptime >= self.deadline) {
        if (error) *error = KAError(@"SESSION_EXPIRED"); return nil;
    }
    NSDictionary *claims = KAVerifyGrant(self.grant, self.sessionToken, self.installationID, error);
    if (!claims) return nil;
    NSDictionary *result = [self post:@"/grant/introspect" body:@{@"token":self.sessionToken,@"grant":self.grant} error:error];
    if (!result) return nil;
    NSDictionary *returned = [result[@"claims"] isKindOfClass:NSDictionary.class] ? result[@"claims"] : nil;
    NSDictionary *license = [result[@"license"] isKindOfClass:NSDictionary.class] ? result[@"license"] : nil;
    BOOL expiryTyped = [license[@"expiresAt"] isKindOfClass:NSNumber.class];
    unsigned long long flags = ([result[@"active"] isEqual:@YES] ? 1 : 0) |
        ([returned isEqualToDictionary:claims] ? 2 : 0) | (license ? 4 : 0) | (expiryTyped ? 8 : 0);
    if (!KAPolicyAccept(flags, expiryTyped ? [license[@"expiresAt"] unsignedLongLongValue] : 0,
        (unsigned long long)(NSDate.date.timeIntervalSince1970 * 1000),
        (unsigned long long)(self.deadline * 1000), (unsigned long long)(NSProcessInfo.processInfo.systemUptime * 1000))) {
        if (error) *error = KAError(@"GRANT_INACTIVE"); return nil;
    }
    return license;
}
- (void)loginWithLicense:(NSString *)license remember:(BOOL)remember completion:(KACompletion)completion {
    NSAssert(NSThread.isMainThread, @"Use the main thread");
    NSUInteger generation = ++self.generation;
    dispatch_async(self.worker, ^{
        [self clearSession]; NSError *error = nil;
        NSString *normalized = [[[license uppercaseString] componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsJoinedByString:@""];
        if (normalized.length == 0) normalized = KAReadLicense(&error);
        if (!normalized.length) { [self deliver:completion value:nil error:error ?: KAError(@"KEY_REQUIRED") generation:generation]; return; }
        NSRegularExpression *format = [NSRegularExpression regularExpressionWithPattern:@"^[A-Z1-9]{15}$" options:0 error:NULL];
        if ([format numberOfMatchesInString:normalized options:0 range:NSMakeRange(0, normalized.length)] != 1) {
            [self deliver:completion value:nil error:KAError(@"KEY_FORMAT") generation:generation]; return;
        }
        SecKeyRef key = KACopyDeviceKey(&error);
        if (!key) { [self deliver:completion value:nil error:error generation:generation]; return; }
        SecKeyRef pub = SecKeyCopyPublicKey(key);
        NSData *raw = pub ? CFBridgingRelease(SecKeyCopyExternalRepresentation(pub, NULL)) : nil;
        if (pub) CFRelease(pub);
        self.installationID = raw ? KAB64(KAHash(raw)) : nil;
        NSDictionary *start = self.installationID ? [self post:@"/device/session/start" body:@{@"package":@"external1"} error:&error] : nil;
        if (![start[@"token"] isKindOfClass:NSString.class] || [start[@"token"] length] < 20 || ![start[@"expiresAt"] isKindOfClass:NSNumber.class]) {
            CFRelease(key); [self deliver:completion value:nil error:error ?: KAError(@"INVALID_RESPONSE") generation:generation]; return;
        }
        self.sessionToken = start[@"token"];
        NSDictionary *enrollment = [self completeChallenge:@"enrollment" key:key license:nil error:&error];
        NSDictionary *issued = nil;
        if ([enrollment[@"completed"] isEqual:@YES]) issued = [self completeChallenge:@"authorization" key:key license:normalized error:&error];
        CFRelease(key);
        if (![issued[@"grant"] isKindOfClass:NSString.class]) {
            [self clearSession]; [self deliver:completion value:nil error:error ?: KAError(@"INVALID_RESPONSE") generation:generation]; return;
        }
        self.grant = issued[@"grant"];
        NSDictionary *claims = KAVerifyGrant(self.grant, self.sessionToken, self.installationID, &error);
        if (claims && ![claims[@"key"] isEqual:normalized]) { claims = nil; error = KAError(@"GRANT_INVALID"); }
        double seconds = MIN([start[@"expiresAt"] doubleValue], [claims[@"exp"] doubleValue]) - NSDate.date.timeIntervalSince1970;
        self.deadline = NSProcessInfo.processInfo.systemUptime + MAX(0, MIN(300, seconds));
        NSDictionary *result = claims ? [self validateCurrent:&error] : nil;
        if (self.generation != generation) { result = nil; error = KAError(@"CANCELLED"); }
        if (result && remember && !KASaveLicense(normalized, &error)) result = nil;
        if (result && !remember) KADeleteLicense();
        if (result) self.activeLicense = normalized;
        if (!result) {
            if ([@[@"KEY_INVALID",@"KEY_EXPIRED",@"DEVICE_MISMATCH"] containsObject:error.userInfo[@"apiCode"]]) KADeleteLicense();
            [self clearSession];
        }
        [self deliver:completion value:result error:error generation:generation];
    });
}
- (void)authorizeOperation:(KACompletion)completion {
    NSAssert(NSThread.isMainThread, @"Use the main thread");
    NSUInteger generation = self.generation;
    dispatch_async(self.worker, ^{
        NSError *error = nil;
        NSDictionary *result = nil;
        if (self.activeLicense.length && self.sessionToken && NSProcessInfo.processInfo.systemUptime < self.deadline) {
            SecKeyRef key = KACopyDeviceKey(&error);
            NSDictionary *issued = key ? [self completeChallenge:@"authorization" key:key license:self.activeLicense error:&error] : nil;
            if (key) CFRelease(key);
            NSString *fresh = [issued[@"grant"] isKindOfClass:NSString.class] ? issued[@"grant"] : nil;
            NSDictionary *claims = fresh ? KAVerifyGrant(fresh,self.sessionToken,self.installationID,&error) : nil;
            if (claims && [claims[@"key"] isEqual:self.activeLicense] && ![fresh isEqual:self.grant]) {
                self.grant = fresh;
                result = [self validateCurrent:&error];
            } else if (!error) error = KAError(@"GRANT_INVALID");
        } else error = KAError(@"SESSION_EXPIRED");
        if (!result) [self failClosed:error generation:generation];
        [self deliver:completion value:result error:error generation:generation];
    });
}
- (void)failClosed:(NSError *)error generation:(NSUInteger)generation {
    [self clearSession];
    NSString *code = error.userInfo[@"apiCode"];
    BOOL terminal = [@[@"KEY_INVALID",@"KEY_EXPIRED",@"DEVICE_MISMATCH",@"GRANT_INACTIVE"] containsObject:code];
    if (terminal) KADeleteLicense();
    BOOL retry = [@[@"SESSION_EXPIRED",@"SESSION_NOT_FOUND"] containsObject:code];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.generation != generation) return;
        self.generation += 1;
        [[NSNotificationCenter defaultCenter] postNotificationName:KAExternalDidLockNotification object:self
            userInfo:@{@"error":error ?: KAError(@"GRANT_INVALID"),@"allowAutomatic":@(retry)}];
    });
}
- (void)revalidate:(KACompletion)completion {
    NSAssert(NSThread.isMainThread, @"Use the main thread");
    NSUInteger generation = self.generation;
    dispatch_async(self.worker, ^{
        NSError *error = nil; NSDictionary *result = [self validateCurrent:&error];
        if (!result) [self failClosed:error generation:generation];
        [self deliver:completion value:result error:error generation:generation];
    });
}
- (void)requestForFunction:(NSString *)functionID original:(BOOL)original completion:(void (^)(NSURLRequest *, NSError *))completion {
    NSRegularExpression *format = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9_-]{1,80}$" options:0 error:NULL];
    if ([format numberOfMatchesInString:functionID options:0 range:NSMakeRange(0,functionID.length)] != 1) { completion(nil, KAError(@"INVALID_RESPONSE")); return; }
    [self revalidate:^(NSDictionary *license, NSError *error) {
        if (error) { completion(nil,error); return; }
        // Main-thread callback: take a snapshot on worker to avoid a concurrent invalidate/login race.
        NSUInteger generation = self.generation;
        dispatch_async(self.worker, ^{
            NSMutableURLRequest *request = nil;
            if (self.generation == generation && self.grant && self.sessionToken && NSProcessInfo.processInfo.systemUptime < self.deadline) {
                request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://keyauthv2.org/api/v1/functions/%@/%@",functionID,original ? @"original" : @"payload"]]];
                [request setValue:[@"Bearer " stringByAppendingString:self.grant] forHTTPHeaderField:@"Authorization"];
                [request setValue:self.sessionToken forHTTPHeaderField:@"X-KeyAuth-Session"];
                request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
            }
            dispatch_async(dispatch_get_main_queue(), ^{ completion(self.generation == generation ? request : nil, request && self.generation == generation ? nil : KAError(@"SESSION_EXPIRED")); });
        });
    }];
}
@end
