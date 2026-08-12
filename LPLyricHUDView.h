#import <UIKit/UIKit.h>
#import "LPLyricModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface LPLyricHUDView : UIView
@property (nonatomic, assign) BOOL passThrough;
@property (nonatomic, assign) BOOL lockPosition;
- (void)applyPreferences:(NSDictionary *)preferences;
- (void)updateCurrentLine:(nullable LPLyricLine *)currentLine nextLine:(nullable LPLyricLine *)nextLine progress:(CGFloat)progress;
@end

NS_ASSUME_NONNULL_END
