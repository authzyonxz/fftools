

#ifndef FF_WIDGETS_H
#define FF_WIDGETS_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class FFFunction, FFGame;

@interface FFSectionHeaderView : UIView
- (instancetype)initWithTitle:(NSString *)title;
@end

@interface FFFunctionRowView : UIView

@property (nonatomic, copy, nullable) void (^onToggle)(BOOL isOn);
@property (nonatomic, readonly) UISwitch *toggle;
@property (nonatomic, assign) BOOL showsSeparator;

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle;
- (void)setOn:(BOOL)isOn animated:(BOOL)animated;
- (void)setSubtitleText:(NSString *)text;
- (void)setInteractionEnabled:(BOOL)enabled;

@end

@interface FFGroupCardView : UIView
- (instancetype)initWithRows:(NSArray<FFFunctionRowView *> *)rows;
@end

@interface FFGameCardView : UIControl

@property (nonatomic, readonly) FFGame *game;
@property (nonatomic, assign, getter=isSelectedGame) BOOL selectedGame;

- (instancetype)initWithGame:(FFGame *)game;
- (void)setActive:(BOOL)active;

@end

typedef NS_ENUM(NSInteger, FFAlertStyle) {
    FFAlertStyleSuccess = 0,
    FFAlertStyleFailure = 1,
    FFAlertStyleInfo    = 2,
};

@interface FFStatusAlertView : UIView

+ (instancetype)showWithStyle:(FFAlertStyle)style
                         title:(NSString *)title
                       message:(NSString *)message
                        detail:(nullable NSString *)detail;

+ (instancetype)showActivityWithTitle:(NSString *)title detail:(nullable NSString *)detail;

- (void)dismiss;

@end

@interface FFBadgeView : UIView
- (instancetype)initWithText:(NSString *)text color:(UIColor *)color;
- (void)setText:(NSString *)text color:(UIColor *)color;
@end

NS_ASSUME_NONNULL_END

#endif
