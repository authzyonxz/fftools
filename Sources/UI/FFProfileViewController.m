

#import "FFProfileViewController.h"
#import "FFWidgets.h"
#import "FFTheme.h"
#import "FFLicense.h"
#import "FFManifest.h"
#import "FFPatchEngine.h"
#import "FFSandbox.h"
#import "FFCore.h"
#import "FFCatalogClient.h"

#pragma mark - Value row

@interface FFValueRowView : UIView
@property (nonatomic, readonly) UILabel *valueLabel;
@property (nonatomic, strong) UILabel *titleLabel;
- (instancetype)initWithTitle:(NSString *)title value:(NSString *)value monospaced:(BOOL)monospaced;
@end

@implementation FFValueRowView

- (instancetype)initWithTitle:(NSString *)title value:(NSString *)value monospaced:(BOOL)monospaced {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _titleLabel = [UILabel new];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.text = title.uppercaseString;
        _titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        _titleLabel.textColor = [FFTheme secondaryText];
        _titleLabel.numberOfLines = 1;

        _valueLabel = [UILabel new];
        _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _valueLabel.text = value;
        _valueLabel.font = monospaced ? [FFTheme monoFont] : [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _valueLabel.textColor = [FFTheme primaryText];
        _valueLabel.numberOfLines = 0;

        [self addSubview:_titleLabel];
        [self addSubview:_valueLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:11],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-16],

            [_valueLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3],
            [_valueLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [_valueLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            [_valueLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-11],
        ]];
    }
    return self;
}

@end

#pragma mark - Profile

@interface FFProfileViewController ()
@property (nonatomic, strong) FFManifest *manifest;
@property (nonatomic, strong) FFPatchEngine *engine;
@property (nonatomic, strong) NSMutableArray<UIView *> *builtViews;
@end

@implementation FFProfileViewController

- (instancetype)initWithManifest:(FFManifest *)manifest {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _manifest = manifest;
        _engine = [FFPatchEngine sharedEngine];
        _builtViews = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [FFTheme background];
    [FFTheme installBackgroundInView:self.view];
    self.title = @"Perfil";
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(licenseDidUpdate:)
                                                 name:FFLicenseDidUpdateNotification
                                               object:nil];
    [self rebuild];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [FFTheme animateEntrance:self.view];
    [self rebuild];
}

