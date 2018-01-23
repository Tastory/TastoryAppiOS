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
NSString *const kAlignment = @"Alignment";
NSString *const kCenter = @"Center";
NSString *const kRotation = @"kRotation";
NSString *const kScale = @"Scale";
NSString *const kFitWidth = @"FitWidth";

NSString *const kTextColor = @"Color";
NSString *const kLabelColorRed = @"LabelColorRed";
NSString *const kLabelColorGreen = @"LabelColorGreen";
NSString *const kLabelColorBlue = @"LabelColorBlue";
NSString *const kLabelColorAlpha = @"LabelColorAlpha";
NSString *const kLabelPointX = @"LabelPointX";
NSString *const kLabelPointY = @"LabelPointY";

NSString *const kBackingColor = @"BackingColor";
NSString *const kBgColorRed = @"BgColorRed";
NSString *const kBgColorGreen = @"BgColorGreen";
NSString *const kBgColorBlue = @"BgColorBlue";
NSString *const kBgColorAlpha = @"BgColorAlpha";
NSString *const kBgWhiteValue = @"BgWhiteValue";
NSString *const kBgAlphaValue = @"BgAlphaValue";

NSString *const kTextInsets = @"TextInsets";
NSString *const kTextInsetTop = @"TextInsetTop";
NSString *const kTextInsetBottom = @"TextInsetBottom";
NSString *const kTextInsetLeft = @"TextInsetLeft";
NSString *const kTextInsetRight = @"TextInsetRight";

CGFloat const bgPadWidthAsFontFraction = 0.5f; // Hand tuned numbers
CGFloat const bgPadHeightAsFontFraction = 0.25f;
CGFloat const bgCornerRadiusAsFontFraction = 0.3f;

@interface JotLabel ()

@end

@implementation JotLabel

- (instancetype)init
{
	self = [super init];
	if (self) {
		_initialRotationTransform = CGAffineTransformIdentity;
		_scale = 1;
		_unscaledFrame = self.frame;
    
    // Create a little background placeholder for the label
    self.layer.backgroundColor = [[UIColor colorWithWhite:1.0f alpha:0.0f] CGColor];
	}
	return self;
}

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines
{
  UIEdgeInsets insets = UIEdgeInsetsMake(self.font.pointSize * bgPadHeightAsFontFraction,
                                         self.font.pointSize * bgPadWidthAsFontFraction,
                                         self.font.pointSize * bgPadHeightAsFontFraction,
                                         self.font.pointSize * bgPadWidthAsFontFraction);
  CGRect rect = [super textRectForBounds:bounds limitedToNumberOfLines:numberOfLines];

  rect.origin.x    -= insets.left;
  rect.origin.y    -= insets.top;
  rect.size.width  += (insets.left + insets.right);
  rect.size.height += (insets.top + insets.bottom);

  return rect;
}

- (void)drawTextInRect:(CGRect)rect
{
  [super drawTextInRect:UIEdgeInsetsInsetRect(rect, UIEdgeInsetsMake(self.font.pointSize * bgPadHeightAsFontFraction,
                                                                     self.font.pointSize * bgPadWidthAsFontFraction,
                                                                     self.font.pointSize * bgPadHeightAsFontFraction,
                                                                     self.font.pointSize * bgPadWidthAsFontFraction))];
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
										_unscaledFrame.size.width * self.scale,// * 1.03f,  // 1.0X is for extra space around the label
                    _unscaledFrame.size.height * self.scale);// * 1.03f);
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
										_unscaledFrame.size.width * _scale,// * 1.03f,
                    _unscaledFrame.size.height * _scale);// * 1.03f);
		CGFloat currentFontSize = self.unscaledFontSize * _scale;
		self.font = [self.font fontWithSize:currentFontSize];
		self.layer.cornerRadius = currentFontSize * bgCornerRadiusAsFontFraction;
    
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
  temporarySizingLabel.lineBreakMode = NSLineBreakByWordWrapping;
  
	CGRect insetViewRect;
	
	if (_fitOriginalFontSizeToViewWidth) {
		temporarySizingLabel.numberOfLines = 0;
		insetViewRect = CGRectInset(self.superview.bounds,
									(self.initialTextInsets.left + self.initialTextInsets.right)/2,
									(self.initialTextInsets.top + self.initialTextInsets.bottom)/2);
	} else {
		temporarySizingLabel.numberOfLines = 1;
		insetViewRect = CGRectMake(0.f, 0.f, CGFLOAT_MAX, CGFLOAT_MAX);
	}
	
	CGSize originalSize = [temporarySizingLabel sizeThatFits:insetViewRect.size];
	temporarySizingLabel.frame = CGRectMake(0.f,
											0.f,
											originalSize.width,
                      originalSize.height * 1.03f);
	temporarySizingLabel.center = self.center;
  
	self.unscaledFrame = temporarySizingLabel.frame;
  self.layer.cornerRadius = self.unscaledFontSize * self.scale * bgCornerRadiusAsFontFraction;
}


