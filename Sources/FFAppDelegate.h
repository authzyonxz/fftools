

#ifndef FF_APP_DELEGATE_H
#define FF_APP_DELEGATE_H

#import <UIKit/UIKit.h>

@class FFManifest;

@interface FFAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, readonly, nullable) UIView *overlayContainerView;
@property (nonatomic, strong, nullable) FFManifest *manifest;

@end

int FFAppMain(int argc, char *argv[]);

#endif