- (void)licenseDidUpdate:(NSNotification *)notification {
    (void)notification;
    if (self.isViewLoaded) [self rebuild];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)rebuild {
    for (UIView *view in _builtViews) [view removeFromSuperview];
    [_builtViews removeAllObjects];

    FFLicense *license = [FFLicense current];

    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];
    [_builtViews addObject:scroll];

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    [scroll addSubview:stack];
    [_builtViews addObject:stack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:10],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-28],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32],
    ]];

    UILabel *title = [UILabel new];
    title.text = @"PERFIL";
    title.font = [FFTheme titleFont];
    title.textColor = [FFTheme primaryText];
    title.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:title];

    NSArray<FFValueRowView *> *licenseRows = @[
        [[FFValueRowView alloc] initWithTitle:@"Expiração" value:license.duration monospaced:NO],
        [[FFValueRowView alloc] initWithTitle:@"Status" value:license.status monospaced:NO],
        [[FFValueRowView alloc] initWithTitle:@"Package" value:license.packageName monospaced:YES],
        [[FFValueRowView alloc] initWithTitle:@"Versões compatíveis" value:license.compatibleRanges monospaced:NO],
        [[FFValueRowView alloc] initWithTitle:@"Build" value:license.build monospaced:YES],
    ];
    [stack addArrangedSubview:[self cardWithRows:licenseRows]];

    NSArray<FFValueRowView *> *deviceRows = @[
        [[FFValueRowView alloc] initWithTitle:@"Modelo" value:license.deviceModel monospaced:YES],
        [[FFValueRowView alloc] initWithTitle:@"iOS" value:license.deviceOS monospaced:NO],
        [[FFValueRowView alloc] initWithTitle:@"Build do sistema" value:license.deviceBuild monospaced:YES],
        [[FFValueRowView alloc] initWithTitle:@"Backend" value:license.sandboxBackend monospaced:YES],
    ];
    [stack addArrangedSubview:[self cardWithRows:deviceRows]];

    UIButton *syncButton = [UIButton buttonWithType:UIButtonTypeSystem];
    syncButton.translatesAutoresizingMaskIntoConstraints = NO;
    [syncButton setTitle:@"SINCRONIZAR CATÁLOGO" forState:UIControlStateNormal];
    syncButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [syncButton setTitleColor:[FFTheme primaryText] forState:UIControlStateNormal];
    syncButton.backgroundColor = [FFTheme card];
    syncButton.layer.cornerRadius = 14;
    syncButton.layer.cornerCurve = kCACornerCurveContinuous;
    [syncButton.heightAnchor constraintEqualToConstant:48].active = YES;
    [syncButton addTarget:self action:@selector(syncCatalogTapped) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:syncButton];

    UIButton *reactivateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    reactivateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [reactivateButton setTitle:@"REATIVAR ACESSO" forState:UIControlStateNormal];
    reactivateButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [reactivateButton setTitleColor:[FFTheme accent] forState:UIControlStateNormal];
    reactivateButton.backgroundColor = [FFTheme card];
    reactivateButton.layer.cornerRadius = 14;
    reactivateButton.layer.cornerCurve = kCACornerCurveContinuous;
    [reactivateButton.heightAnchor constraintEqualToConstant:48].active = YES;
    [reactivateButton addTarget:self action:@selector(reactivateAccessTapped) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:reactivateButton];

    UIButton *restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    restoreButton.translatesAutoresizingMaskIntoConstraints = NO;
    [restoreButton setTitle:@"RESTAURAR ORIGINAIS" forState:UIControlStateNormal];
    restoreButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [restoreButton setTitleColor:[FFTheme failure] forState:UIControlStateNormal];
    restoreButton.backgroundColor = [FFTheme card];
    restoreButton.layer.cornerRadius = 14;
    restoreButton.layer.cornerCurve = kCACornerCurveContinuous;
    [restoreButton.heightAnchor constraintEqualToConstant:48].active = YES;
    [restoreButton addTarget:self action:@selector(restoreAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:restoreButton];

    UIButton *logButton = [UIButton buttonWithType:UIButtonTypeSystem];
    logButton.translatesAutoresizingMaskIntoConstraints = NO;
    [logButton setTitle:@"EXPORTAR DIAGNÓSTICO" forState:UIControlStateNormal];
    logButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [logButton setTitleColor:[FFTheme primaryText] forState:UIControlStateNormal];
    logButton.backgroundColor = [FFTheme card];
    logButton.layer.cornerRadius = 14;
    logButton.layer.cornerCurve = kCACornerCurveContinuous;
    [logButton.heightAnchor constraintEqualToConstant:48].active = YES;
    [logButton addTarget:self action:@selector(exportDiagnosticsTapped) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:logButton];
}

- (UIView *)cardWithRows:(NSArray<FFValueRowView *> *)rows {
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [FFTheme card];
    card.layer.cornerRadius = 14;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.clipsToBounds = YES;

    UIView *previous = nil;
    for (NSUInteger index = 0; index < rows.count; index++) {
        UIView *row = rows[index];
        [card addSubview:row];

        if (index + 1 < rows.count) {
            UIView *separator = [UIView new];
            separator.translatesAutoresizingMaskIntoConstraints = NO;
            separator.backgroundColor = [FFTheme separator];
            [card addSubview:separator];
            [NSLayoutConstraint activateConstraints:@[
                [separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
                [separator.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
                [separator.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
                [separator.topAnchor constraintEqualToAnchor:row.bottomAnchor],
            ]];
        }

        if (previous == nil) {
            [row.topAnchor constraintEqualToAnchor:card.topAnchor].active = YES;
        } else {
            [row.topAnchor constraintEqualToAnchor:previous.bottomAnchor].active = YES;
        }
        [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor].active = YES;
        [row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor].active = YES;
        previous = row;
    }
    if (previous != nil) {
        [previous.bottomAnchor constraintEqualToAnchor:card.bottomAnchor].active = YES;
    }
    return card;
}

#pragma mark - Actions

- (void)reactivateAccessTapped {
    FFSandboxClearKernelCrashGuard();
    FFSandboxInvalidateCaches();
    FFStatusAlertView *hud = [FFStatusAlertView showActivityWithTitle:@"REATIVANDO"
                                                              detail:@"backend de sandbox"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *detail = nil;
        BOOL ok = FFSandboxActivate(&detail);
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismiss];
            if (ok) {
                [FFStatusAlertView showWithStyle:FFAlertStyleSuccess
                                            title:@"STATUS"
                                          message:@"ACESSO ATIVO"
                                           detail:detail];
            } else {
                [FFStatusAlertView showWithStyle:FFAlertStyleFailure
                                            title:@"STATUS"
                                          message:FFUserMessageForError(FFMakeError(FFErrorNoSandboxAccess, @"%@", detail ?: @"")).uppercaseString
                                           detail:detail];
            }
            [self rebuild];
        });
    });
}

