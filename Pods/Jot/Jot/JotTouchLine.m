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

- (NSMutableDictionary*)serialize {
	NSMutableDictionary *dic = [super serialize];
	dic[kPointA] = [NSValue valueWithCGPoint:self.pointA];
	dic[kPointB] = [NSValue valueWithCGPoint:self.pointB];
	dic[kStrokeWidth] = @(self.strokeWidth);
	dic[kIsDashed] = @(self.dashed);
	return dic;
}

- (void)unserialize:(NSDictionary*)dictionary {
	[super unserialize:dictionary];
	if (dictionary[kPointA]) {
		self.pointA = [dictionary[kPointA] CGPointValue];
	}
	if (dictionary[kPointB]) {
		self.pointB = [dictionary[kPointB] CGPointValue];
	}
	if (dictionary[kStrokeWidth]) {
		self.strokeWidth = [dictionary[kStrokeWidth] floatValue];
	}
	if (dictionary[kIsDashed]) {
		self.dashed = [dictionary[kIsDashed] boolValue];
	}
}

@end
