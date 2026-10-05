#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <MediaPlayer/MediaPlayer.h>
#import "LPLyricFetcher.h"
#import "LPLyricHUDView.h"

#ifdef __cplusplus
extern "C" {
#endif
void MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_queue_t queue);
void MRMediaRemoteGetNowPlayingInfo(dispatch_queue_t queue, void (^block)(CFDictionaryRef information));
#ifdef __cplusplus
}
#endif

static NSString * const kLPPrefsIdentifier = @"com.domgur0.lyric";
static CFStringRef const kLPPrefsReloadNotificationCF = CFSTR("com.domgur0.lyric/preferenceschanged");

@interface LPLyricPluginManager : NSObject
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) LPLyricHUDView *hudView;
@property (nonatomic, strong) NSDictionary *preferences;
@property (nonatomic, strong) LPLyricFetcher *fetcher;
@property (nonatomic, strong) LPLyricDocument *document;
@property (nonatomic, copy) NSString *lastTrackIdentifier;
@property (nonatomic, assign) NSTimeInterval baseElapsed;
@property (nonatomic, assign) float playbackRate;
@property (nonatomic, strong) NSDate *snapshotDate;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSDate *lastLyricUpdate;
@end

@implementation LPLyricPluginManager

+ (instancetype)shared {
    static LPLyricPluginManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[LPLyricPluginManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _fetcher = [[LPLyricFetcher alloc] init];
        _playbackRate = 1.0;
    }
    return self;
}

- (void)start {
    [self reloadPreferences];
    [self createHUDIfNeeded];
    [self registerPreferenceNotifications];
    [self registerMediaNotifications];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / 24.0) target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [self.timer fire];
}

- (void)registerPreferenceNotifications {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), preferenceReloadCallback, kLPPrefsReloadNotificationCF, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}

- (void)registerMediaNotifications {
    MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_get_main_queue());
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), mediaInfoChangedCallback, CFSTR("kMRMediaRemoteNowPlayingInfoDidChangeNotification"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), mediaInfoChangedCallback, CFSTR("kMRMediaRemoteNowPlayingApplicationDidChangeNotification"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    [self refreshNowPlayingInfo];
}

static void preferenceReloadCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[LPLyricPluginManager shared] reloadPreferences];
}

static void mediaInfoChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[LPLyricPluginManager shared] refreshNowPlayingInfo];
}

- (void)createHUDIfNeeded {
    if (self.window) {
        return;
    }

    CGRect bounds = UIScreen.mainScreen.bounds;
    CGFloat width = MIN(CGRectGetWidth(bounds) - 24, 360);
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake((CGRectGetWidth(bounds) - width) / 2.0, 96, width, 74)];
    self.window.windowLevel = UIWindowLevelStatusBar + 200;
    self.window.hidden = NO;
    self.window.backgroundColor = UIColor.clearColor;

    self.hudView = [[LPLyricHUDView alloc] initWithFrame:self.window.bounds];
    self.hudView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.window addSubview:self.hudView];

    [self applyPreferencesToUI];
}

