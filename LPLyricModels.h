#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LPLyricLine : NSObject
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSTimeInterval endTime;
@property (nonatomic, copy) NSString *text;
@end

@interface LPLyricDocument : NSObject
@property (nonatomic, copy) NSArray<LPLyricLine *> *lines;
+ (instancetype)documentWithLRC:(NSString *)lrc;
- (nullable LPLyricLine *)lineAtTime:(NSTimeInterval)time progress:(CGFloat *)progress nextLine:(LPLyricLine * _Nullable * _Nullable)nextLine;
@end

NS_ASSUME_NONNULL_END
