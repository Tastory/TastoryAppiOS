//
//  JotTextView.m
//  jot
//
//  Created by Laura Skelton on 4/30/15.
//
//

#import "JotTextView.h"
#import "UIImageView+ImageFrame.h"
#import "JotLabel.h"

@interface JotTextView ()

//@property (nonatomic, strong) JotLabel *selectedLabel;
@property (nonatomic, strong) NSMutableArray <JotLabel*> *labels;
@property (nonatomic, strong) UIView *textEditingContainer;
@property (nonatomic, strong) UITextView *textEditingView;
@property (nonatomic, assign) CGPoint referenceCenter;
@property (nonatomic, strong) UIPinchGestureRecognizer *activePinchRecognizer;
@property (nonatomic, strong) UIRotationGestureRecognizer *activeRotationRecognizer;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, strong) UIImpactFeedbackGenerator *impactFeedbackGenerator;
@property (nonatomic, assign) Boolean rotateSnapped;
@end

@implementation JotTextView

- (instancetype)init
{
  if ((self = [super init])) {
    
    self.backgroundColor = [UIColor clearColor];
    
    _initialTextInsets = UIEdgeInsetsMake(0.f, 0.f, 0.f, 0.f);
    
    CGFloat fontSize = 60.f;
    _scale = 1.f;
    _font = [UIFont systemFontOfSize:fontSize];
    _textAlignment = NSTextAlignmentCenter;
    _textColor = [UIColor blackColor];
    _backingColor = [UIColor colorWithWhite:1.0f alpha:0.0f];
    
    _labels = [NSMutableArray new];
    
    self.referenceCenter = CGPointZero;
    
    self.userInteractionEnabled = NO;
  }
  
  return self;
}

#pragma mark - Undo

- (void)clearAll
{
  while (_selectedLabel) {
    [self deleteSelectedLabel];
  }
  
  NSMutableArray *toDelete = [NSMutableArray array];
  
  for (JotLabel *currentLabel in _labels) {
    [toDelete addObject:currentLabel];
    [currentLabel removeFromSuperview];
  }
  
  [_labels removeObjectsInArray:toDelete];
}

#pragma mark - Properties

- (void)setTextString:(NSString *)textString
{
	if (textString.length == 0) {
		// delete it.
		if (_selectedLabel) {
			[self deleteSelectedLabel];
		}
	}
	else {
		if (!_selectedLabel) {
			[self addLabelAtPosition:self.center];
		}
		CGPoint center = self.selectedLabel.center;
		self.selectedLabel.text = textString;
    self.selectedLabel.initialTextInsets = self.initialTextInsets;
		[self.selectedLabel autosize];
		self.selectedLabel.center = center;
	}
}

- (void)setFontSize:(CGFloat)fontSize
{
	_fontSize = fontSize;
    if (_selectedLabel) {
		self.selectedLabel.unscaledFontSize = fontSize;
		[self.selectedLabel refreshFont];
    }
}

