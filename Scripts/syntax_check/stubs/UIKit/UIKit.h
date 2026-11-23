/* Verification-only UIKit / QuartzCore stub. Not part of the app. */
#ifndef FF_VERIFY_UIKIT_H
#define FF_VERIFY_UIKIT_H

#import <Foundation/Foundation.h>

typedef struct CGColor *CGColorRef;
typedef unsigned long UInt32;

typedef NS_ENUM(NSInteger, UIViewContentMode) {
    UIViewContentModeScaleToFill, UIViewContentModeScaleAspectFit,
    UIViewContentModeScaleAspectFill, UIViewContentModeRedraw
};
typedef NS_ENUM(NSInteger, NSTextAlignment) {
    NSTextAlignmentLeft, NSTextAlignmentCenter, NSTextAlignmentRight,
    NSTextAlignmentJustified, NSTextAlignmentNatural
};
typedef NS_ENUM(NSInteger, UIButtonType) {
    UIButtonTypeCustom, UIButtonTypeSystem
};
typedef NS_ENUM(NSInteger, UIControlEvent) {
    UIControlEventTouchUpInside = 1 << 6,
    UIControlEventValueChanged = 1 << 12
};
typedef NS_ENUM(NSInteger, UIButtonState) {
    UIControlStateNormal, UIControlStateHighlighted, UIControlStateSelected,
    UIControlStateDisabled
};
typedef NS_ENUM(NSInteger, UILayoutConstraintAxis) {
    UILayoutConstraintAxisHorizontal, UILayoutConstraintAxisVertical
};
typedef NS_ENUM(NSInteger, UIStackViewDistribution) {
    UIStackViewDistributionFill, UIStackViewDistributionFillEqually,
    UIStackViewDistributionFillProportionally, UIStackViewDistributionEqualSpacing,
    UIStackViewDistributionEqualCentering
};
typedef NS_ENUM(NSInteger, UIStackViewAlignment) {
    UIStackViewAlignmentFill, UIStackViewAlignmentLeading,
    UIStackViewAlignmentFirstBaseline, UIStackViewAlignmentCenter,
    UIStackViewAlignmentTrailing, UIStackViewAlignmentLastBaseline
};
typedef NS_ENUM(NSInteger, UIAlertControllerStyle) {
    UIAlertControllerStyleActionSheet, UIAlertControllerStyleAlert
};
typedef NS_ENUM(NSInteger, UIAlertActionStyle) {
    UIAlertActionStyleDefault, UIAlertActionStyleCancel, UIAlertActionStyleDestructive
};
typedef NS_ENUM(NSInteger, UIActivityIndicatorViewStyle) {
    UIActivityIndicatorViewStyleMedium, UIActivityIndicatorViewStyleLarge,
    UIActivityIndicatorViewStyleWhiteLarge
};
typedef NS_ENUM(NSInteger, UIStatusBarStyle) {
    UIStatusBarStyleDefault, UIStatusBarStyleLightContent
};
typedef NS_ENUM(NSInteger, UISceneActivationState) {
    UISceneActivationStateUnattached, UISceneActivationStateForegroundActive,
    UISceneActivationStateForegroundInactive, UISceneActivationStateBackground
};
typedef NS_OPTIONS(NSUInteger, UIInterfaceOrientationMask) {
    UIInterfaceOrientationMaskPortrait = 1 << 1,
    UIInterfaceOrientationMaskLandscape = 1 << 4
};
typedef NS_OPTIONS(NSUInteger, UIAccessibilityTraits) {
    UIAccessibilityTraitNone = 0,
    UIAccessibilityTraitButton = 1 << 0,
    UIAccessibilityTraitStaticText = 1 << 3
};
typedef NS_OPTIONS(NSUInteger, UIViewAnimationOptions) {
    UIViewAnimationOptionCurveEaseOut = 0
};
typedef NS_ENUM(NSInteger, UIUserInterfaceStyle) {
    UIUserInterfaceStyleUnspecified, UIUserInterfaceStyleLight, UIUserInterfaceStyleDark
};
typedef double UIFontWeight;
static const UIFontWeight UIFontWeightUltraLight = -0.8;
static const UIFontWeight UIFontWeightThin = -0.6;
static const UIFontWeight UIFontWeightLight = -0.4;
static const UIFontWeight UIFontWeightRegular = 0.0;
static const UIFontWeight UIFontWeightMedium = 0.23;
static const UIFontWeight UIFontWeightSemibold = 0.3;
static const UIFontWeight UIFontWeightBold = 0.4;
static const UIFontWeight UIFontWeightHeavy = 0.56;
static const UIFontWeight UIFontWeightBlack = 0.62;
typedef NS_ENUM(NSInteger, UIImageSymbolWeight) {
    UIImageSymbolWeightRegular, UIImageSymbolWeightMedium,
    UIImageSymbolWeightSemibold, UIImageSymbolWeightBold
};
typedef NS_ENUM(NSInteger, UIBarStyle) {
    UIBarStyleDefault, UIBarStyleBlack
};
typedef NS_ENUM(NSInteger, UITextAutocorrectionType) {
    UITextAutocorrectionTypeDefault
};

