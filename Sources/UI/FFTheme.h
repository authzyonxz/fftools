//
//  FFTheme.h
//  FFPatch — one place for the dark "FUNÇÕES" look.
//
//  Palette and metrics are lifted from the reference screenshot: pure black
//  page, #1C1C1E cards, 14–16 pt corners, white selected outline, grey
//  uppercase section headers, white/red switches.
//

#ifndef FF_THEME_H
#define FF_THEME_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFTheme : NSObject

+ (UIColor *)background;      // #000000
+ (UIColor *)card;            // #1C1C1E
+ (UIColor *)cardElevated;    // #2C2C2E
+ (UIColor *)separator;       // #2C2C2E @ 60%
+ (UIColor *)primaryText;     // #FFFFFF
+ (UIColor *)secondaryText;   // #8E8E93
+ (UIColor *)accent;          // #E23744 (Free Fire red)
+ (UIColor *)success;         // #30D158
+ (UIColor *)failure;         // #FF453A

+ (void)installBackgroundInView:(UIView *)view;
+ (void)animateEntrance:(UIView *)view;

+ (UIFont *)titleFont;
+ (UIFont *)sectionFont;
+ (UIFont *)rowTitleFont;
+ (UIFont *)rowSubtitleFont;
+ (UIFont *)cardLabelFont;
+ (UIFont *)monoFont;

/*! The window a floating overlay/alert should be attached to, or nil. */
+ (nullable UIWindow *)presentingWindow;

/*! Attaches a full-screen overlay view to the presenting window. */
+ (BOOL)attachOverlay:(UIView *)overlay;

@end

NS_ASSUME_NONNULL_END

#endif /* FF_THEME_H */