- (void)setFont:(UIFont *)font
{
	_font = font;
    if (_selectedLabel) {
		self.selectedLabel.font = font;
		self.selectedLabel.unscaledFontSize = font.pointSize;
		[self.selectedLabel refreshFont];
    }
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment
{
	_textAlignment = textAlignment;
    if (_selectedLabel) {
        self.selectedLabel.textAlignment = self.textAlignment;
		[self.selectedLabel autosize];
    }
}

- (void)setBackingColor:(UIColor *)backingColor
{
  _backingColor = backingColor;
  if (_selectedLabel) {
    self.selectedLabel.layer.backgroundColor = [backingColor CGColor];
    // [self.selectedLabel autosize];
  }
}
  
- (void)setInitialTextInsets:(UIEdgeInsets)initialTextInsets
{
	_initialTextInsets = initialTextInsets;
    if (_selectedLabel) {
        self.selectedLabel.initialTextInsets = initialTextInsets;
        [self.selectedLabel autosize];
    }
}

- (void)setFitOriginalFontSizeToViewWidth:(BOOL)fitOriginalFontSizeToViewWidth
{
	_fitOriginalFontSizeToViewWidth = fitOriginalFontSizeToViewWidth;
    if (_selectedLabel) {
		self.selectedLabel.fitOriginalFontSizeToViewWidth = fitOriginalFontSizeToViewWidth;
        self.selectedLabel.numberOfLines = (fitOriginalFontSizeToViewWidth ? 0 : 1);
        [self.selectedLabel autosize];
    }
}

- (void)setTextColor:(UIColor *)textColor
{
	_textColor = textColor;
    if (_selectedLabel) {
        self.selectedLabel.textColor = textColor;
    }
}

- (void)setSelectedLabel:(JotLabel *)selectedLabel {
	if (_selectedLabel != selectedLabel) {
		_selectedLabel.selected = NO;
		if (selectedLabel) {
			selectedLabel.selected = YES;
			self.referenceCenter = selectedLabel.center;
			
			// place the selected label at last array position
			if (selectedLabel != [_labels lastObject]) {
				NSUInteger index = [_labels indexOfObject:selectedLabel];
				if (index != NSNotFound) {
					[_labels removeObjectAtIndex:index];
					[_labels addObject:selectedLabel];
					[self bringSubviewToFront:selectedLabel];
				}
			}
		}
		_selectedLabel = selectedLabel;
	}
}

#pragma mark - Methods

- (JotLabel*)labelAtPosition:(CGPoint)point {
	for (int i=(int)_labels.count-1; i>=0; i--) {
		JotLabel *label = self.labels[i];
		if ([label.layer containsPoint:[label convertPoint:point fromView:self]]) {
			return label;
		}
	}
	return nil;
}

- (JotLabel*)selectLabelAtPosition:(CGPoint)point {
	JotLabel *label = [self labelAtPosition:point];
	if (label) {
		self.selectedLabel = label;
	}
	return label;
}


- (void)deselectLabel {
	if (_selectedLabel) {
		self.selectedLabel = nil;
	}
}

- (JotLabel*)addLabelAtPosition:(CGPoint)point {
	self.selectedLabel = [JotLabel new];
	self.selectedLabel.fitOriginalFontSizeToViewWidth = self.fitOriginalFontSizeToViewWidth;
	self.selectedLabel.numberOfLines = (self.fitOriginalFontSizeToViewWidth ? 0 : 1);
	self.selectedLabel.initialTextInsets = self.initialTextInsets;
	self.selectedLabel.font = self.font;
  self.selectedLabel.unscaledFontSize = self.fontSize;
	self.selectedLabel.textColor = self.textColor;
	self.selectedLabel.textAlignment = self.textAlignment;
  self.selectedLabel.layer.backgroundColor = [self.backingColor CGColor];
	self.selectedLabel.center = point;
	[self.selectedLabel autosize];
	[self.labels addObject:self.selectedLabel];
	[self addSubview:self.selectedLabel];
	return self.selectedLabel;
}

- (void)deleteSelectedLabel {
	[_labels removeObject:_selectedLabel];
	[_selectedLabel removeFromSuperview];
	self.selectedLabel = [_labels lastObject];
}

#pragma mark - Gestures

- (void)handlePanGesture:(UIGestureRecognizer *)recognizer
{
    if (![recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return;
    }
    
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
			CGPoint touch = [recognizer locationOfTouch:0 inView:self];
			[self selectLabelAtPosition:touch];
			
            self.referenceCenter = self.selectedLabel.center;
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            CGPoint panTranslation = [(UIPanGestureRecognizer *)recognizer translationInView:self];
            self.selectedLabel.center = CGPointMake(self.referenceCenter.x + panTranslation.x,
                                                self.referenceCenter.y + panTranslation.y);;
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            self.referenceCenter = self.selectedLabel.center;
            break;
        }
            
        default:
            break;
    }
}

- (void)handlePinchOrRotateGesture:(UIGestureRecognizer *)recognizer
{
    switch (recognizer.state) {
        
        case UIGestureRecognizerStateBegan: {
          
            if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
                self.activeRotationRecognizer = (UIRotationGestureRecognizer *)recognizer;
              
            } else {
                self.activePinchRecognizer = (UIPinchGestureRecognizer *)recognizer;
            }
          
            // Initialize and prepare Impact Feedback whenever Pinch or Rotate begins
            self.impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [self.impactFeedbackGenerator prepare];
          
            // See if snapped
            CGFloat snapMargin = 0.01 * 2.0 * M_PI; // 1%
            CGFloat currentAngle = atan2f(self.selectedLabel.initialRotationTransform.b, self.selectedLabel.initialRotationTransform.a);
          
            if (((currentAngle > -snapMargin) && (currentAngle < snapMargin)) ||
                ((currentAngle > (M_PI/2 - snapMargin)) && (currentAngle < (M_PI/2 + snapMargin))) ||
                ((currentAngle > (M_PI - snapMargin)) && (currentAngle < (M_PI + snapMargin))) ||
                ((currentAngle > (3*M_PI/2 - snapMargin)) && (currentAngle < (3*M_PI/2 + snapMargin))) ||
                ((currentAngle > (2*M_PI - snapMargin)) && (currentAngle < (2*M_PI + snapMargin)))) {

                self.rotateSnapped = true;
            } else {
                self.rotateSnapped = false;
            }
            break;
        }
        
        case UIGestureRecognizerStateChanged: {
          
            CGAffineTransform currentTransform = self.selectedLabel.initialRotationTransform;
          
            // Apply the rotation
            currentTransform = [self applyRecognizer:self.activeRotationRecognizer toTransform:currentTransform];
          
            // Apply the scale
            currentTransform = [self applyRecognizer:self.activePinchRecognizer toTransform:currentTransform];
            
            self.selectedLabel.transform = currentTransform;
            break;
        }
        
        case UIGestureRecognizerStateEnded: {
          
            if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
                self.selectedLabel.initialRotationTransform = [self applyRecognizer:recognizer toTransform:self.selectedLabel.initialRotationTransform];
                self.activeRotationRecognizer = nil;
				
            } else if ([recognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
                self.selectedLabel.scale *= self.activePinchRecognizer.scale;
                self.activePinchRecognizer = nil;
            }
          
            self.impactFeedbackGenerator = nil;
            break;
        }
            
        default:
            self.impactFeedbackGenerator = nil;
            break;
    }
}

