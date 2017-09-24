//
//  JotTouchLine.m
//  DrawModules
//
//  Created by Martin Prot on 06/10/2015.
//  Copyright © 2015 appricot. All rights reserved.
//

#import "JotTouchLine.h"

@implementation JotTouchLine

+ (instancetype)withStartPoint:(CGPoint)a
{
	JotTouchLine *touchLine = [JotTouchLine new];
	touchLine.pointA = a;
	touchLine.pointB = a;
	return touchLine;
}

- (void)jotDraw
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		return;
	}
	[self.strokeColor setStroke];
	CGContextSetLineWidth(context, self.strokeWidth);
	CGContextSetLineCap(context, kCGLineCapSquare);
	CGContextMoveToPoint(context, self.pointA.x, self.pointA.y);
	CGContextAddLineToPoint(context, self.pointB.x, self.pointB.y);
	if (self.dashed) {
		CGFloat lengths[] = {self.strokeWidth, self.strokeWidth*2};
		CGContextSetLineDash(context, 0, lengths, 2);
	}
	else {
		CGContextSetLineDash(context, 0, NULL, 0);
	}
	CGContextStrokePath(context);
}

- (CGRect)rect
{
	CGRect zeroWidthRect = CGRectUnion(CGRectMake(self.pointA.x, self.pointA.y, 0, 0),
									   CGRectMake(self.pointB.x, self.pointB.y, 0, 0));
	CGFloat enlarge = -self.strokeWidth/2*sqrt(2);
	return CGRectInset(zeroWidthRect, enlarge, enlarge);
}

#pragma mark - Serialization

- (NSMutableDictionary*)serialize:(CGFloat)ratioForAspectFitAgainstiPhone6 {
  NSMutableDictionary *dic = [super serialize:ratioForAspectFitAgainstiPhone6];
	dic[kPointA] = @{ kPointX: @(self.pointA.x / ratioForAspectFitAgainstiPhone6), kPointY: @(self.pointA.y / ratioForAspectFitAgainstiPhone6) };
	dic[kPointB] = @{ kPointX: @(self.pointB.x / ratioForAspectFitAgainstiPhone6), kPointY: @(self.pointB.y / ratioForAspectFitAgainstiPhone6) };
	dic[kStrokeWidth] = @(self.strokeWidth / ratioForAspectFitAgainstiPhone6);
	dic[kIsDashed] = @(self.dashed);
	return dic;
}

- (void)unserialize:(NSDictionary*)dictionary on:(CGFloat)ratioForAspectFitAgainstiPhone6 {
  [super unserialize:dictionary on:ratioForAspectFitAgainstiPhone6];
	if (dictionary[kPointA]) {
    NSDictionary *center = dictionary[kPointA];
    NSNumber *numberX = center[kPointX];
    NSNumber *numberY = center[kPointY];
    CGPoint tempPoint;
    tempPoint.x = numberX.doubleValue * ratioForAspectFitAgainstiPhone6;
    tempPoint.y = numberY.doubleValue * ratioForAspectFitAgainstiPhone6;
    
    self.pointA = tempPoint;
	}
	if (dictionary[kPointB]) {
    NSDictionary *center = dictionary[kPointB];
    NSNumber *numberX = center[kPointX];
    NSNumber *numberY = center[kPointY];
    CGPoint tempPoint;
    tempPoint.x = numberX.doubleValue * ratioForAspectFitAgainstiPhone6;
    tempPoint.y = numberY.doubleValue * ratioForAspectFitAgainstiPhone6;
    
    self.pointB = tempPoint;
	}
	if (dictionary[kStrokeWidth]) {
		self.strokeWidth = [dictionary[kStrokeWidth] floatValue]  * ratioForAspectFitAgainstiPhone6;
	}
	if (dictionary[kIsDashed]) {
		self.dashed = [dictionary[kIsDashed] boolValue];
	}
}

@end
