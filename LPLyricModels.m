#import "LPLyricModels.h"
#import <math.h>

@implementation LPLyricLine
@end

@implementation LPLyricDocument

+ (instancetype)documentWithLRC:(NSString *)lrc {
    LPLyricDocument *document = [[LPLyricDocument alloc] init];
    NSMutableArray<LPLyricLine *> *parsed = [NSMutableArray array];

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\[(\\d{1,2}):(\\d{1,2})(?:\\.(\\d{1,3}))?\\](.*)" options:0 error:nil];
    [lrc enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        NSTextCheckingResult *match = [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        if (!match || match.numberOfRanges < 5) {
            return;
        }

        NSString *minuteText = [line substringWithRange:[match rangeAtIndex:1]];
        NSString *secondText = [line substringWithRange:[match rangeAtIndex:2]];
        NSString *fractionText = [line substringWithRange:[match rangeAtIndex:3]];
        NSString *lyricText = [[line substringWithRange:[match rangeAtIndex:4]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (lyricText.length == 0) {
            return;
        }

        NSTimeInterval seconds = minuteText.doubleValue * 60.0 + secondText.doubleValue;
        if (fractionText.length > 0) {
            seconds += fractionText.doubleValue / pow(10, fractionText.length);
        }

        LPLyricLine *lineModel = [[LPLyricLine alloc] init];
        lineModel.startTime = seconds;
        lineModel.text = lyricText;
        [parsed addObject:lineModel];
    }];

    [parsed sortUsingComparator:^NSComparisonResult(LPLyricLine * _Nonnull lhs, LPLyricLine * _Nonnull rhs) {
        if (lhs.startTime < rhs.startTime) {
            return NSOrderedAscending;
        }
        if (lhs.startTime > rhs.startTime) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];

    for (NSUInteger idx = 0; idx < parsed.count; idx++) {
        LPLyricLine *current = parsed[idx];
        NSTimeInterval defaultEnd = current.startTime + 6.0;
        if (idx + 1 < parsed.count) {
            LPLyricLine *next = parsed[idx + 1];
            current.endTime = MAX(current.startTime + 0.1, next.startTime);
        } else {
            current.endTime = defaultEnd;
        }
    }

    document.lines = parsed.copy;
    return document;
}

- (nullable LPLyricLine *)lineAtTime:(NSTimeInterval)time progress:(CGFloat *)progress nextLine:(LPLyricLine * _Nullable * _Nullable)nextLine {
    if (self.lines.count == 0) {
        if (progress) {
            *progress = 0;
        }
        if (nextLine) {
            *nextLine = nil;
        }
        return nil;
    }

    NSInteger low = 0;
    NSInteger high = self.lines.count - 1;
    NSInteger foundIndex = NSNotFound;

    while (low <= high) {
        NSInteger mid = (low + high) / 2;
        LPLyricLine *candidate = self.lines[mid];
        if (time < candidate.startTime) {
            high = mid - 1;
        } else if (time >= candidate.endTime) {
            low = mid + 1;
        } else {
            foundIndex = mid;
            break;
        }
    }

    if (foundIndex == NSNotFound) {
        LPLyricLine *first = self.lines.firstObject;
        if (time < first.startTime) {
            if (progress) {
                *progress = 0;
            }
            if (nextLine) {
                *nextLine = first;
            }
            return nil;
        }

        LPLyricLine *last = self.lines.lastObject;
        if (progress) {
            *progress = 1;
        }
        if (nextLine) {
            *nextLine = nil;
        }
        return last;
    }

    LPLyricLine *line = self.lines[foundIndex];
    NSTimeInterval duration = MAX(0.01, line.endTime - line.startTime);
    CGFloat lineProgress = (CGFloat)((time - line.startTime) / duration);
    if (progress) {
        *progress = MIN(MAX(lineProgress, 0), 1);
    }
    if (nextLine) {
        *nextLine = (foundIndex + 1 < (NSInteger)self.lines.count) ? self.lines[foundIndex + 1] : nil;
    }
    return line;
}

@end
