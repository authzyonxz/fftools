//
//  FFHomeViewController.m
//  FFPatch
//

#import "FFHomeViewController.h"
#import "FFWidgets.h"
#import "FFTheme.h"
#import "FFManifest.h"
#import "FFPatchEngine.h"
#import "FFSandbox.h"
#import "FFCore.h"
#import "FFContainerStore.h"

static NSString *const FFActiveGameDefaultsKey = @"FFActiveGameID";

@interface FFHomeViewController ()

@property (nonatomic, strong) FFManifest *manifest;
@property (nonatomic, strong) FFPatchEngine *engine;
@property (nonatomic, strong) FFGame *activeGame;
@property (nonatomic, strong) NSMutableDictionary<NSString *, FFFunctionRowView *> *rowViews;
@property (nonatomic, strong) NSMutableDictionary<NSString *, FFGameCardView *> *gameCards;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *accessBanner;
@property (nonatomic, assign) BOOL busy;

@end

@implementation FFHomeViewController

- (instancetype)initWithManifest:(FFManifest *)manifest {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _manifest = manifest;
        _engine = [FFPatchEngine sharedEngine];
        _engine.manifest = manifest;
        _rowViews = [NSMutableDictionary dictionary];
        _gameCards = [NSMutableDictionary dictionary];

        NSString *storedGameID = [[NSUserDefaults standardUserDefaults] stringForKey:FFActiveGameDefaultsKey];
        _activeGame = [manifest gameWithID:storedGameID ?: @""] ?: manifest.games.firstObject;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [FFTheme background];
    self.title = @"Início";

    [self buildScrollView];
    [self buildHeader];
    [self buildGameSelector];
    [self buildAccessBanner];
    [self buildGroups];
    [self reloadState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadState];
}

#pragma mark - Layout

- (void)buildScrollView {
    _scrollView = [UIScrollView new];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scrollView];

    _contentStack = [UIStackView new];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.alignment = UIStackViewAlignmentFill;
    _contentStack.spacing = 0;

    [_scrollView addSubview:_contentStack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [_contentStack.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor constant:8],
        [_contentStack.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor constant:-28],
        [_contentStack.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor constant:16],
        [_contentStack.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor constant:-16],
        [_contentStack.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor constant:-32],
    ]];
}

- (void)buildHeader {
    UILabel *title = [UILabel new];
    title.text = @"FUNÇÕES";
    title.font = [FFTheme titleFont];
    title.textColor = [FFTheme primaryText];
    title.textAlignment = NSTextAlignmentCenter;
    [_contentStack addArrangedSubview:title];
    [_contentStack setCustomSpacing:18 afterView:title];
}

- (void)buildGameSelector {
    NSMutableArray<UIView *> *cards = [NSMutableArray array];
    for (FFGame *game in self.manifest.games) {
        FFGameCardView *card = [[FFGameCardView alloc] initWithGame:game];
        [card addTarget:self action:@selector(gameCardTapped:) forControlEvents:UIControlEventTouchUpInside];
        [card setActive:[game.gameID isEqualToString:self.activeGame.gameID]];
        self.gameCards[game.gameID] = card;
        [cards addObject:card];
    }

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:cards];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 12;
    row.alignment = UIStackViewAlignmentFill;
    [_contentStack addArrangedSubview:row];
    [_contentStack setCustomSpacing:22 afterView:row];
}

- (void)buildAccessBanner {
    _accessBanner = [UIView new];
    _accessBanner.translatesAutoresizingMaskIntoConstraints = NO;
    _accessBanner.backgroundColor = [FFTheme card];
    _accessBanner.layer.cornerRadius = 14;
    _accessBanner.layer.cornerCurve = kCACornerCurveContinuous;

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.tag = 401;
    label.font = [FFTheme rowSubtitleFont];
    label.textColor = [FFTheme secondaryText];
    label.numberOfLines = 0;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = 402;
    [button setTitle:@"DESBLOQUEAR" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [button setTitleColor:[FFTheme accent] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(unlockTapped) forControlEvents:UIControlEventTouchUpInside];

    [_accessBanner addSubview:label];
    [_accessBanner addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:_accessBanner.topAnchor constant:12],
        [label.leadingAnchor constraintEqualToAnchor:_accessBanner.leadingAnchor constant:14],
        [label.trailingAnchor constraintEqualToAnchor:_accessBanner.trailingAnchor constant:-14],

        [button.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:8],
        [button.leadingAnchor constraintEqualToAnchor:_accessBanner.leadingAnchor constant:14],
        [button.bottomAnchor constraintEqualToAnchor:_accessBanner.bottomAnchor constant:-10],
    ]];

    [_contentStack addArrangedSubview:_accessBanner];
    [_contentStack setCustomSpacing:20 afterView:_accessBanner];
    [self refreshAccessBanner];
}

