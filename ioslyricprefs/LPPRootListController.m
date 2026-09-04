#import "LPPRootListController.h"
#import <notify.h>

@implementation LPPRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];
    notify_post("com.domgur0.lyric/preferenceschanged");
}

@end
