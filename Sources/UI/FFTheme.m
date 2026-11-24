//
//  FFTheme.m
//  FFPatch
//

#import "FFTheme.h"
#import "FFAppDelegate.h"

@interface FFAtmosphereView : UIView
@end
@implementation FFAtmosphereView
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    [[UIColor blackColor] setFill]; UIRectFill(rect);
    CGFloat w = CGRectGetWidth(self.bounds), h = CGRectGetHeight(self.bounds);
    CGContextSaveGState(c);
    CGContextTranslateCTM(c, w * 0.92, h * 0.24);
    CGContextRotateCTM(c, -0.48);
    for (NSInteger i = 0; i < 9; i++) {
        CGFloat radius = 100 + i * 26;
        CGContextSetStrokeColorWithColor(c, [UIColor colorWithWhite:1 alpha:0.065 - i * 0.004].CGColor);
        CGContextSetLineWidth(c, 0.7);
        CGContextStrokeEllipseInRect(c, CGRectMake(-radius, -radius * 1.8, radius * 2, radius * 3.6));
    }
    CGContextRestoreGState(c);
    CGContextSetFillColorWithColor(c, [UIColor colorWithWhite:1 alpha:0.085].CGColor);
    for (CGFloat x = 20; x < w; x += 28)
        for (CGFloat y = 24; y < h; y += 28)
            CGContextFillEllipseInRect(c, CGRectMake(x, y, 1, 1));
}
@end

@implementation FFTheme

+ (UIColor *)colorWithHex:(UInt32)hex {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:1.0];
}

+ (UIColor *)background  { return [UIColor blackColor]; }
+ (UIColor *)card        { return [self colorWithHex:0x111111]; }
+ (UIColor *)cardElevated{ return [self colorWithHex:0x191919]; }
+ (UIColor *)separator   { return [[self colorWithHex:0x454545] colorWithAlphaComponent:0.6]; }
+ (UIColor *)primaryText { return [UIColor whiteColor]; }
+ (UIColor *)secondaryText { return [self colorWithHex:0xAAAAAA]; }
+ (UIColor *)accent      { return [self colorWithHex:0xFFFFFF]; }
+ (UIColor *)success     { return [self colorWithHex:0xFFFFFF]; }
+ (UIColor *)failure     { return [self colorWithHex:0xDDDDDD]; }

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
    UIFont *base = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
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

+ (void)installBackgroundInView:(UIView *)view {
    FFAtmosphereView *background = [[FFAtmosphereView alloc] initWithFrame:view.bounds];
    background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    background.contentMode = UIViewContentModeRedraw;
    background.userInteractionEnabled = NO;
    background.accessibilityElementsHidden = YES;
    [view insertSubview:background atIndex:0];
}

+ (void)animateEntrance:(UIView *)view {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    view.alpha = 0;
    view.transform = CGAffineTransformMakeTranslation(0, 8);
    [UIView animateWithDuration:0.24 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:^{
        view.alpha = 1;
        view.transform = CGAffineTransformIdentity;
    } completion:nil];
}

+ (UIWindow *)presentingWindow {
    id delegate = [UIApplication sharedApplication].delegate;
    if (![delegate isKindOfClass:[FFAppDelegate class]]) return nil;
    return [(FFAppDelegate *)delegate window];
}

+ (BOOL)attachOverlay:(UIView *)overlay {
    id delegate = [UIApplication sharedApplication].delegate;
    if (![delegate isKindOfClass:[FFAppDelegate class]]) return NO;
    UIView *container = [(FFAppDelegate *)delegate overlayContainerView];
    if (container == nil || container.window == nil) return NO;
    // Application HUDs belong below the stable SDK presentation host.
    // Never attach them to whichever window the SDK has made key.
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:overlay];
    [NSLayoutConstraint activateConstraints:@[
        [overlay.topAnchor constraintEqualToAnchor:container.topAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [overlay.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
    ]];
    return YES;
}

@end