extern const CGAffineTransform CGAffineTransformIdentity;
extern const CGRect CGRectZero;
extern const CGPoint CGPointZero;
CGRect CGRectMake(CGFloat x, CGFloat y, CGFloat width, CGFloat height);
CGSize CGSizeMake(CGFloat width, CGFloat height);
extern const CGRect CGRectZero;
extern const CGPoint CGPointZero;
CGRect CGRectMake(CGFloat x, CGFloat y, CGFloat width, CGFloat height);
CGSize CGSizeMake(CGFloat width, CGFloat height);
CGAffineTransform CGAffineTransformMakeScale(CGFloat sx, CGFloat sy);

extern NSString *const UIFontTextStyleTitle2;
extern NSString *const UIFontTextStyleCaption1;
extern NSString *const UIFontTextStyleBody;
extern NSString *const UIFontTextStyleFootnote;
extern NSString *const UIFontTextStyleSubheadline;

@class UIWindow, UIViewController, UIApplication, UIScreen, UIGestureRecognizer;
@class UIScene, UIWindowScene, UITabBarItem, UINavigationItem;
@class UILayoutGuide, NSLayoutAnchor, NSLayoutConstraint, UITabBarItemAppearance;
@class UIImage, UIColor, UIFont, UIFontMetrics, UIImageView, UILabel, UISwitch,
       UIScrollView, UIStackView, UIButton, UIControl, UIView, UITabBar,
       UITabBarAppearance, UINavigationBar, UINavigationBarAppearance,
       UIActivityIndicatorView, UIActivityViewController, UIAlertController,
       UIAlertAction, UITabBarController, UINavigationController,
       UIImageSymbolConfiguration;
@class CALayer;

@interface UIColor : NSObject
+ (UIColor *)blackColor;
+ (UIColor *)whiteColor;
+ (UIColor *)clearColor;
+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (UIColor *)colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha;
- (UIColor *)colorWithAlphaComponent:(CGFloat)alpha;
@property (readonly) CGColorRef CGColor;
@end

@interface UIFont : NSObject
+ (UIFont *)systemFontOfSize:(CGFloat)size;
+ (UIFont *)systemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;
+ (UIFont *)monospacedSystemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;
- (UIFont *)fontWithSize:(CGFloat)size;
@end

@interface UIFontMetrics : NSObject
+ (UIFontMetrics *)metricsForTextStyle:(NSString *)textStyle;
- (UIFont *)scaledFontForFont:(UIFont *)font;
@end

@interface UIImage : NSObject
+ (UIImage *)imageNamed:(NSString *)name;
+ (UIImage *)systemImageNamed:(NSString *)name;
+ (UIImage *)systemImageNamed:(NSString *)name withConfiguration:(UIImageSymbolConfiguration *)configuration;
@end

@interface UIImageSymbolConfiguration : NSObject
+ (UIImageSymbolConfiguration *)configurationWithPointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight;
@end

@interface CALayer : NSObject
@property CGFloat cornerRadius;
@property CGFloat borderWidth;
@property CGColorRef borderColor;
@property BOOL masksToBounds;
@property NSInteger cornerCurve;
@end

extern const NSInteger kCACornerCurveContinuous;

