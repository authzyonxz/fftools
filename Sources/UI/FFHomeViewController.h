

#ifndef FF_HOME_VIEW_CONTROLLER_H
#define FF_HOME_VIEW_CONTROLLER_H

#import <UIKit/UIKit.h>

@class FFManifest;

@interface FFHomeViewController : UIViewController

- (instancetype)initWithManifest:(FFManifest *)manifest;

- (void)reloadState;

@end

#endif
