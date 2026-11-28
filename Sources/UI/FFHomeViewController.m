

#import "FFHomeViewController.h"
#import "FFWidgets.h"
#import "FFTheme.h"
#import "FFManifest.h"
#import "FFPatchEngine.h"
#import "FFSandbox.h"
#import "FFCore.h"
#import "FFContainerStore.h"
#import "FFCatalogClient.h"
#import "FFLicense.h"

static NSString *const FFActiveGameDefaultsKey = @"FFActiveGameID";

static BOOL FFIsMaxGame(FFGame *game) {
    return [game.gameID.lowercaseString isEqualToString:@"freefiremax"] ||
           [game.bundleID.lowercaseString isEqualToString:@"com.dts.freefiremax"];
}

static FFGame *FFNormalGame(FFManifest *manifest) {
    FFGame *normal = [manifest gameWithID:@"freefireth"];
    if (normal != nil && !FFIsMaxGame(normal)) return normal;
    for (FFGame *game in manifest.games) {
        if (!FFIsMaxGame(game)) return game;
    }
    return nil;
}

@interface FFHomeViewController ()

@property (nonatomic, strong) FFManifest *manifest;
@property (nonatomic, strong) FFPatchEngine *engine;
@property (nonatomic, strong) FFGame *activeGame;
@property (nonatomic, strong) NSMutableDictionary<NSString *, FFFunctionRowView *> *rowViews;
@property (nonatomic, strong) NSMutableDictionary<NSString *, FFGameCardView *> *gameCards;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<UIView *> *> *groupContainers;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
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
        _groupContainers = [NSMutableDictionary dictionary];

        NSString *storedGameID = [[NSUserDefaults standardUserDefaults] stringForKey:FFActiveGameDefaultsKey];
        FFGame *storedGame = [manifest gameWithID:storedGameID ?: @""];
        _activeGame = FFIsMaxGame(storedGame) ? FFNormalGame(manifest) : storedGame;
        if (_activeGame == nil) _activeGame = FFNormalGame(manifest) ?: manifest.games.firstObject;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [FFTheme background];
    [FFTheme installBackgroundInView:self.view];
    self.title = @"Início";

    [self buildScrollView];
    [self buildHeader];
    [self buildGameSelector];
    [self buildGroups];
    [self buildEmptyState];
    [self reloadState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [FFTheme animateEntrance:self.view];
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
            __weak FFFunctionRowView *weakRow = row;
            row.onToggle = ^(BOOL isOn) {
                __strong FFFunctionRowView *strongRow = weakRow;
                if (strongRow == nil) return;
                [weakSelf handleToggleForFunction:function isOn:isOn row:strongRow];
            };
            self.rowViews[function.funcID] = row;
            [rows addObject:row];
        }

        FFGroupCardView *card = [[FFGroupCardView alloc] initWithRows:rows];
        [_contentStack addArrangedSubview:card];
        [_contentStack setCustomSpacing:22 afterView:card];
        self.groupContainers[group.groupID] = @[header, card];
    }
}

- (void)buildEmptyState {
    UIView *container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"Nenhuma função publicada";
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    label.textColor = [FFTheme secondaryText];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:@"ATUALIZAR CATÁLOGO" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [button setTitleColor:[FFTheme accent] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(requestCatalogSync) forControlEvents:UIControlEventTouchUpInside];

    [container addSubview:label];
    [container addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:container.topAnchor constant:40],
        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:24],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-24],
        [button.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:14],
        [button.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [button.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-8],
    ]];

    self.emptyStateView = container;
    [_contentStack addArrangedSubview:container];
    container.hidden = YES;
}

- (void)requestCatalogSync {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FFCatalogSyncRequestNotification"
                                                        object:nil];
}

#pragma mark - State

- (void)reloadState {
    if (self.activeGame == nil) return;
    for (FFGameCardView *card in self.gameCards.allValues) {
        [card setActive:[card.game isEqual:self.activeGame]];
    }
    BOOL anyVisible = NO;

    for (FFGroup *group in self.manifest.groups) {
        BOOL groupVisible = NO;
        for (FFFunction *function in group.functions) {
            FFFunctionRowView *row = self.rowViews[function.funcID];
            if (row == nil) continue;

            BOOL supported = function.supportedGames.count == 0 ||
                [function.supportedGames containsObject:self.activeGame.gameID];
            NSString *status = function.publicationStatus.length ? function.publicationStatus : @"active";
            BOOL maintenance = ![status isEqualToString:@"active"];

            row.hidden = !supported;
            if (!supported) {
                [row setOn:NO animated:NO];
                continue;
            }
            groupVisible = YES;
            anyVisible = YES;

            if (maintenance) {
                [row setSubtitleText:[status isEqualToString:@"maintenance"]
                    ? @"EM MANUTENÇÃO" : @"DESATIVADA"];
                [row setInteractionEnabled:NO];
                [row setOn:NO animated:NO];
                continue;
            }
            [row setSubtitleText:function.subtitle];
            [row setInteractionEnabled:!self.busy];
            FFFunctionState state = [self.engine stateForFunction:function game:self.activeGame];
            [row setOn:(state == FFFunctionStateApplied) animated:NO];
        }

        NSArray<UIView *> *views = self.groupContainers[group.groupID];
        for (UIView *view in views) {
            view.hidden = !groupVisible;
        }
    }

    self.emptyStateView.hidden = anyVisible || self.manifest.groups.count > 0;
}

