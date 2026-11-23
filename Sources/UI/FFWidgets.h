//
//  FFWidgets.h
//  FFPatch — reusable views for the FUNÇÕES / PERFIL screens.
//

#ifndef FF_WIDGETS_H
#define FF_WIDGETS_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class FFFunction, FFGame;

/* ---- section header: "FUNÇÕES DE AIMBOT" ---- */
@interface FFSectionHeaderView : UIView
- (instancetype)initWithTitle:(NSString *)title;
@end

/* ---- one toggle row ---- */
@interface FFFunctionRowView : UIView

@property (nonatomic, copy, nullable) void (^onToggle)(BOOL isOn);
@property (nonatomic, readonly) UISwitch *toggle;
@property (nonatomic, assign) BOOL showsSeparator;

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle;
- (void)setOn:(BOOL)isOn animated:(BOOL)animated;
- (void)setInteractionEnabled:(BOOL)enabled;

@end

/* ---- rounded card that stacks rows ---- */
@interface FFGroupCardView : UIView
- (instancetype)initWithRows:(NSArray<FFFunctionRowView *> *)rows;
@end

/* ---- game selector card: icon + label, white outline when selected ---- */
@interface FFGameCardView : UIControl

@property (nonatomic, readonly) FFGame *game;
@property (nonatomic, assign, getter=isSelectedGame) BOOL selectedGame;

- (instancetype)initWithGame:(FFGame *)game;
- (void)setActive:(BOOL)active;

@end

/* ---- Apple-style floating alert ---- */
typedef NS_ENUM(NSInteger, FFAlertStyle) {
    FFAlertStyleSuccess = 0,
    FFAlertStyleFailure = 1,
    FFAlertStyleInfo    = 2,
};

@interface FFStatusAlertView : UIView

/*! Shows a status alert with a FECHAR button. */
+ (instancetype)showWithStyle:(FFAlertStyle)style
                         title:(NSString *)title
                       message:(NSString *)message
                        detail:(nullable NSString *)detail;

/*! Spinner overlay ("APLICANDO…"). Call -dismiss when the work ends. */
+ (instancetype)showActivityWithTitle:(NSString *)title detail:(nullable NSString *)detail;

- (void)dismiss;

@end

/* ---- small "ATIVO" pill used in the header ---- */
@interface FFBadgeView : UIView
- (instancetype)initWithText:(NSString *)text color:(UIColor *)color;
- (void)setText:(NSString *)text color:(UIColor *)color;
@end

NS_ASSUME_NONNULL_END

#endif /* FF_WIDGETS_H */