- (void)buildGroups {
    for (FFGroup *group in self.manifest.groups) {
        FFSectionHeaderView *header = [[FFSectionHeaderView alloc] initWithTitle:group.title];
        [_contentStack addArrangedSubview:header];
        [_contentStack setCustomSpacing:8 afterView:header];

        NSMutableArray<FFFunctionRowView *> *rows = [NSMutableArray array];
        for (FFFunction *function in group.functions) {
            FFFunctionRowView *row = [[FFFunctionRowView alloc] initWithTitle:function.name
                                                                    subtitle:function.subtitle];
            __weak typeof(self) weakSelf = self;
            row.onToggle = ^(BOOL isOn) {
                [weakSelf handleToggleForFunction:function isOn:isOn row:row];
            };
            self.rowViews[function.funcID] = row;
            [rows addObject:row];
        }

        FFGroupCardView *card = [[FFGroupCardView alloc] initWithRows:rows];
        [_contentStack addArrangedSubview:card];
        [_contentStack setCustomSpacing:22 afterView:card];
    }
}

#pragma mark - State

- (void)reloadState {
    if (self.activeGame == nil) return;
    for (FFGameCardView *card in self.gameCards.allValues) {
        [card setActive:[card.game isEqual:self.activeGame]];
    }
    for (FFGroup *group in self.manifest.groups) {
        for (FFFunction *function in group.functions) {
            FFFunctionRowView *row = self.rowViews[function.funcID];
            if (row == nil) continue;
            FFFunctionState state = [self.engine stateForFunction:function game:self.activeGame];
            [row setOn:(state == FFFunctionStateApplied) animated:NO];
        }
    }
    [self refreshAccessBanner];
}

- (void)refreshAccessBanner {
    UILabel *label = [_accessBanner viewWithTag:401];
    UIButton *button = [_accessBanner viewWithTag:402];
    if (label == nil || button == nil) return;

    if (!FFSandboxOSIsSupported()) {
        label.text = FFSandboxUnsupportedReason();
        label.textColor = [FFTheme failure];
        button.hidden = YES;
        _accessBanner.hidden = NO;
        return;
    }

    BOOL active = FFSandboxAccessActive();
    label.text = [NSString stringWithFormat:@"backend %@ · %@",
                  FFSandboxBackendNameCurrent(),
                  active ? @"acesso ao container ativo" : @"acesso ainda não liberado"];
    label.textColor = active ? [FFTheme secondaryText] : [FFTheme accent];
    button.hidden = active;
    _accessBanner.hidden = active;
}

#pragma mark - Actions

- (void)gameCardTapped:(FFGameCardView *)sender {
    if (self.busy) return;
    if ([sender.game isEqual:self.activeGame]) return;
    self.activeGame = sender.game;
    [[NSUserDefaults standardUserDefaults] setObject:self.activeGame.gameID
                                             forKey:FFActiveGameDefaultsKey];
    [self reloadState];
    FFLog(@"ui: jogo ativo → %@ (%@)", self.activeGame.displayName, self.activeGame.bundleID);
}

- (void)unlockTapped {
    if (self.busy) return;
    self.busy = YES;
    FFStatusAlertView *hud = [FFStatusAlertView showActivityWithTitle:@"DESBLOQUEANDO"
                                                              detail:@"cadeia de acesso ao container"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *detail = nil;
        BOOL ok = FFSandboxActivate(&detail);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO;
            [hud dismiss];
            if (ok) {
                FFStatusAlertView *alert = [FFStatusAlertView showWithStyle:FFAlertStyleSuccess
                                                                      title:@"STATUS"
                                                                    message:@"ACESSO LIBERADO"
                                                                     detail:detail];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    [alert dismiss];
                });
            } else {
                [FFStatusAlertView showWithStyle:FFAlertStyleFailure
                                            title:@"STATUS"
                                          message:@"FALHA NO DESBLOQUEIO"
                                           detail:detail];
            }
            [self reloadState];
        });
    });
}

