

#ifndef FF_THEME_H
#define FF_THEME_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFTheme : NSObject

+ (UIColor *)background;
+ (UIColor *)card;
+ (UIColor *)cardElevated;
+ (UIColor *)separator;
+ (UIColor *)primaryText;
+ (UIColor *)secondaryText;
+ (UIColor *)accent;
+ (UIColor *)success;
+ (UIColor *)failure;

+ (void)installBackgroundInView:(UIView *)view;
+ (void)animateEntrance:(UIView *)view;

+ (UIFont *)titleFont;
+ (UIFont *)sectionFont;
+ (UIFont *)rowTitleFont;
+ (UIFont *)rowSubtitleFont;
+ (UIFont *)cardLabelFont;
+ (UIFont *)monoFont;

+ (nullable UIWindow *)presentingWindow;

+ (BOOL)attachOverlay:(UIView *)overlay;

@end

NS_ASSUME_NONNULL_END

#endif
