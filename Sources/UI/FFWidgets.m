

#import "FFWidgets.h"
#import "FFTheme.h"
#import "FFManifest.h"

#pragma mark - Section header

@implementation FFSectionHeaderView {
    UILabel *_label;
}

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _label = [UILabel new];
        _label.translatesAutoresizingMaskIntoConstraints = NO;
        _label.numberOfLines = 1;
        NSAttributedString *text = [[NSAttributedString alloc] initWithString:title.uppercaseString
            attributes:@{
                NSFontAttributeName: [FFTheme sectionFont],
                NSForegroundColorAttributeName: [FFTheme secondaryText],
                NSKernAttributeName: @(0.9),
            }];
        _label.attributedText = text;
        [self addSubview:_label];
        [NSLayoutConstraint activateConstraints:@[
            [_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_label.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor],
            [_label.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}

@end

#pragma mark - Function row

@implementation FFFunctionRowView {
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIView *_separator;
    BOOL _rowEnabled;
}

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _rowEnabled = YES;
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _titleLabel = [UILabel new];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.text = title;
        _titleLabel.font = [FFTheme rowTitleFont];
        _titleLabel.textColor = [FFTheme primaryText];
        _titleLabel.numberOfLines = 0;
        _titleLabel.adjustsFontForContentSizeCategory = YES;

        _subtitleLabel = [UILabel new];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.text = subtitle;
        _subtitleLabel.font = [FFTheme rowSubtitleFont];
        _subtitleLabel.textColor = [FFTheme secondaryText];
        _subtitleLabel.numberOfLines = 0;
        _subtitleLabel.adjustsFontForContentSizeCategory = YES;

        _toggle = [UISwitch new];
        _toggle.translatesAutoresizingMaskIntoConstraints = NO;
        _toggle.onTintColor = [FFTheme success];
        _toggle.thumbTintColor = [UIColor colorWithWhite:0.35 alpha:1];
        _toggle.accessibilityLabel = title;
        [_toggle addTarget:self
                    action:@selector(toggleChanged:)
          forControlEvents:UIControlEventValueChanged];

        _separator = [UIView new];
        _separator.translatesAutoresizingMaskIntoConstraints = NO;
        _separator.backgroundColor = [FFTheme separator];

        [self addSubview:_titleLabel];
        [self addSubview:_subtitleLabel];
        [self addSubview:_toggle];
        [self addSubview:_separator];

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_toggle.leadingAnchor constant:-12],

            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12],
            [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_toggle.leadingAnchor constant:-12],

            [_toggle.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            [_toggle.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

            [_separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
            [_separator.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [_separator.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_separator.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];

        self.showsSeparator = YES;
    }
    return self;
}

- (void)setShowsSeparator:(BOOL)showsSeparator {
    _showsSeparator = showsSeparator;
    _separator.hidden = !showsSeparator;
}

- (void)setOn:(BOOL)isOn animated:(BOOL)animated {
    [_toggle setOn:isOn animated:animated];
}

- (void)setSubtitleText:(NSString *)text {
    _subtitleLabel.text = text;
}

- (void)setInteractionEnabled:(BOOL)enabled {
    _rowEnabled = enabled;
    self.toggle.enabled = enabled;
    self.alpha = enabled ? 1.0 : 0.55;
}

- (void)toggleChanged:(UISwitch *)sender {
    if (self.onToggle != nil) self.onToggle(sender.isOn);
}

@end

#pragma mark - Group card

@implementation FFGroupCardView

- (instancetype)initWithRows:(NSArray<FFFunctionRowView *> *)rows {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = [FFTheme card];
        self.layer.borderWidth = 0.75;
        self.layer.borderColor = [FFTheme separator].CGColor;
        self.layer.cornerRadius = 18;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.clipsToBounds = YES;

        UIView *previous = nil;
        for (NSUInteger index = 0; index < rows.count; index++) {
            FFFunctionRowView *row = rows[index];
            row.showsSeparator = (index + 1 < rows.count);
            [self addSubview:row];
            if (previous == nil) {
                [NSLayoutConstraint activateConstraints:@[
                    [row.topAnchor constraintEqualToAnchor:self.topAnchor],
                ]];
            } else {
                [NSLayoutConstraint activateConstraints:@[
                    [row.topAnchor constraintEqualToAnchor:previous.bottomAnchor],
                ]];
            }
            [NSLayoutConstraint activateConstraints:@[
                [row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            ]];
            previous = row;
        }
        if (previous != nil) {
            [NSLayoutConstraint activateConstraints:@[
                [previous.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            ]];
        }
    }
    return self;
}

@end

#pragma mark - Game card

@implementation FFGameCardView {
    UIImageView *_iconView;
    UILabel *_nameLabel;
}

- (instancetype)initWithGame:(FFGame *)game {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _game = game;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = [FFTheme card];
        self.layer.borderWidth = 0.75;
        self.layer.borderColor = [FFTheme separator].CGColor;
        self.layer.cornerRadius = 18;
        self.layer.cornerCurve = kCACornerCurveContinuous;

        _iconView = [UIImageView new];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFill;
        _iconView.clipsToBounds = YES;
        _iconView.layer.cornerRadius = 14;
        _iconView.layer.cornerCurve = kCACornerCurveContinuous;
        UIImage *icon = [UIImage imageNamed:game.iconName];
        _iconView.image = icon;

        _nameLabel = [UILabel new];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.text = game.displayName;
        _nameLabel.font = [FFTheme cardLabelFont];
        _nameLabel.textColor = [FFTheme primaryText];
        _nameLabel.textAlignment = NSTextAlignmentCenter;
        _nameLabel.numberOfLines = 1;
        _nameLabel.adjustsFontSizeToFitWidth = YES;
        _nameLabel.minimumScaleFactor = 0.8;

        [self addSubview:_iconView];
        [self addSubview:_nameLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.topAnchor constraintEqualToAnchor:self.topAnchor constant:14],
            [_iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:48],
            [_iconView.heightAnchor constraintEqualToConstant:48],

            [_nameLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:10],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [_nameLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-12],

            [self.heightAnchor constraintGreaterThanOrEqualToConstant:102],
        ]];

        self.accessibilityTraits = UIAccessibilityTraitButton;
        self.accessibilityLabel = game.displayName;
    }
    return self;
}

