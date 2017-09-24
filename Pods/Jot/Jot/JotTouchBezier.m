//
//  JotTouchBezier.m
//  jot
//
//  Created by Laura Skelton on 4/30/15.
//
//

#import "JotTouchBezier.h"

NSUInteger const kJotDrawStepsPerBezier = 30;

@interface JotTouchBezier ()

@property (nonatomic, assign) CGMutablePathRef scaledPath;

@end

@implementation JotTouchBezier

+ (instancetype)withStartPoint:(CGPoint)startPoint endPoint:(CGPoint)endPoint controlPoint1:(CGPoint)controlPoint1 controlPoint2:(CGPoint)controlPoint2 scaleFactor:(CGFloat)scaleFactor
{
	return [[JotTouchBezier alloc] initWithStartPoint:startPoint endPoint:endPoint controlPoint1:controlPoint1 controlPoint2:controlPoint2 scaleFactor:scaleFactor];
}

- (instancetype)initWithStartPoint:(CGPoint)startPoint endPoint:(CGPoint)endPoint controlPoint1:(CGPoint)controlPoint1 controlPoint2:(CGPoint)controlPoint2 scaleFactor:(CGFloat)scaleFactor
{
	self = [super init];
	if (self) {
		self.startPoint = startPoint;
		self.endPoint = endPoint;
		self.controlPoint1 = controlPoint1;
		self.controlPoint2 = controlPoint2;
    self.outputScaleFactor = scaleFactor;
		[self generatePath];
	}
	return self;
}

- (void)dealloc
{
	CGPathRelease(_path);
}

- (void)jotDrawWithScaling:(BOOL)shouldScale
{
    if (self.constantWidth) {
		[self drawStrategy1WithScaling:shouldScale];
    } else {
		[self drawStrategy2WithScaling:shouldScale];
    }
}

- (CGMutablePathRef)scaledPath {
    CGAffineTransform scaleTransform = CGAffineTransformMakeScale(self.outputScaleFactor, self.outputScaleFactor);
    return CGPathCreateMutableCopyByTransformingPath(self.path, &scaleTransform);
}

- (void)generatePath {
	if (_path) CGPathRelease(_path);
	_path = CGPathCreateMutable();
	CGPathMoveToPoint(_path, NULL, self.startPoint.x, self.startPoint.y);
	CGPathAddCurveToPoint(_path, NULL, self.controlPoint1.x, self.controlPoint1.y, self.controlPoint2.x, self.controlPoint2.y, self.endPoint.x, self.endPoint.y);
}

- (void)drawStrategy1WithScaling:(BOOL)shouldScale {
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		return;
	}
    CGMutablePathRef path = shouldScale ? self.scaledPath : _path;
	CGContextAddPath(context, path);
	CGContextSetLineWidth(context, self.startWidth);
	CGContextSetLineCap(context, kCGLineCapRound);
	[self.strokeColor setStroke];
	CGContextStrokePath(context);
}

- (void)drawStrategy2WithScaling:(BOOL)shouldScale {
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		return;
	}
    
    CGFloat scaleFactor = shouldScale ? self.outputScaleFactor : 1.f;
    CGPoint scaledStartPoint = CGPointMake(self.startPoint.x * scaleFactor,
                                           self.startPoint.y * scaleFactor);
    CGPoint scaledEndPoint = CGPointMake(self.endPoint.x * scaleFactor,
                                         self.endPoint.y * scaleFactor);
    CGPoint scaledControlPoint1 = CGPointMake(self.controlPoint1.x * scaleFactor,
                                              self.controlPoint1.y * scaleFactor);
    CGPoint scaledControlPoint2 = CGPointMake(self.controlPoint2.x * scaleFactor,
                                              self.controlPoint2.y * scaleFactor);
    CGFloat scaledStartWidth = self.startWidth * scaleFactor;
    CGFloat scaledEndWidth = self.endWidth * scaleFactor;
	CGFloat widthDelta = scaledEndWidth - scaledStartWidth;
	
	[self.strokeColor setStroke];
	CGContextSetLineCap(context, kCGLineCapRound);
	
	for (NSUInteger i = 0; i <= kJotDrawStepsPerBezier; i++) {
		
		CGFloat t = ((CGFloat)i) / (CGFloat)kJotDrawStepsPerBezier;
		CGFloat tt = t * t;
		CGFloat ttt = tt * t;
		CGFloat u = 1.f - t;
		CGFloat uu = u * u;
		CGFloat uuu = uu * u;
		
		CGFloat x = uuu * scaledStartPoint.x;
		x += 3 * uu * t * scaledControlPoint1.x;
		x += 3 * u * tt * scaledControlPoint2.x;
		x += ttt * scaledEndPoint.x;
		
		CGFloat y = uuu * scaledStartPoint.y;
		y += 3 * uu * t * scaledControlPoint1.y;
		y += 3 * u * tt * scaledControlPoint2.y;
		y += ttt * scaledEndPoint.y;
		
		CGFloat pointWidth = scaledStartWidth + (ttt * widthDelta);
		
		if (i > 0) {
			CGContextAddLineToPoint(context, x, y);
			CGContextSetLineWidth(context, pointWidth);
			CGContextStrokePath(context);
		}
		CGContextMoveToPoint(context, x, y);
	}
}

