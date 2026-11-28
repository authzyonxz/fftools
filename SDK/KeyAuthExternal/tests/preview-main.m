#import <UIKit/UIKit.h>
#import "KALicenseViewController.h"
@interface PreviewDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic) UIWindow *window;
@end
@implementation PreviewDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[KAProtectedRootController alloc] initWithContentFactory:^UIViewController *(KAExternalClient *client, NSDictionary *license) {
        UIViewController *controller = [UIViewController new]; controller.view.backgroundColor = UIColor.blackColor;
        return controller;
    }];
    [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int argc,char **argv) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(PreviewDelegate.class)); } }
