#import "LPPRootListController.h"
#import <notify.h>
#import <Preferences/PSSpecifier.h>

@implementation LPPRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *defaults = specifier.properties[@"defaults"];
    NSString *key = specifier.properties[@"key"];
    if (defaults.length == 0 || key.length == 0) {
        return specifier.properties[@"default"];
    }

    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", defaults];
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:path];
    id value = settings[key];
    return value ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *defaults = specifier.properties[@"defaults"];
    NSString *key = specifier.properties[@"key"];
    if (defaults.length == 0 || key.length == 0) {
        return;
    }

    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", defaults];
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
    if (value) {
        settings[key] = value;
    } else {
        [settings removeObjectForKey:key];
    }
    [settings writeToFile:path atomically:YES];

    NSString *notification = specifier.properties[@"PostNotification"];
    if (notification.length > 0) {
        notify_post(notification.UTF8String);
    }

    notify_post("com.domgur0.lyric/preferenceschanged");
}

@end