@interface UIView : NSObject
- (instancetype)initWithFrame:(CGRect)frame;
@property (copy) UIColor *backgroundColor;
@property (readonly) CALayer *layer;
@property BOOL translatesAutoresizingMaskIntoConstraints;
@property (readonly) NSArray *subviews;
@property (readonly) UIView *superview;
@property BOOL hidden;
@property CGFloat alpha;
@property NSInteger tag;
@property CGRect frame;
@property CGRect bounds;
@property (readonly) UILayoutGuide *safeAreaLayoutGuide;
@property (readonly) UILayoutGuide *layoutMarginsGuide;
@property (readonly) NSLayoutAnchor *topAnchor;
@property (readonly) NSLayoutAnchor *bottomAnchor;
@property (readonly) NSLayoutAnchor *leadingAnchor;
@property (readonly) NSLayoutAnchor *trailingAnchor;
@property (readonly) NSLayoutAnchor *centerXAnchor;
@property (readonly) NSLayoutAnchor *centerYAnchor;
@property (readonly) NSLayoutAnchor *widthAnchor;
@property (readonly) NSLayoutAnchor *heightAnchor;
@property BOOL clipsToBounds;
@property CGAffineTransform transform;
@property BOOL isAccessibilityElement;
@property (copy) NSString *accessibilityLabel;
@property (copy) NSString *accessibilityValue;
@property UIAccessibilityTraits accessibilityTraits;
- (void)addSubview:(UIView *)view;
- (void)removeFromSuperview;
- (UIView *)viewWithTag:(NSInteger)tag;
- (void)layoutIfNeeded;
- (void)setNeedsLayout;
- (CGSize)systemLayoutSizeFittingSize:(CGSize)size;
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations;
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)animateWithDuration:(NSTimeInterval)duration
                      delay:(NSTimeInterval)delay
     usingSpringWithDamping:(CGFloat)damping
      initialSpringVelocity:(CGFloat)velocity
                    options:(UIViewAnimationOptions)options
                 animations:(void (^)(void))animations
                 completion:(void (^)(BOOL finished))completion;
@end

@interface UILayoutGuide : NSObject
@property (readonly) NSLayoutAnchor *topAnchor;
@property (readonly) NSLayoutAnchor *bottomAnchor;
@property (readonly) NSLayoutAnchor *leadingAnchor;
@property (readonly) NSLayoutAnchor *trailingAnchor;
@property (readonly) NSLayoutAnchor *centerXAnchor;
@property (readonly) NSLayoutAnchor *centerYAnchor;
@property (readonly) NSLayoutAnchor *widthAnchor;
@property (readonly) NSLayoutAnchor *heightAnchor;
@end

@interface NSLayoutAnchor : NSObject
- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutAnchor *)anchor;
- (NSLayoutConstraint *)constraintEqualToConstant:(CGFloat)constant;
- (NSLayoutConstraint *)constraintGreaterThanOrEqualToConstant:(CGFloat)constant;
- (NSLayoutConstraint *)constraintLessThanOrEqualToConstant:(CGFloat)constant;
- (NSLayoutConstraint *)constraintEqualToConstant:(CGFloat)constant;
- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutAnchor *)anchor constant:(CGFloat)constant;
- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor *)anchor;
- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor *)anchor constant:(CGFloat)constant;
- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutAnchor *)anchor;
- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutAnchor *)anchor constant:(CGFloat)constant;
@end

@interface NSLayoutConstraint : NSObject
@property BOOL active;
+ (void)activateConstraints:(NSArray<NSLayoutConstraint *> *)constraints;
+ (void)deactivateConstraints:(NSArray<NSLayoutConstraint *> *)constraints;
@end

@interface UIScreen : NSObject
+ (UIScreen *)mainScreen;
@property (readonly) CGRect bounds;
@property (readonly) CGFloat scale;
@end

@interface UILabel : UIView
@property (copy) NSString *text;
@property (strong) UIFont *font;
@property (strong) UIColor *textColor;
@property NSTextAlignment textAlignment;
@property NSInteger numberOfLines;
@property (copy) NSAttributedString *attributedText;
@property BOOL adjustsFontSizeToFitWidth;
@property CGFloat minimumScaleFactor;
@end

@interface UIImageView : UIView
- (instancetype)initWithImage:(UIImage *)image;
@property (strong) UIImage *image;
@property UIViewContentMode contentMode;
@property (strong) UIColor *tintColor;
@end

@interface UIControl : UIView
@property BOOL enabled;
@property BOOL selected;
@property (getter=isHighlighted) BOOL highlighted;
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvent)events;
- (void)removeTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvent)events;
- (void)setHighlighted:(BOOL)highlighted;
@end

@interface UISwitch : UIControl
@property (getter=isOn) BOOL on;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@property (strong) UIColor *onTintColor;
@end

@interface UIButton : UIControl
+ (instancetype)buttonWithType:(UIButtonType)type;
- (void)setTitle:(NSString *)title forState:(UIButtonState)state;
- (void)setTitleColor:(UIColor *)color forState:(UIButtonState)state;
@property (readonly) UILabel *titleLabel;
@property (copy) NSString *title;
@end

@interface UIScrollView : UIView
@property BOOL alwaysBounceVertical;
@property BOOL showsVerticalScrollIndicator;
@property (readonly) UILayoutGuide *contentLayoutGuide;
@property (readonly) UILayoutGuide *frameLayoutGuide;
@end