- (CGAffineTransform)applyRecognizer:(UIGestureRecognizer *)recognizer toTransform:(CGAffineTransform)transform
{
    if (!recognizer
        || !([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]
             || [recognizer isKindOfClass:[UIPinchGestureRecognizer class]])) {
        return transform;
    }
    
    if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
      
        Boolean wasSnapped = self.rotateSnapped;
        CGFloat snapMargin = 0.01 * 2.0 * M_PI; // 1%
        CGFloat currentAngle = atan2f(transform.b, transform.a);
        CGFloat rotation = [(UIRotationGestureRecognizer *)recognizer rotation];
        CGFloat newAngle = fmod((currentAngle + rotation), (2.0 * M_PI));
      
        if (newAngle < 0.0) {
          newAngle += (2.0 * M_PI);
        }
      
        // 0 O'clock position
        if ((newAngle > -snapMargin) && (newAngle < snapMargin)) {
          newAngle = 0;
          self.rotateSnapped = true;
          
          
        // 3 O'clock position
        } else if ((newAngle > (M_PI/2 - snapMargin)) && (newAngle < (M_PI/2 + snapMargin))) {
          newAngle = M_PI/2;
          self.rotateSnapped = true;
          
        // 6 O'clock position
        } else if ((newAngle > (M_PI - snapMargin)) && (newAngle < (M_PI + snapMargin))) {
          newAngle = M_PI;
          self.rotateSnapped = true;
          
        // 9 O'clock position
        } else if ((newAngle > (3*M_PI/2 - snapMargin)) && (newAngle < (3*M_PI/2 + snapMargin))) {
          newAngle = 3*M_PI/2;
          self.rotateSnapped = true;
          
        // 12 O'clock position
        } else if ((newAngle > (2*M_PI - snapMargin)) && (newAngle < (2*M_PI + snapMargin))) {
          newAngle = 0;
          self.rotateSnapped = true;
          
        } else {
          self.rotateSnapped = false;
        }
      
        if (!wasSnapped && self.rotateSnapped) {
          [self.impactFeedbackGenerator impactOccurred];
          [self.impactFeedbackGenerator prepare];
          NSLog(@"Feedback Triggered");
        }

        return CGAffineTransformRotate(transform, newAngle - currentAngle);
    }
    
    CGFloat scale = [(UIPinchGestureRecognizer *)recognizer scale];
    return CGAffineTransformScale(transform, scale, scale);
}

#pragma mark - Image Rendering

- (UIImage *)drawTextOnImage:(UIImage *)backgroundImage withScaledFrame:(CGRect)frame scaleFactor:(CGFloat)scale
{
	CGSize size;
	if (backgroundImage) {
		CGRect maxRect = CGRectUnion(self.bounds, CGRectMake(0, 0, backgroundImage.size.width, backgroundImage.size.height));
		size = maxRect.size;
	}
	else {
		size = self.bounds.size;
	}
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    
    [backgroundImage drawAtPoint:CGPointZero];
    CGContextScaleCTM(UIGraphicsGetCurrentContext(), scale, scale);
	
	_selectedLabel.selected = NO; // remove the selection border

    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
	_selectedLabel.selected = YES;
	
    UIImage *drawnImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [UIImage imageWithCGImage:drawnImage.CGImage
                               scale:0.f
                         orientation:drawnImage.imageOrientation];
}

#pragma mark - Serialization

- (NSArray*)serialize:(CGFloat)ratioForAspectFitAgainstiPhone6 {
	NSMutableArray *labels = [NSMutableArray new];

	for (JotLabel *label in self.labels) {
    [labels addObject:[label serialize:ratioForAspectFitAgainstiPhone6]];
	}
	return labels;
}

- (void)unserialize:(NSArray*)array on:(CGFloat)ratioForAspectFitAgainstiPhone6{
	for (NSDictionary *labelDic in array) {
    JotLabel *label = [JotLabel fromSerialized:labelDic on:ratioForAspectFitAgainstiPhone6 with:self.initialTextInsets bounds:self.bounds];
		[self.labels addObject:label];
		[self addSubview:label];
    [label autosize];
	}
}

@end
