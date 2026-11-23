//
//  FFAppDelegate.h
//  FFPatch
//

#ifndef FF_APP_DELEGATE_H
#define FF_APP_DELEGATE_H

#import <UIKit/UIKit.h>

@class FFManifest;

@interface FFAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong, nullable) FFManifest *manifest;

@end

/*! Entry point exported by the dylib. The MH_EXECUTE stub (launcher/main.c)
    dlopens the dylib and calls this, so the whole app is the dylib. */
int FFAppMain(int argc, char *argv[]);

#endif /* FF_APP_DELEGATE_H */
