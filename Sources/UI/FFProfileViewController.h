

#ifndef FF_PROFILE_VIEW_CONTROLLER_H
#define FF_PROFILE_VIEW_CONTROLLER_H

#import <UIKit/UIKit.h>

@class FFManifest;

@interface FFProfileViewController : UIViewController

- (instancetype)initWithManifest:(FFManifest *)manifest;

@end

#endif
