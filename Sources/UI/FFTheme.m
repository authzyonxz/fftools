//
//  FFTheme.m
//  FFPatch
//

#import "FFTheme.h"

@implementation FFTheme

+ (UIColor *)colorWithHex:(UInt32)hex {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:1.0];
}

+ (UIColor *)background  { return [UIColor blackColor]; }
+ (UIColor *)card        { return [self colorWithHex:0x1C1C1E]; }
+ (UIColor *)cardElevated{ return [self colorWithHex:0x2C2C2E]; }
+ (UIColor *)separator   { return [[self colorWithHex:0x3A3A3C] colorWithAlphaComponent:0.6]; }
+ (UIColor *)primaryText { return [UIColor whiteColor]; }
+ (UIColor *)secondaryText { return [self colorWithHex:0x8E8E93]; }
+ (UIColor *)accent      { return [self colorWithHex:0xE23744]; }
+ (UIColor *)success     { return [self colorWithHex:0x30D158]; }
+ (UIColor *)failure     { return [self colorWithHex:0xFF453A]; }

+ (UIFont *)titleFont {
    UIFont *base = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle2] scaledFontForFont:base];
    }
    return base;
}

+ (UIFont *)sectionFont {
    UIFont *base = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    if (@available(iOS 13.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:base];
    }
    return base;
}

+ (UIFont *)rowTitleFont {
    UIFont *base = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    if (@available(iOS 13.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:base];
    }
    return base;
}

+ (UIFont *)rowSubtitleFont {
    UIFont *base = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    if (@available(iOS 13.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote] scaledFontForFont:base];
    }
    return base;
}

+ (UIFont *)cardLabelFont {
    UIFont *base = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    if (@available(iOS 13.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:base];
    }
    return base;
}

+ (UIFont *)monoFont {
    return [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];
}

+ (UIWindow *)presentingWindow {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState != UISceneActivationStateForegroundActive &&
            windowScene.activationState != UISceneActivationStateForegroundInactive) {
            continue;
        }
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow && !window.hidden) return window;
        }
        if (windowScene.windows.count) return windowScene.windows.firstObject;
    }
    UIWindow *legacy = [UIApplication sharedApplication].keyWindow;
    if (legacy != nil) return legacy;
    // Last resort: the first window of the app delegate.
    return [UIApplication sharedApplication].windows.firstObject;
}

+ (BOOL)attachOverlay:(UIView *)overlay {
    UIWindow *window = [self presentingWindow];
    if (window == nil) return NO;
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    [window addSubview:overlay];
    [NSLayoutConstraint activateConstraints:@[
        [overlay.topAnchor constraintEqualToAnchor:window.topAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:window.bottomAnchor],
        [overlay.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
    ]];
    return YES;
}

@end
