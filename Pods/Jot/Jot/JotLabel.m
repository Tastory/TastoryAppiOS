//
//  JotLabel.m
//  DrawModules
//
//  Created by Martin Prot on 24/09/2015.
//  Copyright © 2015 appricot. All rights reserved.
//

#import "JotLabel.h"

NSString *const kText = @"Text";
NSString *const kFontName = @"FontName";
NSString *const kFontSize = @"FontSize";
NSString *const kTextColor = @"Color";
NSString *const kAlignment = @"Alignment";
NSString *const kCenter = @"Center";
NSString *const kRotation = @"kRotation";
NSString *const kScale = @"Scale";
NSString *const kFitWidth = @"FitWidth";
NSString *const kLabelColorRed = @"LabelColorRed";
NSString *const kLabelColorGreen = @"LabelColorGreen";
NSString *const kLabelColorBlue = @"LabelColorBlue";
NSString *const kLabelColorAlpha = @"LabelColorAlpha";
NSString *const kLabelPointX = @"LabelPointX";
NSString *const kLabelPointY = @"LabelPointY";


@interface JotLabel ()

@property (nonatomic, strong) CAShapeLayer *borderLayer;

@end

@implementation JotLabel

- (instancetype)init
{
	self = [super init];
	if (self) {
		_initialRotationTransform = CGAffineTransformIdentity;
		_scale = 1;
		_unscaledFrame = self.frame;
	}
	return self;
}

- (void)setSelected:(BOOL)selected {
	if (_selected != selected) {
		_selected = selected;
		if (selected) {
			self.layer.borderColor = [UIColor redColor].CGColor;
			self.layer.borderWidth = 1.f;
		}
		else {
			self.layer.borderColor = [UIColor clearColor].CGColor;
			self.layer.borderWidth = 0.f;
		}
	}
}

- (void)setUnscaledFrame:(CGRect)unscaledFrame
{
	if (!CGRectEqualToRect(_unscaledFrame, unscaledFrame)) {
		_unscaledFrame = unscaledFrame;
		CGPoint labelCenter = self.center;
		CGRect scaledFrame = CGRectMake(0.f,
										0.f,
										_unscaledFrame.size.width * self.scale * 1.05f,
										_unscaledFrame.size.height * self.scale * 1.05f);
		CGAffineTransform labelTransform = self.transform;
		self.transform = CGAffineTransformIdentity;
		self.frame = scaledFrame;
		self.transform = labelTransform;
		self.center = labelCenter;
	}
}

- (void)setScale:(CGFloat)scale
{
	if (_scale != scale) {
		_scale = scale;
		// Get only the rotation component
		CGFloat angle = atan2f(self.transform.b, self.transform.a);
		// Convert a scale trasform (which pixelate) into a scaled font size (vector)
		self.transform = CGAffineTransformIdentity;
		CGPoint labelCenter = self.center;
		CGRect scaledFrame = CGRectMake(0.f,
										0.f,
										_unscaledFrame.size.width * _scale * 1.05f,
											 _unscaledFrame.size.height* _scale * 1.05f);
		CGFloat currentFontSize = self.unscaledFontSize * _scale;
		self.font = [self.font fontWithSize:currentFontSize];
		
		self.frame = scaledFrame;
		self.center = labelCenter;
		self.transform = CGAffineTransformMakeRotation(angle);
	}
}

- (void)refreshFont {
	CGFloat currentFontSize = self.unscaledFontSize * _scale;
	CGPoint center = self.center;
	self.font = [self.font fontWithSize:currentFontSize];
	[self autosize];
	self.center = center;
}