#pragma mark - Serialization

+ (instancetype)fromSerialized:(NSDictionary*)dictionary on:(CGFloat)ratioForAspectFitAgainstiPhone6 with:(UIEdgeInsets)textInsets bounds:(CGRect)superBounds{
	JotLabel *label = [JotLabel new];
  label.initialTextInsets = textInsets;
  [label unserialize:dictionary on:ratioForAspectFitAgainstiPhone6 bounds:superBounds];
	return label;
}

- (NSMutableDictionary*)serialize:(CGFloat)ratioForAspectFitAgainstiPhone6 {
	NSMutableDictionary *dic = [NSMutableDictionary new];
	dic[kText] = self.text;  // NSString
	dic[kFontName] = self.font.fontName;  // NSString
	dic[kFontSize] = @(self.unscaledFontSize);  // CGFloat
  dic[kAlignment] = @(self.textAlignment);  // NSTextAlignment enum raw Int
  dic[kCenter] = @{ kLabelPointX: @(self.center.x / ratioForAspectFitAgainstiPhone6), kLabelPointY: @(self.center.y / ratioForAspectFitAgainstiPhone6) };  // Only need to move the points and change the size (scale). Don't need to touch Font sizing
  dic[kRotation] = @(atan2f(self.transform.b, self.transform.a)); // Tan 2 Float?
  dic[kScale] = @(self.scale / ratioForAspectFitAgainstiPhone6);  // Only need to move the points and change the size (scale). Don't need to touch Font sizing
  dic[kFitWidth] = @(self.fitOriginalFontSizeToViewWidth);  // Bool
  
  CGFloat textColorRed;
  CGFloat textColorGreen;
  CGFloat textColorBlue;
  CGFloat textColorAlpha;

  [self.textColor getRed: &textColorRed green: &textColorGreen blue: &textColorBlue alpha: &textColorAlpha];
  
  dic[kTextColor] = @{ kLabelColorRed: @(textColorRed),
                       kLabelColorGreen: @(textColorGreen),
                       kLabelColorBlue: @(textColorBlue),
                       kLabelColorAlpha: @(textColorAlpha) };

  CGFloat bgColorRed;
  CGFloat bgColorGreen;
  CGFloat bgColorBlue;
  CGFloat bgColorAlpha;
  
  [[UIColor colorWithCGColor: self.layer.backgroundColor] getRed: &bgColorRed green: &bgColorGreen blue: &bgColorBlue alpha: &bgColorAlpha];
  
  dic[kBackingColor] = @{ kBgColorRed: @(bgColorRed),
                          kBgColorGreen: @(bgColorGreen),
                          kBgColorBlue: @(bgColorBlue),
                          kBgColorAlpha: @(bgColorAlpha) };
  
  CGFloat widthInsetAdjustment = (self.superview.bounds.size.width - (self.superview.bounds.size.width / ratioForAspectFitAgainstiPhone6))/2;
  CGFloat heightInsetAdjustment = (self.superview.bounds.size.height - (self.superview.bounds.size.height / ratioForAspectFitAgainstiPhone6))/2;
  
  dic[kTextInsets] = @{ kTextInsetTop: @(self.initialTextInsets.top - heightInsetAdjustment),
                        kTextInsetLeft: @(self.initialTextInsets.left - widthInsetAdjustment),
                        kTextInsetBottom: @(self.initialTextInsets.bottom - heightInsetAdjustment),
                        kTextInsetRight: @(self.initialTextInsets.right - widthInsetAdjustment) };
	return dic;
}

