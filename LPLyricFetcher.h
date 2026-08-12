#import <Foundation/Foundation.h>
#import "LPLyricModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LPLyricProvider) {
    LPLyricProviderNetease = 0,
};

@interface LPLyricFetcher : NSObject
- (void)fetchLyricsForTitle:(NSString *)title artist:(NSString *)artist provider:(LPLyricProvider)provider completion:(void(^)(LPLyricDocument * _Nullable document, NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