- (void)syncCatalogTapped {
    FFStatusAlertView *hud = [FFStatusAlertView showActivityWithTitle:@"SINCRONIZANDO"
                                                              detail:@"catálogo de funções"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        FFCatalogResult *result = [[FFCatalogClient sharedClient] syncWithTimeout:15.0];
        NSUInteger functions = 0;
        for (FFGroup *group in result.manifest.groups) functions += group.functions.count;
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismiss];
            if (functions == 0) {
                [FFStatusAlertView showWithStyle:FFAlertStyleFailure
                                            title:@"STATUS"
                                          message:FFUserMessageForError(result.error).uppercaseString
                                           detail:@"verifique a conexão e a URL do catálogo"];
            } else {
                [FFStatusAlertView showWithStyle:FFAlertStyleSuccess
                                            title:@"STATUS"
                                          message:@"CATÁLOGO ATUALIZADO"
                                           detail:[NSString stringWithFormat:@"%lu função(ões) disponíveis",
                                               (unsigned long)functions]];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:FFCatalogDidSyncNotification
                                                                object:result];
        });
    });
}

- (void)restoreAllTapped {
    UIAlertController *confirm = [UIAlertController
        alertControllerWithTitle:@"Restaurar originais"
                         message:@"Todos os arquivos injetados voltam para os bytes originais do container. "
                                 @"Esta é a única operação irreversível do motor — o backup é preservado em disco."
                  preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Restaurar" style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *action) {
        [weakSelf performRestoreAll];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)performRestoreAll {
    FFStatusAlertView *hud = [FFStatusAlertView showActivityWithTitle:@"RESTAURANDO" detail:@"todos os arquivos"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSUInteger restored = 0;
        NSError *error = nil;
        [self.engine restoreAllWithError:&error restoredCount:&restored];
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismiss];
            if (error != nil) {
                [FFStatusAlertView showWithStyle:FFAlertStyleFailure
                                            title:@"STATUS"
                                          message:@"FALHA AO RESTAURAR"
                                           detail:error.localizedDescription];
            } else {
                [FFStatusAlertView showWithStyle:FFAlertStyleSuccess
                                            title:@"STATUS"
                                          message:@"ORIGINAIS RESTAURADOS"
                                           detail:[NSString stringWithFormat:
                                               @"%lu função(ões) revertida(s)", (unsigned long)restored]];
            }
            [self rebuild];
        });
    });
}

- (void)exportDiagnosticsTapped {
    NSString *logPath = FFLogFilePath();
    NSArray *items = [[NSFileManager defaultManager] fileExistsAtPath:logPath]
        ? @[[NSURL fileURLWithPath:logPath]] : @[];
    if (items.count == 0) {
        [FFStatusAlertView showWithStyle:FFAlertStyleInfo
                                    title:@"STATUS"
                                  message:@"SEM LOG"
                                   detail:@"nenhum evento registrado nesta sessão"];
        return;
    }
    UIActivityViewController *controller = [[UIActivityViewController alloc]
        initWithActivityItems:items applicationActivities:nil];
    [self presentViewController:controller animated:YES completion:nil];
}

@end