#pragma mark - Actions

- (void)gameCardTapped:(FFGameCardView *)sender {
    if (FFIsMaxGame(sender.game)) {
        FFGame *normal = FFNormalGame(self.manifest);
        if (normal != nil) {
            self.activeGame = normal;
            [[NSUserDefaults standardUserDefaults] setObject:normal.gameID
                                                     forKey:FFActiveGameDefaultsKey];
            [self reloadState];
        }
        [self presentMaintenanceAlert];
        FFLog(@"ui: Free Fire MAX em manutenção; Free Fire normal selecionado");
        return;
    }
    if (self.busy) return;
    if ([sender.game isEqual:self.activeGame]) return;
    self.activeGame = sender.game;
    [[NSUserDefaults standardUserDefaults] setObject:self.activeGame.gameID
                                             forKey:FFActiveGameDefaultsKey];
    [self reloadState];
    FFLog(@"ui: jogo ativo → %@ (%@)", self.activeGame.displayName, self.activeGame.bundleID);
}

- (void)handleToggleForFunction:(FFFunction *)function
                           isOn:(BOOL)isOn
                            row:(FFFunctionRowView *)row {
    FFLicense *license = [FFLicense current];
    if (isOn && !license.apiValidated) {
        [row setOn:NO animated:YES];
        return;
    }
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

    dispatch_block_t performOperation = ^{
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *error = nil;
            BOOL success = NO;

            if (isOn) {

                if (!FFSandboxAccessActive()) {
                    NSString *activationDetail = nil;
                    BOOL activated = FFSandboxActivate(&activationDetail);
                    FFLog(@"ui: probe inativo (ativação %@) — tentando apply mesmo assim",
                          activated ? @"OK" : (activationDetail ?: @"falhou"));
                }
                if (!FFSandboxOSIsSupported()) {
                    error = FFMakeError(FFErrorUnsupportedOS, @"%@", FFSandboxUnsupportedReason());
                } else {

                    for (FFFunction *sibling in siblings) {
                        if ([self.engine stateForFunction:sibling game:game] == FFFunctionStateApplied) {
                            [self.engine restoreFunction:sibling game:game error:NULL];
                        }
                    }
                    success = [self.engine applyFunction:function game:game stats:NULL error:&error];
                }
            } else {

                FFSandboxWaitForActivation();
                if (FFSandboxCurrentBackend() == FFSandboxBackendKernel && !FFSandboxAccessActive()) {
                    error = FFMakeError(FFErrorNoSandboxAccess, @"acesso ao container não está ativo");
                } else {
                    success = [self.engine restoreFunction:function game:game error:&error];
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                self.busy = NO;
                [hud dismiss];
                [self setRowsEnabled:YES];
                [self reloadState];
                [self showResultForFunction:function
                                     isOn:isOn
                                    success:success
                                      error:error];
            });
        });
    };

    performOperation();
}

- (void)showResultForFunction:(FFFunction *)function
                         isOn:(BOOL)isOn
                      success:(BOOL)success
                        error:(NSError *)error {
    if (success) {
        [self presentSystemAlertWithMessage:isOn ? @"INJETADO COM SUCESSO" : @"RESTAURADO COM SUCESSO"];
        return;
    }

    NSString *shortMessage = FFUserMessageForError(error);
    FFLog(@"ui: %@ %@ falhou — %@ (%@)", function.name, isOn ? @"apply" : @"restore",
          shortMessage, error.localizedDescription ?: @"sem detalhe");
    [self presentSystemAlertWithMessage:shortMessage.uppercaseString];
}

- (void)presentSystemAlertWithMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Fechar"
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (self.viewIfLoaded.window != nil && self.presentedViewController == nil) {
            [self presentViewController:alert animated:YES completion:nil];
        }
    });
}

- (void)presentMaintenanceAlert {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Manutenção"
                         message:@"As funções do Free Fire MAX estão em manutenção e ficarão disponíveis em breve. Use o Free Fire normal enquanto isso."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Entendi"
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.viewIfLoaded.window != nil && self.presentedViewController == nil) {
            [self presentViewController:alert animated:YES completion:nil];
        }
    });
}

- (void)setRowsEnabled:(BOOL)enabled {
    for (FFFunctionRowView *row in self.rowViews.allValues) {
        [row setInteractionEnabled:enabled];
    }
}

@end