- (void)setActive:(BOOL)active {
    _selectedGame = active;
    self.layer.borderWidth = active ? 1.5 : 0.75;
    self.layer.borderColor = active ? [UIColor whiteColor].CGColor : [FFTheme separator].CGColor;
    self.accessibilityValue = active ? @"selecionado" : nil;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.18 animations:^{
        self.alpha = highlighted ? 0.75 : 1.0;
    }];
}

@end

#pragma mark - Badge

@implementation FFBadgeView {
    UILabel *_label;
}

- (instancetype)initWithText:(NSString *)text color:(UIColor *)color {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = 9;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.clipsToBounds = YES;

        _label = [UILabel new];
        _label.translatesAutoresizingMaskIntoConstraints = NO;
        _label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        _label.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_label];
        [NSLayoutConstraint activateConstraints:@[
            [_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [_label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [_label.topAnchor constraintEqualToAnchor:self.topAnchor constant:3],
            [_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-3],
            [self.heightAnchor constraintEqualToConstant:20],
        ]];
        [self setText:text color:color];
    }
    return self;
}

- (void)setText:(NSString *)text color:(UIColor *)color {
    _label.text = text;
    _label.textColor = color;
    self.backgroundColor = [color colorWithAlphaComponent:0.16];
}

@end

#pragma mark - Status alert

@interface FFStatusAlertView ()
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, assign) BOOL activityMode;
@end

@implementation FFStatusAlertView

+ (instancetype)showWithStyle:(FFAlertStyle)style
                        title:(NSString *)title
                      message:(NSString *)message
                       detail:(NSString *)detail {
    FFStatusAlertView *alert = [[FFStatusAlertView alloc] initWithFrame:CGRectZero];
    [alert buildWithStyle:style title:title message:message detail:detail];
    [alert present];
    return alert;
}

+ (instancetype)showActivityWithTitle:(NSString *)title detail:(NSString *)detail {
    FFStatusAlertView *alert = [[FFStatusAlertView alloc] initWithFrame:CGRectZero];
    [alert buildActivityWithTitle:title detail:detail];
    [alert present];
    return alert;
}