- (void)unserialize:(NSDictionary*)dictionary on:(CGFloat)ratioForAspectFitAgainstiPhone6 bounds:(CGRect)superBounds {
	if (dictionary[kText]) {
		self.text = dictionary[kText];
	}
	else return;
	
	if (dictionary[kFontName] && dictionary[kFontSize]) {
		self.font = [UIFont fontWithName:dictionary[kFontName]
									size:[dictionary[kFontSize] floatValue]];
		self.unscaledFontSize = [dictionary[kFontSize] floatValue];
	}
	if (dictionary[kAlignment]) {
		self.textAlignment = [dictionary[kAlignment] integerValue];
	}
	if (dictionary[kCenter]) {
    NSDictionary *center = dictionary[kCenter];
    NSNumber *numberX = center[kLabelPointX];
    NSNumber *numberY = center[kLabelPointY];
    CGPoint centerPoint;
    centerPoint.x = numberX.doubleValue * ratioForAspectFitAgainstiPhone6;  // Only need to move the points and change the size (scale). Don't need to touch Font sizing
    centerPoint.y = numberY.doubleValue * ratioForAspectFitAgainstiPhone6;  // Only need to move the points and change the size (scale). Don't need to touch Font sizing
    
    self.center = centerPoint;
	}
	if (dictionary[kRotation]) {
		self.transform = CGAffineTransformMakeRotation([dictionary[kRotation] floatValue]);
	}
	if (dictionary[kScale]) {
    self.scale = [dictionary[kScale] floatValue] * ratioForAspectFitAgainstiPhone6;  // Only need to move the points and change the size (scale). Don't need to touch Font sizing
	}
	if ([dictionary[kFitWidth] boolValue]) {
    self.lineBreakMode = NSLineBreakByWordWrapping;
		self.fitOriginalFontSizeToViewWidth = YES;
		self.numberOfLines = 0;
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
  
  if (dictionary[kBackingColor]) {
    NSDictionary * color = dictionary[kBackingColor];
    NSNumber *numberRed = color[kBgColorRed];
    NSNumber *numberGreen = color[kBgColorGreen];
    NSNumber *numberBlue = color[kBgColorBlue];
    NSNumber *numberAlpha = color[kBgColorAlpha];
    
    self.layer.backgroundColor = [[UIColor colorWithRed:[numberRed floatValue]
                                                  green:[numberGreen floatValue]
                                                   blue:[numberBlue floatValue]
                                                  alpha:[numberAlpha floatValue]] CGColor];
  }
  
  else if (dictionary[kBgWhiteValue] && dictionary[kBgAlphaValue]) {
    self.layer.backgroundColor = [[UIColor colorWithWhite: [dictionary[kBgWhiteValue] floatValue] alpha: [dictionary[kBgAlphaValue] floatValue]] CGColor];
  }
  
  if (dictionary[kTextInsets]) {
    CGFloat widthInsetAdjustment = (superBounds.size.width - (superBounds.size.width / ratioForAspectFitAgainstiPhone6))/2;
    CGFloat heightInsetAdjustment = (superBounds.size.height - (superBounds.size.height / ratioForAspectFitAgainstiPhone6))/2;
    
    NSDictionary *textInset = dictionary[kTextInsets];
    CGFloat textInsetTop = [textInset[kTextInsetTop] floatValue] + heightInsetAdjustment;
    CGFloat textInsetLeft = [textInset[kTextInsetLeft] floatValue] + widthInsetAdjustment;
    CGFloat textInsetBottom = [textInset[kTextInsetBottom] floatValue] + heightInsetAdjustment;
    CGFloat textInsetRight = [textInset[kTextInsetRight] floatValue] + widthInsetAdjustment;
    self.initialTextInsets = UIEdgeInsetsMake(textInsetTop, textInsetLeft, textInsetBottom, textInsetRight);
  }

	[self refreshFont];
}


@end
