//
//  FFAppDelegate.m
//  FFPatch
//

#import "FFAppDelegate.h"
#import "FFCore.h"
#import "FFSandbox.h"
#import "FFProtect.h"
#import "FFManifest.h"
#import "FFCatalogClient.h"
#import "FFPatchEngine.h"
#import "FFHomeViewController.h"
#import "FFProfileViewController.h"
#import "FFWidgets.h"
#import "FFTheme.h"
#import "FFLicense.h"

@interface FFAppDelegate ()
@property (nonatomic, strong) UITabBarController *tabs;
@property (nonatomic, strong) UIViewController *loadingController;
@property (nonatomic, strong) FFCatalogResult *lastResult;
@property (nonatomic, assign) BOOL syncing;
@property (nonatomic, assign) BOOL startupServicesStarted;
- (void)handleAuthorizationResult:(BOOL)isValid;
- (void)showAccessBlocked;
- (void)retryAPIAuthorization;
@end

@implementation FFAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    FFProtectInstall();
    FFLog(@"boot: External iniciando. iOS %@ build %@ model %@ backend %@",
          FFOSVersionString(), FFOSBuildString(), FFDeviceModelIdentifier(),
          FFSandboxBackendNameCurrent());

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor blackColor];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(catalogSynced:)
                                                 name:FFCatalogDidSyncNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(syncRequested:)
                                                 name:@"FFCatalogSyncRequestNotification"
                                               object:nil];

    [self showLoadingWithText:@"inicializando API"];
    [self.window makeKeyAndVisible];

    [[FFLicense current] validateWithCompletion:^(BOOL isValid) {
        [self handleAuthorizationResult:isValid];
    }];
    return YES;
}

#pragma mark - Catalogue

- (void)showLoadingWithText:(NSString *)text {
    UIViewController *controller = [UIViewController new];
    controller.view.backgroundColor = [UIColor blackColor];

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.color = [UIColor whiteColor];
    [spinner startAnimating];

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"EXTERNAL";
    label.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;

    UILabel *detail = [UILabel new];
    detail.translatesAutoresizingMaskIntoConstraints = NO;
    detail.text = text;
    detail.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    detail.textColor = [FFTheme secondaryText];
    detail.textAlignment = NSTextAlignmentCenter;

    [controller.view addSubview:spinner];
    [controller.view addSubview:label];
    [controller.view addSubview:detail];
    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor constant:-30],
        [label.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
        [label.topAnchor constraintEqualToAnchor:spinner.bottomAnchor constant:18],
        [detail.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
        [detail.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:6],
        [detail.leadingAnchor constraintGreaterThanOrEqualToAnchor:controller.view.leadingAnchor constant:24],
        [detail.trailingAnchor constraintLessThanOrEqualToAnchor:controller.view.trailingAnchor constant:-24],
    ]];

    self.loadingController = controller;
    self.window.rootViewController = controller;
}

- (void)showAccessBlocked {
    UIViewController *controller = [UIViewController new];
    controller.view.backgroundColor = [UIColor blackColor];

    UILabel *brand = [UILabel new];
    brand.translatesAutoresizingMaskIntoConstraints = NO;
    brand.text = @"EXTERNAL";
    brand.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    brand.textColor = [UIColor whiteColor];
    brand.textAlignment = NSTextAlignmentCenter;

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Acesso não validado";
    title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightSemibold];
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *detail = [UILabel new];
    detail.translatesAutoresizingMaskIntoConstraints = NO;
    detail.text = @"Não foi possível validar o acesso. Confira sua conexão e tente novamente.";
    detail.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    detail.textColor = [FFTheme secondaryText];
    detail.textAlignment = NSTextAlignmentCenter;
    detail.numberOfLines = 0;

    UIButton *retry = [UIButton buttonWithType:UIButtonTypeSystem];
    retry.translatesAutoresizingMaskIntoConstraints = NO;
    [retry setTitle:@"Tentar novamente" forState:UIControlStateNormal];
    [retry setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    retry.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    retry.backgroundColor = [FFTheme accent];
    retry.layer.cornerRadius = 12;
    [retry addTarget:self action:@selector(retryAPIAuthorization)
        forControlEvents:UIControlEventTouchUpInside];

    [controller.view addSubview:brand];
    [controller.view addSubview:title];
    [controller.view addSubview:detail];
    [controller.view addSubview:retry];
    [NSLayoutConstraint activateConstraints:@[
        [brand.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
        [brand.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor constant:-100],
        [title.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
        [title.topAnchor constraintEqualToAnchor:brand.bottomAnchor constant:28],
        [detail.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
        [detail.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10],
        [detail.leadingAnchor constraintGreaterThanOrEqualToAnchor:controller.view.leadingAnchor constant:32],
        [detail.trailingAnchor constraintLessThanOrEqualToAnchor:controller.view.trailingAnchor constant:-32],
        [retry.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
        [retry.topAnchor constraintEqualToAnchor:detail.bottomAnchor constant:24],
        [retry.widthAnchor constraintGreaterThanOrEqualToConstant:190],
        [retry.heightAnchor constraintEqualToConstant:48],
    ]];

    self.loadingController = controller;
    self.window.rootViewController = controller;
}

- (void)retryAPIAuthorization {
    [self showLoadingWithText:@"validando acesso"];
    [[FFLicense current] validateWithCompletion:^(BOOL isValid) {
        [self handleAuthorizationResult:isValid];
    }];
}

- (void)handleAuthorizationResult:(BOOL)isValid {
    if (!isValid) {
        [self showAccessBlocked];
        return;
    }
    if (self.startupServicesStarted) return;

    self.startupServicesStarted = YES;
    [self showLoadingWithText:@"sincronizando catálogo"];
    [self startCatalogSyncWithTimeout:12.0];
    [self startSandboxInBackground];
}

- (void)startCatalogSyncWithTimeout:(NSTimeInterval)timeout {
    if (![FFLicense current].apiValidated) return;
    if (self.syncing) return;
    self.syncing = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        FFCatalogResult *result = [[FFCatalogClient sharedClient] syncWithTimeout:timeout];
        self.syncing = NO;
        self.lastResult = result;
        [[NSNotificationCenter defaultCenter] postNotificationName:FFCatalogDidSyncNotification
                                                            object:result];
    });
}

- (void)catalogSynced:(NSNotification *)notification {
    if (![FFLicense current].apiValidated) return;
    FFCatalogResult *result = [notification.object isKindOfClass:[FFCatalogResult class]]
        ? (FFCatalogResult *)notification.object : self.lastResult;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self installRootWithManifest:result.manifest result:result];
    });
}

