

#import <UIKit/UIKit.h>
#import <stdlib.h>

#import "FFAppDelegate.h"
#import "FFCore.h"

__attribute__((constructor))
static void FFPatchDylibLoaded(void) {

    if (getenv("FFPATCH_INJECTED") != NULL) {
        FFLog(@"entry: dylib injetada no processo host (modo injeção)");
    }
}

__attribute__((visibility("default"), used))
int FFAppMain(int argc, char *argv[]) {
    @autoreleasepool {
        FFLog(@"entry: FFAppMain — subindo UIApplicationMain (ObjC/UIKit)");
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([FFAppDelegate class]));
    }
}