- (void)autosize
{
	JotLabel *temporarySizingLabel = [JotLabel new];
	temporarySizingLabel.text = self.text;
	temporarySizingLabel.font = [self.font fontWithSize:self.unscaledFontSize];
	temporarySizingLabel.textAlignment = self.textAlignment;
	
	CGRect insetViewRect;
	
	if (_fitOriginalFontSizeToViewWidth) {
		temporarySizingLabel.numberOfLines = 0;
		insetViewRect = CGRectInset(self.superview.bounds,
									_initialTextInsets.left + _initialTextInsets.right,
									_initialTextInsets.top + _initialTextInsets.bottom);
//    NSLog(@"fitOriginalFontSizeToViewWidth: YES");
//    NSLog(@"superview.bounds.size.width: %f", self.superview.bounds.size.width);
//    NSLog(@"initialTextInsets.left: %f", _initialTextInsets.left);
//    NSLog(@"initialTextInsets.right: %f", _initialTextInsets.right);
	} else {
		temporarySizingLabel.numberOfLines = 1;
		insetViewRect = CGRectMake(0.f, 0.f, CGFLOAT_MAX, CGFLOAT_MAX);
//    NSLog(@"fitOriginalFontSizeToViewWidth: NO");
	}
	
	CGSize originalSize = [temporarySizingLabel sizeThatFits:insetViewRect.size];
	temporarySizingLabel.frame = CGRectMake(0.f,
											0.f,
											originalSize.width * 1.05f,
											originalSize.height * 1.05f);
	temporarySizingLabel.center = self.center;
	self.unscaledFrame = temporarySizingLabel.frame;
  
//  NSLog(@"insetViewRect.size.width: %f", insetViewRect.size.width);
//  NSLog(@"SomeUnscaledFrame.Origin.x: %f", self.unscaledFrame.origin.x);
//  NSLog(@"SomeUnscaledFrame.Origin.y: %f", self.unscaledFrame.origin.y);
//  NSLog(@"SomeUnscaledFrame.Size.width: %f", self.unscaledFrame.size.width);
//  NSLog(@"SomeUnscaledFrame.Size.height: %f", self.unscaledFrame.size.height);
}


#pragma mark - Serialization

+ (instancetype)fromSerialized:(NSDictionary*)dictionary {
	JotLabel *label = [JotLabel new];
	[label unserialize:dictionary];
	return label;
}

- (NSMutableDictionary*)serialize {
	NSMutableDictionary *dic = [NSMutableDictionary new];
	dic[kText] = self.text;  // NSString
	dic[kFontName] = self.font.fontName;  // NSString
	dic[kFontSize] = @(self.unscaledFontSize);  // CGFloat
  
  CGFloat colorRed;
  CGFloat colorGreen;
  CGFloat colorBlue;
  CGFloat colorAlpha;

  [self.textColor getRed: &colorRed green: &colorGreen blue: &colorBlue alpha: &colorAlpha];
  
  dic[kTextColor] = @{ kLabelColorRed: @(colorRed), kLabelColorGreen: @(colorGreen), kLabelColorBlue: @(colorBlue), kLabelColorAlpha: @(colorAlpha) };
	dic[kAlignment] = @(self.textAlignment);  // NSTextAlignment enum raw Int
  dic[kCenter] = @{ kLabelPointX: @(self.center.x), kLabelPointY: @(self.center.y) };
	dic[kRotation] = @(atan2f(self.transform.b, self.transform.a)); // Tan 2 Float?
	dic[kScale] = @(self.scale);  // CGFloat
	dic[kFitWidth] = @(self.fitOriginalFontSizeToViewWidth);  // Bool
	return dic;
}

- (void)unserialize:(NSDictionary*)dictionary {
	if (dictionary[kText]) {
		self.text = dictionary[kText];
	}
	else return;
	
	if (dictionary[kFontName] && dictionary[kFontSize]) {
		self.font = [UIFont fontWithName:dictionary[kFontName]
									size:[dictionary[kFontSize] floatValue]];
		self.unscaledFontSize = [dictionary[kFontSize] floatValue];
	}
	if (dictionary[kTextColor]) {
    NSDictionary *color = dictionary[kTextColor];
    NSNumber *numberRed = color[kLabelColorRed];
    NSNumber *numberGreen = color[kLabelColorGreen];
    NSNumber *numberBlue = color[kLabelColorBlue];
    NSNumber *numberAlpha = color[kLabelColorAlpha];

    self.textColor = [UIColor colorWithRed:[numberRed floatValue]
                                     green:[numberGreen floatValue]
                                      blue:[numberBlue floatValue]
                                     alpha:[numberAlpha floatValue]];
	}
	if (dictionary[kAlignment]) {
		self.textAlignment = [dictionary[kAlignment] integerValue];
	}
	if (dictionary[kCenter]) {
    NSDictionary *center = dictionary[kCenter];
    NSNumber *numberX = center[kLabelPointX];
    NSNumber *numberY = center[kLabelPointY];
    CGPoint centerPoint;
    centerPoint.x = numberX.doubleValue;
    centerPoint.y = numberY.doubleValue;
    
    self.center = centerPoint;
	}
	if (dictionary[kRotation]) {
		self.transform = CGAffineTransformMakeRotation([dictionary[kRotation] floatValue]);
	}
	if (dictionary[kScale]) {
		self.scale = [dictionary[kScale] floatValue];
	}
	if ([dictionary[kFitWidth] boolValue]) {
		self.fitOriginalFontSizeToViewWidth = YES;
		self.numberOfLines = 0;
	}
	
	[self refreshFont];
}


@end
