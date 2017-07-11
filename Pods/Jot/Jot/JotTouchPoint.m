//
//  JotTouchPoint.m
//  jot
//
//  Created by Laura Skelton on 4/30/15.
//
//

#import "JotTouchPoint.h"

@implementation JotTouchPoint

+ (instancetype)withPoint:(CGPoint)point scaleFactor:(CGFloat)scaleFactor
{
    JotTouchPoint *touchPoint = [JotTouchPoint new];
    touchPoint.point = point;
    touchPoint.timestamp = [NSDate date];
    touchPoint.outputScaleFactor = scaleFactor;
    return touchPoint;
}

- (CGFloat)velocityFromPoint:(JotTouchPoint *)fromPoint
{
    CGFloat distance = (CGFloat)sqrt((double)(pow((double)(self.point.x - fromPoint.point.x),
                                                  (double)2.f)
                                              + pow((double)(self.point.y - fromPoint.point.y),
                                                    (double)2.f)));
    
    CGFloat timeInterval = (CGFloat)fabs((double)([self.timestamp timeIntervalSinceDate:fromPoint.timestamp]));
    return distance / timeInterval;
}

- (CGPoint)CGPointValue
{
    return self.point;
}

- (void)jotDrawWithScaling:(BOOL)shouldScale
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		return;
	}
    CGFloat scaleFactor = shouldScale ? self.outputScaleFactor : 1.f;
	[self.strokeColor setFill];
    CGRect scaledRect = CGRectMake(self.rect.origin.x * scaleFactor,
                                   self.rect.origin.y * scaleFactor,
                                   self.rect.size.width * scaleFactor,
                                   self.rect.size.height * scaleFactor);
	CGContextFillEllipseInRect(context, scaledRect);

}

- (CGRect)rect
{
	return CGRectInset(CGRectMake(self.point.x, self.point.y, 0.f, 0.f), -self.strokeWidth / 2.f, -self.strokeWidth / 2.f);
}

#pragma mark - Serialization

- (NSMutableDictionary*)serialize {
	NSMutableDictionary *dic = [super serialize];
	dic[kPoint] = [NSValue valueWithCGPoint:self.point];
	dic[kStrokeWidth] = @(self.strokeWidth);
    dic[kOutputScaleFactor] = @(self.outputScaleFactor);
	return dic;
}

- (void)unserialize:(NSDictionary*)dictionary {
	[super unserialize:dictionary];
	NSValue *pointValue = dictionary[kPoint];
	if (pointValue) {
		self.point = [pointValue CGPointValue];
	}
	if (dictionary[kStrokeWidth]) {
		self.strokeWidth = [dictionary[kStrokeWidth] floatValue];
	}
    if (dictionary[kOutputScaleFactor]) {
        self.outputScaleFactor = [dictionary[kOutputScaleFactor] floatValue];
    }
}

@end
