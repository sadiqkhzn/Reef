//
//  ReefLockWidget.m
//  A SecurityAgent authorization plugin that draws a small ambient widget
//  (clock, playing track, weather, battery) on the screensaver unlock screen.
//
//  SAFETY MODEL — display only, fail open:
//  This plugin is registered as a NON-credential mechanism. It never reads,
//  checks, or sets a password, and it ALWAYS tells the authorization engine to
//  allow and continue. Authentication is still done entirely by the system's
//  own mechanisms that run after this one. The worst this can do is fail to draw
//  its widget; it cannot block or weaken login. All UI work is wrapped so an
//  exception can never escape into the SecurityAgent.
//
//  It reads its content from /Library/Application Support/Reef/lockscreen.json,
//  which the Reef app writes. If the file is missing it just shows the clock.
//

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <Security/AuthorizationPlugin.h>

#pragma mark - Widget window

/// A borderless panel that shows the ambient widget during unlock.
@interface ReefWidgetPanel : NSObject
+ (instancetype)shared;
- (void)show;
- (void)hide;
@end

@interface ReefWidgetPanel ()
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTextField *clockField;
@property(nonatomic, strong) NSTextField *dateField;
@property(nonatomic, strong) NSTextField *infoField;
@property(nonatomic, strong) NSTimer *timer;
@end

@implementation ReefWidgetPanel

+ (instancetype)shared {
    static ReefWidgetPanel *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[ReefWidgetPanel alloc] init]; });
    return shared;
}

- (void)show {
    @try {
        [self buildIfNeeded];
        [self refresh];
        [self.window orderFrontRegardless];
        if (!self.timer) {
            self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          target:self
                                                        selector:@selector(refresh)
                                                        userInfo:nil
                                                         repeats:YES];
        }
    } @catch (__unused NSException *e) {
        // Never let a UI problem reach the authorization engine.
    }
}

- (void)hide {
    @try {
        [self.timer invalidate];
        self.timer = nil;
        [self.window orderOut:nil];
    } @catch (__unused NSException *e) {
    }
}

- (void)buildIfNeeded {
    if (self.window) {
        return;
    }

    NSRect frame = NSMakeRect(0, 0, 420, 180);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                  styleMask:NSWindowStyleMaskBorderless
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    window.opaque = NO;
    window.backgroundColor = [NSColor clearColor];
    window.level = NSScreenSaverWindowLevel + 1;
    window.ignoresMouseEvents = YES;
    window.hasShadow = NO;
    window.collectionBehavior =
        NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary;

    NSVisualEffectView *backdrop = [[NSVisualEffectView alloc] initWithFrame:frame];
    backdrop.material = NSVisualEffectMaterialHUDWindow;
    backdrop.state = NSVisualEffectStateActive;
    backdrop.wantsLayer = YES;
    backdrop.layer.cornerRadius = 22;
    backdrop.layer.masksToBounds = YES;

    NSTextField *clock = [self labelWithSize:64 weight:NSFontWeightSemibold];
    NSTextField *date = [self labelWithSize:18 weight:NSFontWeightMedium];
    NSTextField *info = [self labelWithSize:15 weight:NSFontWeightRegular];
    date.textColor = [NSColor colorWithWhite:1 alpha:0.7];
    info.textColor = [NSColor colorWithWhite:1 alpha:0.8];

    NSStackView *stack = [NSStackView stackViewWithViews:@[ clock, date, info ]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeCenterX;
    stack.spacing = 6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [backdrop addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:backdrop.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:backdrop.centerYAnchor],
    ]];

    window.contentView = backdrop;
    [self centerOnMainScreen:window];

    self.window = window;
    self.clockField = clock;
    self.dateField = date;
    self.infoField = info;
}

- (NSTextField *)labelWithSize:(CGFloat)size weight:(NSFontWeight)weight {
    NSTextField *label = [NSTextField labelWithString:@""];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = [NSColor whiteColor];
    label.alignment = NSTextAlignmentCenter;
    label.backgroundColor = [NSColor clearColor];
    label.bordered = NO;
    label.editable = NO;
    return label;
}

- (void)centerOnMainScreen:(NSWindow *)window {
    NSScreen *screen = [NSScreen mainScreen] ?: NSScreen.screens.firstObject;
    if (!screen) {
        return;
    }
    NSRect s = screen.frame;
    NSRect w = window.frame;
    CGFloat x = s.origin.x + (s.size.width - w.size.width) / 2;
    // Sit a little above vertical center so it reads as a header, clear of the
    // password field that sits in the middle.
    CGFloat y = s.origin.y + s.size.height * 0.62;
    [window setFrameOrigin:NSMakePoint(x, y)];
}

- (void)refresh {
    @try {
        NSDate *now = [NSDate date];

        NSDateFormatter *time = [[NSDateFormatter alloc] init];
        [time setLocalizedDateFormatFromTemplate:@"j:mm"];
        self.clockField.stringValue = [time stringFromDate:now];

        NSDateFormatter *date = [[NSDateFormatter alloc] init];
        [date setLocalizedDateFormatFromTemplate:@"EEEE d MMMM"];
        self.dateField.stringValue = [date stringFromDate:now];

        self.infoField.stringValue = [self infoLine];
    } @catch (__unused NSException *e) {
    }
}