- (void)reloadPreferences {
    CFArrayRef keys = CFPreferencesCopyKeyList((CFStringRef)kLPPrefsIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (keys) {
        for (id key in (__bridge NSArray *)keys) {
            CFPropertyListRef value = CFPreferencesCopyAppValue((CFStringRef)key, (CFStringRef)kLPPrefsIdentifier);
            if (value) {
                dict[key] = (__bridge id)value;
                CFRelease(value);
            }
        }
        CFRelease(keys);
    }

    if (!dict[@"enabled"]) {
        dict[@"enabled"] = @YES;
    }
    if (!dict[@"fontSize"]) {
        dict[@"fontSize"] = @24;
    }
    if (!dict[@"baseColor"]) {
        dict[@"baseColor"] = @"#FFFFFF";
    }
    if (!dict[@"progressColor"]) {
        dict[@"progressColor"] = @"#63F2FF";
    }
    if (!dict[@"yOffset"]) {
        dict[@"yOffset"] = @96;
    }
    if (!dict[@"autoHideSeconds"]) {
        dict[@"autoHideSeconds"] = @6;
    }
    if (!dict[@"showNextLine"]) {
        dict[@"showNextLine"] = @YES;
    }
    if (!dict[@"hudWidth"]) {
        dict[@"hudWidth"] = @360;
    }
    if (!dict[@"hudHeight"]) {
        dict[@"hudHeight"] = @74;
    }
    if (!dict[@"xOffset"]) {
        dict[@"xOffset"] = @(-1);
    }
    if (!dict[@"hudOpacity"]) {
        dict[@"hudOpacity"] = @1.0;
    }
    if (!dict[@"cornerRadius"]) {
        dict[@"cornerRadius"] = @14;
    }

    self.preferences = dict.copy;
    [self applyPreferencesToUI];
}

- (void)applyPreferencesToUI {
    if (!self.window || !self.hudView) {
        return;
    }

    [self.hudView applyPreferences:self.preferences];

    CGRect bounds = UIScreen.mainScreen.bounds;
    CGFloat width = MIN(MAX([self.preferences[@"hudWidth"] doubleValue], 180.0), MAX(180.0, CGRectGetWidth(bounds) - 12.0));
    CGFloat height = MIN(MAX([self.preferences[@"hudHeight"] doubleValue], 52.0), MAX(52.0, CGRectGetHeight(bounds) - 12.0));
    CGFloat maxX = MAX(6.0, CGRectGetWidth(bounds) - width - 6.0);
    CGFloat maxY = MAX(6.0, CGRectGetHeight(bounds) - height - 6.0);
    CGFloat xOffset = [self.preferences[@"xOffset"] doubleValue];
    CGFloat x = xOffset < 0 ? ((CGRectGetWidth(bounds) - width) / 2.0) : MIN(MAX(xOffset, 6.0), maxX);
    CGFloat y = MIN(MAX([self.preferences[@"yOffset"] doubleValue], 6.0), maxY);

    CGRect frame = CGRectMake(x, y, width, height);
    self.window.frame = frame;
    self.window.hidden = ![self.preferences[@"enabled"] boolValue];
    self.window.alpha = MIN(MAX([self.preferences[@"hudOpacity"] doubleValue], 0.2), 1.0);
}

- (NSTimeInterval)currentPlaybackTime {
    if (!self.snapshotDate) {
        return self.baseElapsed;
    }

    NSTimeInterval delta = [[NSDate date] timeIntervalSinceDate:self.snapshotDate];
    return self.baseElapsed + delta * self.playbackRate;
}

- (void)refreshNowPlayingInfo {
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef information) {
        if (!information) {
            return;
        }

        NSDictionary *info = (__bridge NSDictionary *)information;
        NSString *title = info[@"kMRMediaRemoteNowPlayingInfoTitle"] ?: info[MPMediaItemPropertyTitle];
        NSString *artist = info[@"kMRMediaRemoteNowPlayingInfoArtist"] ?: info[MPMediaItemPropertyArtist];
        NSNumber *elapsed = info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"] ?: info[MPNowPlayingInfoPropertyElapsedPlaybackTime];
        NSNumber *rate = info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] ?: info[MPNowPlayingInfoPropertyPlaybackRate];

        self.baseElapsed = elapsed.doubleValue;
        self.playbackRate = rate ? rate.floatValue : 1.0;
        self.snapshotDate = [NSDate date];

        NSString *identifier = [NSString stringWithFormat:@"%@|%@", title ?: @"", artist ?: @""];
        if (![identifier isEqualToString:self.lastTrackIdentifier]) {
            self.lastTrackIdentifier = identifier;
            self.document = nil;
            [self fetchLyricsForTitle:title artist:artist];
        }
    });
}

- (void)fetchLyricsForTitle:(NSString *)title artist:(NSString *)artist {
    if (title.length == 0) {
        return;
    }

    LPLyricProvider provider = (LPLyricProvider)[self.preferences[@"provider"] integerValue];
    [self.fetcher fetchLyricsForTitle:title artist:artist provider:provider completion:^(LPLyricDocument * _Nullable document, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.document = document;
            self.lastLyricUpdate = [NSDate date];
            if (!document || document.lines.count == 0) {
                [self.hudView updateCurrentLine:nil nextLine:nil progress:0];
            }
        });
    }];
}

- (void)tick {
    if (![self.preferences[@"enabled"] boolValue]) {
        return;
    }

    NSTimeInterval now = [self currentPlaybackTime];
    CGFloat progress = 0;
    LPLyricLine *nextLine = nil;
    LPLyricLine *line = [self.document lineAtTime:now progress:&progress nextLine:&nextLine];
    [self.hudView updateCurrentLine:line nextLine:nextLine progress:progress];

    NSTimeInterval autoHide = [self.preferences[@"autoHideSeconds"] doubleValue];
    BOOL shouldHide = NO;
    if (autoHide > 0 && self.lastLyricUpdate) {
        shouldHide = ([[NSDate date] timeIntervalSinceDate:self.lastLyricUpdate] > autoHide && !line);
    }

    CGFloat visibleAlpha = MIN(MAX([self.preferences[@"hudOpacity"] doubleValue], 0.2), 1.0);
    self.window.alpha = shouldHide ? 0 : visibleAlpha;
}

@end

%ctor {
    @autoreleasepool {
        if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[LPLyricPluginManager shared] start];
            });
        }
    }
}