- (void)syncRequested:(NSNotification *)notification {
    if (![FFLicense current].apiValidated) return;
    [self startCatalogSyncWithTimeout:15.0];
}

- (void)installRootWithManifest:(FFManifest *)manifest result:(FFCatalogResult *)result {
    if (![FFLicense current].apiValidated) return;
    if (manifest == nil) manifest = [FFManifest emptyManifest];
    [FFPatchEngine sharedEngine].manifest = manifest;

    NSUInteger previousIndex = self.tabs.selectedIndex;
    UITabBarController *tabs = [self buildRootWithManifest:manifest];
    if (self.tabs != nil && previousIndex < tabs.viewControllers.count) {
        tabs.selectedIndex = previousIndex;
    }
    self.tabs = tabs;

    self.window.rootViewController = tabs;

    if (result != nil) {
        FFLog(@"catalog: instalado v%@ · %lu grupo(s) · cache=%d · erro=%@",
              result.catalogVersion ?: @"—",
              (unsigned long)manifest.groups.count,
              (int)result.fromCache,
              result.error.localizedDescription ?: @"nenhum");
    }
}

#pragma mark - Root UI

- (UITabBarController *)buildRootWithManifest:(FFManifest *)manifest {
    UITabBarController *tabs = [UITabBarController new];

    FFHomeViewController *home = [[FFHomeViewController alloc] initWithManifest:manifest];
    UINavigationController *homeNavigation = [[UINavigationController alloc] initWithRootViewController:home];

    FFProfileViewController *profile = [[FFProfileViewController alloc] initWithManifest:manifest];
    UINavigationController *profileNavigation = [[UINavigationController alloc] initWithRootViewController:profile];

    tabs.viewControllers = @[homeNavigation, profileNavigation];

    home.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Início"
        image:[UIImage systemImageNamed:@"square.grid.2x2"]
        selectedImage:[UIImage systemImageNamed:@"square.grid.2x2.fill"]];
    profile.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Perfil"
        image:[UIImage systemImageNamed:@"person"]
        selectedImage:[UIImage systemImageNamed:@"person.fill"]];

    [self applyChrome];
    return tabs;
}

- (void)applyChrome {
    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *tabAppearance = [UITabBarAppearance new];
        [tabAppearance configureWithOpaqueBackground];
        tabAppearance.backgroundColor = [UIColor blackColor];
        tabAppearance.shadowColor = [UIColor clearColor];
        [tabAppearance.stackedLayoutAppearance.normal setIconColor:[UIColor colorWithWhite:1.0 alpha:0.45]];
        [tabAppearance.stackedLayoutAppearance.normal setTitleTextAttributes:
            @{NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.45]}];
        [tabAppearance.stackedLayoutAppearance.selected setIconColor:[UIColor whiteColor]];
        [tabAppearance.stackedLayoutAppearance.selected setTitleTextAttributes:
            @{NSForegroundColorAttributeName: [UIColor whiteColor]}];

        UINavigationBarAppearance *navigationAppearance = [UINavigationBarAppearance new];
        [navigationAppearance configureWithOpaqueBackground];
        navigationAppearance.backgroundColor = [UIColor blackColor];
        navigationAppearance.shadowColor = [UIColor clearColor];
        navigationAppearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};

        [UITabBar appearance].standardAppearance = tabAppearance;
        if (@available(iOS 15.0, *)) {
            [UITabBar appearance].scrollEdgeAppearance = tabAppearance;
        }
        [UINavigationBar appearance].standardAppearance = navigationAppearance;
        [UINavigationBar appearance].scrollEdgeAppearance = navigationAppearance;
        [UINavigationBar appearance].compactAppearance = navigationAppearance;
    } else {
        [UITabBar appearance].barTintColor = [UIColor blackColor];
        [UINavigationBar appearance].barTintColor = [UIColor blackColor];
        [UINavigationBar appearance].titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    }
    [UITabBar appearance].tintColor = [UIColor whiteColor];
}

#pragma mark - Sandbox

- (void)startSandboxInBackground {
    if (![FFLicense current].apiValidated) return;
    // Every backend starts on its own, silently:
    //   kernel (iOS 17/18) → kexploit_opa334 + sandbox_escape, 10–30 s
    //   bad_query (26.0–26.6.1) / worse_query (26.7+/27) → grant probe
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (![FFLicense current].apiValidated) return;
        if (!FFSandboxOSIsSupported()) {
            FFLog(@"boot: sistema não suportado — %@", FFSandboxUnsupportedReason());
            return;
        }
        NSString *detail = nil;
        BOOL ok = FFSandboxActivate(&detail);
        FFLog(@"boot: backend %@ iniciado — %@ (%@)",
              FFSandboxBackendNameCurrent(), ok ? @"OK" : @"FALHOU", detail ?: @"sem detalhe");
    });
}

#pragma mark - Chrome

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application
    supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskPortrait;
}

@end
