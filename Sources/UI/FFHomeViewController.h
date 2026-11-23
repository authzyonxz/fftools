//
//  FFHomeViewController.h
//  FFPatch — "FUNÇÕES" screen.
//

#ifndef FF_HOME_VIEW_CONTROLLER_H
#define FF_HOME_VIEW_CONTROLLER_H

#import <UIKit/UIKit.h>

@class FFManifest;

@interface FFHomeViewController : UIViewController

- (instancetype)initWithManifest:(FFManifest *)manifest;

/*! Rebuilds every toggle from the engine state (also used after a restore-all). */
- (void)reloadState;

@end

#endif /* FF_HOME_VIEW_CONTROLLER_H */
