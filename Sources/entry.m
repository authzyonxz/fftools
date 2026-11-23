//
//  entry.m
//  FFPatch — the dylib side of the launcher handshake.
//
//  The IPA's MH_EXECUTE binary is launcher/main.c. It dlopens this dylib and
//  calls FFAppMain(), so every line of app logic below ships inside
//  ffpatch.dylib — no Swift, no SwiftUI, no Combine anywhere in the target.
//

#import <UIKit/UIKit.h>
#import <stdlib.h>

#import "FFAppDelegate.h"
#import "FFCore.h"

__attribute__((constructor))
static void FFPatchDylibLoaded(void) {
    // Cheap, side-effect free: proves the dylib got mapped before the stub asks
    // for the entry point, and leaves a breadcrumb for crash reports.
    if (getenv("FFPATCH_INJECTED") != NULL) {
        FFLog(@"entry: dylib injetada no processo host (modo injeção)");
    }
}

int FFAppMain(int argc, char *argv[]) {
    @autoreleasepool {
        FFLog(@"entry: FFAppMain — subindo UIApplicationMain (ObjC/UIKit)");
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([FFAppDelegate class]));
    }
}
