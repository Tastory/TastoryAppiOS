//
//  JotTouchObject.m
//  DrawModules
//
//  Created by Martin Prot on 23/09/2015.
//  Copyright © 2015 appricot. All rights reserved.
//

#import "JotTouchObject.h"

NSString *const kType = @"Type";
NSString *const kColor = @"Color";
NSString *const kPoint = @"Point";
NSString *const kPointA = @"PointA";
NSString *const kPointB = @"PointB";
NSString *const kPointAControl = @"PointAControl";
NSString *const kPointBControl = @"PointBControl";
NSString *const kStrokeWidth = @"StrokeWidth";
NSString *const kStrokeStartWidth = @"StrokeStartWidth";
NSString *const kStrokeEndWidth = @"StrokeEndWidth";
NSString *const kIsDashed = @"IsDashed";
NSString *const kOutputScaleFactor = @"OutputScaleFactor";
NSString *const kColorRed = @"kColorRed";
NSString *const kColorGreen = @"kColorGreen";
NSString *const kColorBlue = @"kColorBlue";
NSString *const kColorAlpha = @"kColorAlpha";
NSString *const kPointX = @"kPointX";
NSString *const kPointY = @"kPointY";


@implementation JotTouchObject

- (CGRect)rect {
	NSAssert(NO, @"this method should be overriden in subclass");
	return CGRectZero;
}

- (void)jotDrawWithScaling:(BOOL)shouldScale {
	NSAssert(NO, @"this method should be overriden in subclass");
}

#pragma mark - Properties

- (CGFloat)outputScaleFactor {
    return _outputScaleFactor <= 0 ? 1 : _outputScaleFactor;
}

#pragma mark - Serialization

+ (instancetype)fromSerialized:(NSDictionary*)dictionary on:(CGFloat)ratioForAspectFitAgainstiPhone6{
	NSString *className = dictionary[kType];
	JotTouchObject *object = nil;
	if (className) {
		object = [NSClassFromString(className) new];
    [object unserialize:dictionary on:ratioForAspectFitAgainstiPhone6];
	}
	return object;
}

- (NSMutableDictionary*)serialize:(CGFloat)ratioForAspectFitAgainstiPhone6 {
	NSMutableDictionary *dic = [NSMutableDictionary new];
	dic[kType] = NSStringFromClass(self.class);
  
  CGFloat colorRed;
  CGFloat colorGreen;
  CGFloat colorBlue;
  CGFloat colorAlpha;
  [self.strokeColor getRed: &colorRed green: &colorGreen blue: &colorBlue alpha: &colorAlpha];
  dic[kColor] = @{ kColorRed: @(colorRed), kColorGreen: @(colorGreen), kColorBlue: @(colorBlue), kColorAlpha: @(colorAlpha) };
  
	return dic;
}

- (void)unserialize:(NSDictionary*)dictionary on:(CGFloat)ratioForAspectFitAgainstiPhone6{
  
  if (dictionary[kColor]) {
    NSDictionary *color = dictionary[kColor];
    NSNumber *numberRed = color[kColorRed];
    NSNumber *numberGreen = color[kColorGreen];
    NSNumber *numberBlue = color[kColorBlue];
    NSNumber *numberAlpha = color[kColorAlpha];
    
    self.strokeColor = [UIColor colorWithRed:[numberRed floatValue]
                                     green:[numberGreen floatValue]
                                      blue:[numberBlue floatValue]
                                     alpha:[numberAlpha floatValue]];
  }
}

@end