- (void)handleToggleForFunction:(FFFunction *)function
                           isOn:(BOOL)isOn
                            row:(FFFunctionRowView *)row {
    if (self.busy) {
        [row setOn:!isOn animated:YES];
        return;
    }
    self.busy = YES;
    [self setRowsEnabled:NO];

    NSString *title = isOn ? @"APLICANDO" : @"RESTAURANDO";
    NSString *detailText = [NSString stringWithFormat:@"%@ · %@", function.name, self.activeGame.displayName];
    FFStatusAlertView *hud = [FFStatusAlertView showActivityWithTitle:title detail:detailText];

    FFGame *game = self.activeGame;
    FFGroup *group = [self.manifest groupForFunction:function];
    NSArray<FFFunction *> *siblings = (group != nil && group.exclusive)
        ? [self.manifest siblingsOfFunction:function] : @[];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        NSUInteger fileCount = 0;
        FFPatchApplyStats *stats = nil;
        BOOL success = NO;

        if (!FFSandboxAccessActive()) {
            FFSandboxActivate(NULL);
        }

        if (isOn) {
            // Exclusive groups (aimbot): only one posture may be injected at a
            // time, so the siblings are restored before the new payload lands.
            for (FFFunction *sibling in siblings) {
                if ([self.engine stateForFunction:sibling game:game] == FFFunctionStateApplied) {
                    [self.engine restoreFunction:sibling game:game error:NULL];
                }
            }
            fileCount = [self.engine payloadFileCountForFunction:function game:game];
            success = [self.engine applyFunction:function game:game stats:&stats error:&error];
            if (success && stats != nil) fileCount = stats.fileCount;
        } else {
            FFPatchReceipt *receipt = [self.engine receiptForFunction:function game:game];
            fileCount = receipt.fileCount;
            success = [self.engine restoreFunction:function game:game error:&error];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO;
            [hud dismiss];
            [self setRowsEnabled:YES];
            [self reloadState];
            [self showResultForFunction:function
                                 isOn:isOn
                                success:success
                                fileCount:fileCount
                                  stats:stats
                                  error:error];
        });
    });
}

- (void)showResultForFunction:(FFFunction *)function
                         isOn:(BOOL)isOn
                      success:(BOOL)success
                    fileCount:(NSUInteger)fileCount
                        stats:(FFPatchApplyStats *)stats
                        error:(NSError *)error {
    NSString *detail = [NSString stringWithFormat:@"ID %@ · %@ · %@ · %lu arquivo%@",
                        function.funcID, function.name, self.activeGame.displayName,
                        (unsigned long)fileCount, fileCount == 1 ? @"" : @"s"];
    if (stats.usedContainerSearch) {
        detail = [detail stringByAppendingFormat:@" · varredura: %lu entradas",
                  (unsigned long)stats.scannedEntries];
    }

    if (success) {
        NSString *message = isOn ? @"INJETADO COM SUCESSO" : @"RESTAURADO COM SUCESSO";
        [FFStatusAlertView showWithStyle:FFAlertStyleSuccess
                                    title:@"STATUS"
                                  message:message
                                   detail:detail];
        return;
    }

    NSString *reason = error.localizedDescription;
    if (reason.length == 0) reason = @"falha desconhecida";
    FFLog(@"ui: %@ %@ falhou — %@", function.name, isOn ? @"apply" : @"restore", reason);
    [FFStatusAlertView showWithStyle:FFAlertStyleFailure
                                title:@"STATUS"
                              message:@"FALHA NA OPERAÇÃO"
                               detail:reason];
}

- (void)setRowsEnabled:(BOOL)enabled {
    for (FFFunctionRowView *row in self.rowViews.allValues) {
        [row setInteractionEnabled:enabled];
    }
}

@end