- (NSString *)infoLine {
    NSDictionary *state = [self readState];
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    NSDictionary *playing = state[@"nowPlaying"];
    if ([playing isKindOfClass:NSDictionary.class]) {
        NSString *title = playing[@"title"];
        NSString *artist = playing[@"artist"];
        if ([title isKindOfClass:NSString.class] && title.length > 0) {
            NSString *line = title;
            if ([artist isKindOfClass:NSString.class] && artist.length > 0) {
                line = [NSString stringWithFormat:@"%@ — %@", title, artist];
            }
            [parts addObject:[NSString stringWithFormat:@"♪ %@", line]];
        }
    }

    NSDictionary *weather = state[@"weather"];
    if ([weather isKindOfClass:NSDictionary.class]) {
        NSString *temp = weather[@"temp"];
        NSString *condition = weather[@"condition"];
        if ([temp isKindOfClass:NSString.class]) {
            NSString *line = temp;
            if ([condition isKindOfClass:NSString.class] && condition.length > 0) {
                line = [NSString stringWithFormat:@"%@ %@", temp, condition];
            }
            [parts addObject:line];
        }
    }

    NSDictionary *battery = state[@"battery"];
    if ([battery isKindOfClass:NSDictionary.class]) {
        NSNumber *percent = battery[@"percent"];
        if ([percent isKindOfClass:NSNumber.class]) {
            BOOL charging = [battery[@"charging"] boolValue];
            [parts addObject:[NSString stringWithFormat:@"%@%%%@",
                                                        percent, charging ? @" ⚡" : @""]];
        }
    }

    return [parts componentsJoinedByString:@"   ·   "];
}

- (NSDictionary *)readState {
    @try {
        NSData *data = [NSData dataWithContentsOfFile:
                                   @"/Library/Application Support/Reef/lockscreen.json"];
        if (!data) {
            return @{};
        }
        id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        return [object isKindOfClass:NSDictionary.class] ? object : @{};
    } @catch (__unused NSException *e) {
        return @{};
    }
}

@end

#pragma mark - Authorization plugin interface

typedef struct {
    const AuthorizationCallbacks *callbacks;
} PluginRecord;

typedef struct {
    AuthorizationEngineRef engine;
    PluginRecord *plugin;
} MechanismRecord;

static OSStatus PluginDestroy(AuthorizationPluginRef inPlugin) {
    free(inPlugin);
    return errAuthorizationSuccess;
}

static OSStatus MechanismCreate(AuthorizationPluginRef inPlugin,
                                AuthorizationEngineRef inEngine,
                                AuthorizationMechanismId __unused mechanismId,
                                AuthorizationMechanismRef *outMechanism) {
    MechanismRecord *mechanism = (MechanismRecord *)malloc(sizeof(MechanismRecord));
    if (!mechanism) {
        return errAuthorizationInternal;
    }
    mechanism->engine = inEngine;
    mechanism->plugin = (PluginRecord *)inPlugin;
    *outMechanism = mechanism;
    return errAuthorizationSuccess;
}

static OSStatus MechanismInvoke(AuthorizationMechanismRef inMechanism) {
    MechanismRecord *mechanism = (MechanismRecord *)inMechanism;

    // Draw the widget on the main thread. This is best-effort and fully
    // guarded; nothing here can fail the authorization.
    void (^present)(void) = ^{
        @try {
            [[ReefWidgetPanel shared] show];
        } @catch (__unused NSException *e) {
        }
    };
    if ([NSThread isMainThread]) {
        present();
    } else {
        dispatch_async(dispatch_get_main_queue(), present);
    }

    // Always allow and hand control to the real authenticator. This mechanism
    // never gates login.
    OSStatus status = mechanism->plugin->callbacks->SetResult(mechanism->engine,
                                                              kAuthorizationResultAllow);
    return status;
}

static OSStatus MechanismDeactivate(AuthorizationMechanismRef inMechanism) {
    MechanismRecord *mechanism = (MechanismRecord *)inMechanism;

    void (^dismiss)(void) = ^{
        @try {
            [[ReefWidgetPanel shared] hide];
        } @catch (__unused NSException *e) {
        }
    };
    if ([NSThread isMainThread]) {
        dismiss();
    } else {
        dispatch_async(dispatch_get_main_queue(), dismiss);
    }

    return mechanism->plugin->callbacks->DidDeactivate(mechanism->engine);
}

static OSStatus MechanismDestroy(AuthorizationMechanismRef inMechanism) {
    free(inMechanism);
    return errAuthorizationSuccess;
}

static AuthorizationPluginInterface gInterface = {
    kAuthorizationPluginInterfaceVersion,
    &PluginDestroy,
    &MechanismCreate,
    &MechanismInvoke,
    &MechanismDeactivate,
    &MechanismDestroy,
};

/// Entry point the SecurityAgent calls to load the plugin.
OSStatus AuthorizationPluginCreate(const AuthorizationCallbacks *callbacks,
                                   AuthorizationPluginRef *outPlugin,
                                   const AuthorizationPluginInterface **outPluginInterface) {
    PluginRecord *plugin = (PluginRecord *)malloc(sizeof(PluginRecord));
    if (!plugin) {
        return errAuthorizationInternal;
    }
    plugin->callbacks = callbacks;
    *outPlugin = plugin;
    *outPluginInterface = &gInterface;
    return errAuthorizationSuccess;
}
