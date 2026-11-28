#import "KALicenseViewController.h"
#import "KASecurity.h"

@interface KAOrbitCanvas : UIView @end
@implementation KAOrbitCanvas
- (void)drawRect:(CGRect)rect {
    [[UIColor colorWithWhite:0.025 alpha:1] setFill]; UIRectFill(rect);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context); CGContextTranslateCTM(context, rect.size.width * .92, rect.size.height * .17);
    CGContextRotateCTM(context, -.55);
    for (NSInteger i = 0; i < 10; ++i) {
        CGFloat r = 70 + i * 25;
        CGContextSetStrokeColorWithColor(context,[UIColor colorWithWhite:1 alpha:.08 - i * .005].CGColor);
        CGContextSetLineWidth(context,.8); CGContextStrokeEllipseInRect(context,CGRectMake(-r,-r*1.6,r*2,r*3.2));
    }
    CGContextRestoreGState(context);
}
@end
@interface KALicenseViewController () <UITextFieldDelegate>
@property(nonatomic) KAExternalClient *client;
@property(nonatomic,copy) void (^authorized)(NSDictionary *);
@property(nonatomic) UITextField *keyField;
@property(nonatomic) UISwitch *remember;
@property(nonatomic) UIButton *submit;
@property(nonatomic) UILabel *status;
@property(nonatomic) UIActivityIndicatorView *spinner;
@property(nonatomic) BOOL busy;
@property(nonatomic) BOOL autoAttempted;
@property(nonatomic) BOOL allowAutoLogin;
@property(nonatomic) NSError *lockError;
@end
@implementation KALicenseViewController
- (instancetype)initWithClient:(KAExternalClient *)client onAuthorized:(void (^)(NSDictionary *))authorized {
    if ((self = [super init])) { _client = client; _authorized = [authorized copy]; _allowAutoLogin = YES; } return self;
}
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(CGFloat)white {
    UILabel *label = [UILabel new]; label.text = text; label.numberOfLines = 0;
    label.textColor = [UIColor colorWithWhite:white alpha:1];
    label.font = [[UIFontMetrics defaultMetrics] scaledFontForFont:[UIFont systemFontOfSize:size weight:weight]];
    label.adjustsFontForContentSizeCategory = YES; return label;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    KAOrbitCanvas *background = [[KAOrbitCanvas alloc] initWithFrame:self.view.bounds];
    background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    background.contentMode = UIViewContentModeRedraw; background.userInteractionEnabled = NO; [self.view addSubview:background];
    UIScrollView *scroll = [UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive; [self.view addSubview:scroll];
    UIView *card = [UIView new]; card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor colorWithWhite:.055 alpha:.97];
    card.layer.cornerRadius = 26; card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1; card.layer.borderColor = [UIColor colorWithWhite:1 alpha:.14].CGColor;
    [scroll addSubview:card];
    UILabel *title = [self label:@"EXTERNAL" size:30 weight:UIFontWeightBold color:1];
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    NSString *version = [NSString stringWithFormat:@"%@ · BUILD %@", info[@"CFBundleShortVersionString"] ?: @"—", info[@"CFBundleVersion"] ?: @"—"];
    UILabel *subtitle = [self label:version size:12 weight:UIFontWeightMedium color:.6];
    self.keyField = [UITextField new]; self.keyField.delegate = self; self.keyField.placeholder = @"Cole sua key";
    self.keyField.accessibilityLabel = @"Key do pacote EXTERNAL";
    self.keyField.secureTextEntry = YES; self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyField.spellCheckingType = UITextSpellCheckingTypeNo; self.keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.keyField.keyboardType = UIKeyboardTypeASCIICapable; self.keyField.returnKeyType = UIReturnKeyGo;
    self.keyField.textColor = UIColor.whiteColor; self.keyField.font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightMedium];
    self.keyField.backgroundColor = [UIColor colorWithWhite:.10 alpha:1]; self.keyField.layer.cornerRadius = 13;
    UIView *padding = [[UIView alloc] initWithFrame:CGRectMake(0,0,16,1)];
    self.keyField.leftView = padding; self.keyField.leftViewMode = UITextFieldViewModeAlways;
    [self.keyField.heightAnchor constraintGreaterThanOrEqualToConstant:56].active = YES;
    self.remember = [UISwitch new]; self.remember.on = YES;
    self.remember.onTintColor = UIColor.whiteColor; self.remember.thumbTintColor = UIColor.darkGrayColor;
    self.remember.accessibilityLabel = @"Salvar key somente neste aparelho";
    UILabel *saveLabel = [self label:@"Salvar neste aparelho" size:13 weight:UIFontWeightMedium color:.72];
    UIStackView *saveRow = [[UIStackView alloc] initWithArrangedSubviews:@[saveLabel,self.remember]];
    saveRow.axis = UILayoutConstraintAxisHorizontal; saveRow.alignment = UIStackViewAlignmentCenter; saveRow.spacing = 12;
    self.submit = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.submit setTitle:@"Entrar" forState:UIControlStateNormal];
    [self.submit setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    self.submit.backgroundColor = UIColor.whiteColor; self.submit.layer.cornerRadius = 13;
    self.submit.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [self.submit.heightAnchor constraintGreaterThanOrEqualToConstant:54].active = YES;
    [self.submit addTarget:self action:@selector(login) forControlEvents:UIControlEventTouchUpInside];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    self.status = [self label:self.lockError.localizedDescription ?: @"" size:12 weight:UIFontWeightRegular color:.6];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title,subtitle,self.keyField,saveRow,self.submit,self.spinner,self.status]];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 18; stack.translatesAutoresizingMaskIntoConstraints = NO;
    [stack setCustomSpacing:8 afterView:title]; [stack setCustomSpacing:26 afterView:subtitle]; [card addSubview:stack];
    NSLayoutConstraint *center = [card.centerYAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.centerYAnchor]; center.priority = 750;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],
        [card.topAnchor constraintGreaterThanOrEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:24],
        [card.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [card.centerXAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.centerXAnchor],
        [card.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20],
        [card.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20],
        [card.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40], center,
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:26], [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-26],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24], [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24]
    ]];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeSaved) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self resumeSaved];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)resumeSaved {
    if (!self.allowAutoLogin || self.autoAttempted || self.busy || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    self.autoAttempted = YES;
    // Presence alone never grants access: login performs the full online proof.
    if (KAReadLicense(NULL).length) [self login];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [self login]; return NO; }
- (void)login {
    if (self.busy) return; self.busy = YES; self.submit.enabled = NO; self.keyField.enabled = NO; self.remember.enabled = NO;
    self.status.text = @"Confirmando licença e identidade do aparelho…"; [self.spinner startAnimating]; [self.view endEditing:YES];
    __weak typeof(self) weakSelf = self;
    [self.client loginWithLicense:self.keyField.text ?: @"" remember:self.remember.on completion:^(NSDictionary *license, NSError *error) {
        typeof(self) self = weakSelf; if (!self) return;
        self.busy = NO; self.submit.enabled = YES; self.keyField.enabled = YES; self.remember.enabled = YES; [self.spinner stopAnimating];
        if (error) {
            self.status.text = error.localizedDescription;
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,self.status.text); return;
        }
        self.keyField.text = @""; self.status.text = @"Licença confirmada. Bem-vindo ao EXTERNAL.";
        self.authorized(license);
    }];
}
@end