- (CGRect)rect {
	CGRect boundingBox = CGPathGetBoundingBox(_path);
	CGFloat largestWidth = -MAX(self.startWidth, self.endWidth)/2;
	return CGRectInset(boundingBox, largestWidth, largestWidth);
}

#pragma mark - Serialization

- (NSMutableDictionary*)serialize:(CGFloat)ratioForAspectFitAgainstiPhone6 {
  NSMutableDictionary *dic = [super serialize:ratioForAspectFitAgainstiPhone6];
  dic[kPointA] = @{ kPointX: @(self.startPoint.x / ratioForAspectFitAgainstiPhone6), kPointY: @(self.startPoint.y / ratioForAspectFitAgainstiPhone6) };
  dic[kPointB] = @{ kPointX: @(self.endPoint.x / ratioForAspectFitAgainstiPhone6), kPointY: @(self.endPoint.y / ratioForAspectFitAgainstiPhone6) };
	dic[kPointAControl] = @{ kPointX: @(self.controlPoint1.x / ratioForAspectFitAgainstiPhone6), kPointY: @(self.controlPoint1.y / ratioForAspectFitAgainstiPhone6) };
	dic[kPointBControl] = @{ kPointX: @(self.controlPoint2.x / ratioForAspectFitAgainstiPhone6), kPointY: @(self.controlPoint2.y / ratioForAspectFitAgainstiPhone6) };
	dic[kStrokeStartWidth]	= @(self.startWidth / ratioForAspectFitAgainstiPhone6);
	dic[kStrokeEndWidth]	= self.constantWidth?@(self.startWidth / ratioForAspectFitAgainstiPhone6):@(self.endWidth / ratioForAspectFitAgainstiPhone6);
  dic[kOutputScaleFactor]	= @(self.outputScaleFactor / ratioForAspectFitAgainstiPhone6);
	
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
    
    self.startPoint = tempPoint;
	}
	if (dictionary[kPointB]) {
    NSDictionary *center = dictionary[kPointB];
    NSNumber *numberX = center[kPointX];
    NSNumber *numberY = center[kPointY];
    CGPoint tempPoint;
    tempPoint.x = numberX.doubleValue * ratioForAspectFitAgainstiPhone6;
    tempPoint.y = numberY.doubleValue * ratioForAspectFitAgainstiPhone6;
    
    self.endPoint = tempPoint;
	}
	if (dictionary[kPointAControl]) {
    NSDictionary *center = dictionary[kPointAControl];
    NSNumber *numberX = center[kPointX];
    NSNumber *numberY = center[kPointY];
    CGPoint tempPoint;
    tempPoint.x = numberX.doubleValue * ratioForAspectFitAgainstiPhone6;
    tempPoint.y = numberY.doubleValue * ratioForAspectFitAgainstiPhone6;
    
    self.controlPoint1 = tempPoint;
	}
	if (dictionary[kPointBControl]) {
    NSDictionary *center = dictionary[kPointBControl];
    NSNumber *numberX = center[kPointX];
    NSNumber *numberY = center[kPointY];
    CGPoint tempPoint;
    tempPoint.x = numberX.doubleValue * ratioForAspectFitAgainstiPhone6;
    tempPoint.y = numberY.doubleValue * ratioForAspectFitAgainstiPhone6;
    
    self.controlPoint2 = tempPoint;
	}
	[self generatePath];
	
	if (dictionary[kStrokeStartWidth]) {
		self.startWidth = [dictionary[kStrokeStartWidth] floatValue] * ratioForAspectFitAgainstiPhone6;
	}
	if (dictionary[kStrokeEndWidth]) {
		self.endWidth = [dictionary[kStrokeEndWidth] floatValue] * ratioForAspectFitAgainstiPhone6;
	}
  if (dictionary[kOutputScaleFactor]) {
    self.outputScaleFactor = [dictionary[kOutputScaleFactor] floatValue] * ratioForAspectFitAgainstiPhone6;
  }
	self.constantWidth = (self.startWidth == self.endWidth);
}

@end
