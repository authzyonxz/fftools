//
//  FFAppDelegate.m
//  FFPatch
//

#import "FFAppDelegate.h"
#import "FFCore.h"
#import "FFSandbox.h"
#import "FFManifest.h"
#import "FFPatchEngine.h"
#import "FFHomeViewController.h"
#import "FFProfileViewController.h"
#import "FFWidgets.h"

@interface FFAppDelegate ()
@property (nonatomic, strong) UIActivityIndicatorView *bootSpinner;
@end

@implementation FFAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    FFLog(@"boot: FFPatch acessando o hardware. iOS %@ build %@ model %@",
          FFOSVersionString(), FFOSBuildString(), FFDeviceModelIdentifier());

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor blackColor];

    NSError *manifestError = nil;
    FFManifest *manifest = [FFManifest loadFromBundle:nil error:&manifestError];
    self.manifest = manifest;

    if (manifest == nil) {
        [self presentFatalMessage:[NSString stringWithFormat:@"manifesto de payload ausente ou inválido:\n%@",
                                   manifestError.localizedDescription ?: @"erro desconhecido"]];
        [self.window makeKeyAndVisible];
        [self warmUpSandboxBackend];
        return YES;
    }

    UIViewController *root = [self buildRootWithManifest:manifest];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];

    [self warmUpSandboxBackend];
    return YES;
}

- (UIViewController *)buildRootWithManifest:(FFManifest *)manifest {
    UITabBarController *tabs = [UITabBarController new];

    FFHomeViewController *home = [[FFHomeViewController alloc] initWithManifest:manifest];
    UINavigationController *homeNavigation = [[UINavigationController alloc] initWithRootViewController:home];

    FFProfileViewController *profile = [[FFProfileViewController alloc] initWithManifest:manifest];
    UINavigationController *profileNavigation = [[UINavigationController alloc] initWithRootViewController:profile];

    tabs.viewControllers = @[homeNavigation, profileNavigation];

    UITabBarItem *homeItem = [[UITabBarItem alloc] initWithTitle:@"Início"
        image:[UIImage systemImageNamed:@"house"] selectedImage:[UIImage systemImageNamed:@"house.fill"]];
    UITabBarItem *profileItem = [[UITabBarItem alloc] initWithTitle:@"Perfil"
        image:[UIImage systemImageNamed:@"person"] selectedImage:[UIImage systemImageNamed:@"person.fill"]];
    home.tabBarItem = homeItem;
    profile.tabBarItem = profileItem;

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

- (void)presentFatalMessage:(NSString *)message {
    UIViewController *controller = [UIViewController new];
    controller.view.backgroundColor = [UIColor blackColor];

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = message;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    [controller.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor],
        [label.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor constant:24],
        [label.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor constant:-24],
    ]];
    self.window.rootViewController = controller;
}

- (void)warmUpSandboxBackend {
    // bad_query / worse_query activation is an API call, not an exploit: warm
    // it up silently so the first toggle is not delayed. The kernel backend is
    // deliberately left alone — it takes 10–30 s and needs the Unlock button.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        if (!FFSandboxOSIsSupported()) {
            FFLog(@"boot: sistema não suportado — %@", FFSandboxUnsupportedReason());
            return;
        }
        if (FFSandboxCurrentBackend() == FFSandboxBackendKernel) {
            FFLog(@"boot: backend kernel — aguardando desbloqueio manual");
            return;
        }
        NSString *detail = nil;
        BOOL ok = FFSandboxActivate(&detail);
        FFLog(@"boot: warm-up %@ — %@", ok ? @"OK" : @"FALHOU", detail ?: @"sem detalhe");
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