@interface UIStackView : UIView
- (instancetype)initWithArrangedSubviews:(NSArray<UIView *> *)views;
@property UILayoutConstraintAxis axis;
@property CGFloat spacing;
@property UIStackViewDistribution distribution;
@property UIStackViewAlignment alignment;
- (void)addArrangedSubview:(UIView *)view;
- (void)removeArrangedSubview:(UIView *)view;
- (void)setCustomSpacing:(CGFloat)spacing afterView:(UIView *)view;
@end

@interface UIActivityIndicatorView : UIView
- (instancetype)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style;
- (void)startAnimating;
- (void)stopAnimating;
@property (strong) UIColor *color;
@end

@interface UITabBarItem : NSObject
- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image selectedImage:(UIImage *)image2;
@end

@interface UIBarItem : NSObject
@end

@interface UINavigationItem : NSObject
@property (copy) NSString *title;
@end

@protocol UIApplicationDelegate <NSObject>
@end

@interface UIResponder : NSObject
@end

@interface UIViewController : UIResponder
- (instancetype)initWithNibName:(NSString *)name bundle:(NSBundle *)bundle;
@property (strong) UIView *view;
@property (copy) NSString *title;
@property (strong) UITabBarItem *tabBarItem;
@property (readonly) UINavigationController *navigationController;
@property (readonly) UITabBarController *tabBarController;
@property (readonly, copy) NSArray<UIViewController *> *childViewControllers;
- (void)viewDidLoad;
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidLayoutSubviews;
- (void)presentViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion;
- (void)addChildViewController:(UIViewController *)controller;
- (UIStatusBarStyle)preferredStatusBarStyle;
@property (readonly) UIInterfaceOrientationMask supportedInterfaceOrientations;
@end

@interface UINavigationController : UIViewController
- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;
@property (readonly) UIViewController *topViewController;
- (void)pushViewController:(UIViewController *)controller animated:(BOOL)animated;
@end

@interface UITabBarController : UIViewController
@property (copy) NSArray<UIViewController *> *viewControllers;
@property (readonly) UIViewController *selectedViewController;
@property NSUInteger selectedIndex;
@end

@interface UIAlertAction : NSObject
+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *action))handler;
@end

@interface UIAlertController : UIViewController
+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)style;
- (void)addAction:(UIAlertAction *)action;
@end

@interface UIActivityViewController : UIViewController
- (instancetype)initWithActivityItems:(NSArray *)items applicationActivities:(NSArray *)activities;
@end

@interface UIApplication : UIResponder
+ (UIApplication *)sharedApplication;
@property (readonly) NSArray<UIScene *> *connectedScenes;
@property (readonly) NSArray<UIWindow *> *windows;
@property (readonly) UIWindow *keyWindow;
@end

@interface UIScene : NSObject
@property (readonly) UISceneActivationState activationState;
@end

@interface UIWindowScene : UIScene
@property (readonly) NSArray<UIWindow *> *windows;
@end

@interface UIWindow : UIView
- (instancetype)initWithFrame:(CGRect)frame;
@property (strong) UIViewController *rootViewController;
- (void)makeKeyAndVisible;
@property (readonly, getter=isKeyWindow) BOOL keyWindow;
@end

@interface UITabBarItemAppearance : NSObject
@property (readonly) UITabBarItemAppearance *normal;
@property (readonly) UITabBarItemAppearance *selected;
- (void)setIconColor:(UIColor *)color;
- (void)setTitleTextAttributes:(NSDictionary *)attributes;
@end

@interface UITabBarAppearance : NSObject
- (void)configureWithOpaqueBackground;
@property (strong) UIColor *backgroundColor;
@property (strong) UIColor *shadowColor;
@property (readonly) UITabBarItemAppearance *stackedLayoutAppearance;
- (void)setIconColor:(UIColor *)color;
- (void)setTitleTextAttributes:(NSDictionary *)attributes;
@end

@interface UITabBar : UIView
+ (UITabBar *)appearance;
@property (strong) UITabBarAppearance *standardAppearance;
@property (strong) UITabBarAppearance *scrollEdgeAppearance;
@property (strong) UIColor *tintColor;
@property (strong) UIColor *barTintColor;
@end

@interface UINavigationBarAppearance : NSObject
- (void)configureWithOpaqueBackground;
@property (strong) UIColor *backgroundColor;
@property (strong) UIColor *shadowColor;
@property (copy) NSDictionary *titleTextAttributes;
@end

@interface UINavigationBar : UIView
+ (UINavigationBar *)appearance;
@property (strong) UINavigationBarAppearance *standardAppearance;
@property (strong) UINavigationBarAppearance *scrollEdgeAppearance;
@property (strong) UINavigationBarAppearance *compactAppearance;
@property (copy) NSDictionary *titleTextAttributes;
@property (strong) UIColor *barTintColor;
@end

#endif