@interface KAProtectedRootController ()
@property(nonatomic) KAExternalClient *client;
@property(nonatomic,copy) UIViewController *(^factory)(KAExternalClient *, NSDictionary *);
@property(nonatomic) UIViewController *content;
@property(nonatomic) NSTimer *timer;
@property(nonatomic) BOOL checking;
@end
@implementation KAProtectedRootController
- (instancetype)initWithContentFactory:(UIViewController *(^)(KAExternalClient *,NSDictionary *))factory {
    if ((self = [super init])) { _client = [KAExternalClient new]; _factory = [factory copy]; } return self;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = UIColor.blackColor;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locked:) name:KAExternalDidLockNotification object:self.client];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resign) name:UIApplicationWillResignActiveNotification object:nil];
    [self showLogin:nil allowAutomatic:YES];
}
- (void)resign { [self.client invalidate]; }
- (void)replace:(UIViewController *)next animated:(BOOL)animated {
    [self.content willMoveToParentViewController:nil]; [self.content.view removeFromSuperview]; [self.content removeFromParentViewController];
    self.content = next; [self addChildViewController:next]; next.view.frame = self.view.bounds;
    next.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:next.view]; [next didMoveToParentViewController:self];
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        next.view.alpha = 0; [UIView animateWithDuration:.25 animations:^{ next.view.alpha = 1; }];
    }
}
- (void)locked:(NSNotification *)notification {
    NSError *error = notification.userInfo[@"error"];
    BOOL automatic = [notification.userInfo[@"allowAutomatic"] boolValue];
    [self showLogin:error allowAutomatic:automatic];
}
- (void)showLogin:(NSError *)error allowAutomatic:(BOOL)automatic {
    [self.timer invalidate]; self.timer = nil; self.checking = NO;
    __weak typeof(self) weakSelf = self;
    KALicenseViewController *login = [[KALicenseViewController alloc] initWithClient:self.client onAuthorized:^(NSDictionary *license) {
        typeof(self) self = weakSelf; if (!self || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
        UIViewController *main = self.factory(self.client,license); if (!main) { [self.client invalidate]; return; }
        [self replace:main animated:YES];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:30 repeats:YES block:^(NSTimer *timer) {
            typeof(self) owner = weakSelf; if (!owner || owner.checking) return; owner.checking = YES;
            [owner.client revalidate:^(NSDictionary *value, NSError *error) { owner.checking = NO; }];
        }];
    }];
    login.allowAutoLogin = automatic; login.lockError = error;
    [self replace:login animated:NO];
}
- (void)dealloc { [self.timer invalidate]; [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end
