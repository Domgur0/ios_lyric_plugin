#import "LPLyricHUDView.h"

@interface LPKaraokeLabel : UIView
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *baseColor;
@property (nonatomic, strong) UIColor *progressColor;
@property (nonatomic, assign) CGFloat progress;
@end

@implementation LPKaraokeLabel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _text = @"";
        _font = [UIFont boldSystemFontOfSize:24.0];
        _baseColor = [UIColor whiteColor];
        _progressColor = [UIColor colorWithRed:0.3 green:0.95 blue:1 alpha:1];
        self.backgroundColor = UIColor.clearColor;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (CGSize)textSize {
    NSDictionary *attrs = @{NSFontAttributeName: self.font};
    return [self.text sizeWithAttributes:attrs];
}

- (void)drawRect:(CGRect)rect {
    if (self.text.length == 0) {
        return;
    }

    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentCenter;
    NSDictionary *attrs = @{
        NSFontAttributeName: self.font,
        NSForegroundColorAttributeName: self.baseColor,
        NSParagraphStyleAttributeName: paragraph
    };

    CGRect textRect = CGRectInset(rect, 4, 2);
    [self.text drawInRect:textRect withAttributes:attrs];

    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }

    CGFloat width = CGRectGetWidth(textRect) * MIN(MAX(self.progress, 0), 1);
    CGContextSaveGState(context);
    CGContextClipToRect(context, CGRectMake(textRect.origin.x, textRect.origin.y, width, textRect.size.height));
    NSDictionary *progressAttrs = @{
        NSFontAttributeName: self.font,
        NSForegroundColorAttributeName: self.progressColor,
        NSParagraphStyleAttributeName: paragraph
    };
    [self.text drawInRect:textRect withAttributes:progressAttrs];
    CGContextRestoreGState(context);
}

- (void)setText:(NSString *)text {
    _text = [text copy] ?: @"";
    [self setNeedsDisplay];
}

- (void)setProgress:(CGFloat)progress {
    _progress = progress;
    [self setNeedsDisplay];
}

@end

@interface LPLyricHUDView ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) LPKaraokeLabel *currentLabel;
@property (nonatomic, strong) UILabel *nextLabel;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@end

@implementation LPLyricHUDView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = 14.0;
        self.layer.masksToBounds = YES;

        _blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
        _blurView.frame = self.bounds;
        _blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_blurView];

        _currentLabel = [[LPKaraokeLabel alloc] initWithFrame:CGRectZero];
        _nextLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nextLabel.textAlignment = NSTextAlignmentCenter;
        _nextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.72];
        _nextLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _nextLabel.numberOfLines = 1;

        [_blurView.contentView addSubview:_currentLabel];
        [_blurView.contentView addSubview:_nextLabel];

        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:_panGesture];

        _passThrough = NO;
        _lockPosition = NO;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat inset = 8;
    CGFloat width = CGRectGetWidth(self.bounds) - inset * 2;
    self.currentLabel.frame = CGRectMake(inset, 8, width, 34);
    self.nextLabel.frame = CGRectMake(inset, CGRectGetMaxY(self.currentLabel.frame) + 2, width, 20);
}

- (void)applyPreferences:(NSDictionary *)preferences {
    CGFloat fontSize = [preferences[@"fontSize"] doubleValue];
    if (fontSize <= 0) {
        fontSize = 24;
    }

    self.currentLabel.font = [UIFont boldSystemFontOfSize:fontSize];

    NSString *baseHex = preferences[@"baseColor"] ?: @"#FFFFFF";
    NSString *progressHex = preferences[@"progressColor"] ?: @"#63F2FF";
    self.currentLabel.baseColor = [self colorFromHex:baseHex fallback:[UIColor whiteColor]];
    self.currentLabel.progressColor = [self colorFromHex:progressHex fallback:[UIColor cyanColor]];

    CGFloat nextSize = MAX(12.0, fontSize * 0.62);
    self.nextLabel.font = [UIFont systemFontOfSize:nextSize weight:UIFontWeightMedium];

    self.passThrough = [preferences[@"touchPassthrough"] boolValue];
    self.lockPosition = [preferences[@"lockPosition"] boolValue];
}

- (UIColor *)colorFromHex:(NSString *)hex fallback:(UIColor *)fallback {
    NSString *clean = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if ([clean hasPrefix:@"#"]) {
        clean = [clean substringFromIndex:1];
    }
    if (clean.length != 6) {
        return fallback;
    }

    unsigned int value = 0;
    [[NSScanner scannerWithString:clean] scanHexInt:&value];
    CGFloat red = ((value >> 16) & 0xFF) / 255.0;
    CGFloat green = ((value >> 8) & 0xFF) / 255.0;
    CGFloat blue = (value & 0xFF) / 255.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
}

- (void)updateCurrentLine:(nullable LPLyricLine *)currentLine nextLine:(nullable LPLyricLine *)nextLine progress:(CGFloat)progress {
    self.currentLabel.text = currentLine.text ?: @"暂无歌词";
    self.currentLabel.progress = progress;
    self.nextLabel.text = nextLine.text ?: @"";
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.passThrough) {
        return nil;
    }
    return [super hitTest:point withEvent:event];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (self.lockPosition || !self.superview) {
        return;
    }

    UIView *view = self;
    CGPoint translation = [gesture translationInView:view.superview];
    CGPoint center = view.center;
    center.x += translation.x;
    center.y += translation.y;
    view.center = center;
    [gesture setTranslation:CGPointZero inView:view.superview];

    if (gesture.state == UIGestureRecognizerStateEnded) {
        CGRect bounds = view.superview.bounds;
        CGRect frame = view.frame;
        CGFloat margin = 10.0;

        frame.origin.x = MIN(MAX(frame.origin.x, margin), CGRectGetWidth(bounds) - CGRectGetWidth(frame) - margin);
        frame.origin.y = MIN(MAX(frame.origin.y, margin + 40), CGRectGetHeight(bounds) - CGRectGetHeight(frame) - margin - 20);

        [UIView animateWithDuration:0.25 animations:^{
            view.frame = frame;
        }];
    }
}

@end