- (void)buildWithStyle:(FFAlertStyle)style
                 title:(NSString *)title
               message:(NSString *)message
                detail:(NSString *)detail {
    _activityMode = NO;
    [self buildScaffold];

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:34 weight:UIImageSymbolWeightBold];
    NSString *symbolName = style == FFAlertStyleSuccess ? @"checkmark.circle.fill"
                          : style == FFAlertStyleFailure ? @"xmark.circle.fill"
                          : @"info.circle.fill";
    UIColor *tint = style == FFAlertStyleSuccess ? [FFTheme success]
                   : style == FFAlertStyleFailure ? [FFTheme failure]
                   : [FFTheme secondaryText];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:symbolName withConfiguration:config]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = tint;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *titleLabel = [self makeTitleLabel:title];
    UILabel *messageLabel = [self makeMessageLabel:message highlighted:YES];
    UILabel *detailLabel = detail.length ? [self makeDetailLabel:detail] : nil;

    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObjects:iconView, titleLabel, messageLabel, nil];
    if (detailLabel != nil) [stack addObject:detailLabel];

    [self layoutStack:stack buttonTitle:@"FECHAR" buttonColor:[FFTheme primaryText]];
    [self.closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
}

- (void)buildActivityWithTitle:(NSString *)title detail:(NSString *)detail {
    _activityMode = YES;
    [self buildScaffold];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.color = [UIColor whiteColor];
    [_spinner startAnimating];

    UILabel *titleLabel = [self makeTitleLabel:title];
    UILabel *detailLabel = detail.length ? [self makeDetailLabel:detail] : nil;

    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObjects:_spinner, titleLabel, nil];
    if (detailLabel != nil) [stack addObject:detailLabel];
    [self layoutStack:stack buttonTitle:nil buttonColor:nil];
}

- (void)buildScaffold {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = [UIColor clearColor];

    _dimView = [UIView new];
    _dimView.translatesAutoresizingMaskIntoConstraints = NO;
    _dimView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.62];
    [self addSubview:_dimView];
    [NSLayoutConstraint activateConstraints:@[
        [_dimView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_dimView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_dimView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_dimView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];

    _cardView = [UIView new];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = [FFTheme cardElevated];
    _cardView.layer.cornerRadius = 20;
    _cardView.layer.cornerCurve = kCACornerCurveContinuous;
    _cardView.clipsToBounds = YES;
    [self addSubview:_cardView];
    [NSLayoutConstraint activateConstraints:@[
        [_cardView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_cardView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_cardView.widthAnchor constraintEqualToConstant:300],
    ]];
}

- (UILabel *)makeTitleLabel:(NSString *)text {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.attributedText = [[NSAttributedString alloc] initWithString:text.uppercaseString
        attributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName: [FFTheme secondaryText],
            NSKernAttributeName: @(1.1),
        }];
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

- (UILabel *)makeMessageLabel:(NSString *)text highlighted:(BOOL)highlighted {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    label.textColor = [FFTheme primaryText];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    return label;
}

- (UILabel *)makeDetailLabel:(NSString *)text {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [FFTheme rowSubtitleFont];
    label.textColor = [FFTheme secondaryText];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    return label;
}

- (void)layoutStack:(NSArray<UIView *> *)views
        buttonTitle:(NSString *)buttonTitle
        buttonColor:(UIColor *)buttonColor {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 10;
    [stack setCustomSpacing:6 afterView:views.firstObject];

    [_cardView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:26],
        [stack.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-20],
    ]];

    for (UIView *view in views) {
        if (view == _spinner) continue;
        [view.widthAnchor constraintLessThanOrEqualToAnchor:stack.widthAnchor].active = YES;
    }

    if (buttonTitle.length == 0) {
        [NSLayoutConstraint activateConstraints:@[
            [stack.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-26],
        ]];
        return;
    }

    UIView *separator = [UIView new];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = [FFTheme separator];
    [_cardView addSubview:separator];

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_closeButton setTitle:buttonTitle forState:UIControlStateNormal];
    _closeButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [_closeButton setTitleColor:buttonColor ?: [FFTheme primaryText] forState:UIControlStateNormal];
    [_cardView addSubview:_closeButton];

    [NSLayoutConstraint activateConstraints:@[
        [separator.topAnchor constraintEqualToAnchor:stack.bottomAnchor constant:20],
        [separator.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor],
        [separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [_closeButton.topAnchor constraintEqualToAnchor:separator.bottomAnchor],
        [_closeButton.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor],
        [_closeButton.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor],
        [_closeButton.heightAnchor constraintEqualToConstant:50],
        [_closeButton.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor],
    ]];
}

- (void)present {
    self.alpha = 0;
    if (![FFTheme attachOverlay:self]) return;
    _cardView.transform = CGAffineTransformMakeScale(0.86, 0.86);
    [UIView animateWithDuration:0.22
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.alpha = 1;
        self.cardView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)closeTapped {
    [self dismiss];
}

- (void)dismiss {
    [UIView animateWithDuration:0.16 animations:^{
        self.alpha = 0;
        self.cardView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end
