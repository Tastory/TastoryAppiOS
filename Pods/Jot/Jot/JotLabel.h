//
//  JotLabel.h
//  DrawModules
//
//  Created by Martin Prot on 24/09/2015.
//  Copyright © 2015 appricot. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString *const kText;
extern NSString *const kFontName;
extern NSString *const kFontSize;
extern NSString *const kTextColor;
extern NSString *const kAlignment;
extern NSString *const kCenter;
extern NSString *const kRotation;
extern NSString *const kScale;
extern NSString *const kFitWidth;

extern CGFloat const bgPadWidthAsFontFraction;
extern CGFloat const bgPadHeightAsFontFraction;
extern CGFloat const bgCornerRadiusAsFontFraction;

@interface JotLabel : UILabel

@property (nonatomic) BOOL selected;

@property (nonatomic, assign) CGFloat unscaledFontSize;

@property (nonatomic, assign) CGRect unscaledFrame;

@property (nonatomic, assign) CGFloat scale;

@property (nonatomic, assign) BOOL fitOriginalFontSizeToViewWidth;

@property (nonatomic, assign) UIEdgeInsets initialTextInsets;

/**
 *  The rotation transform before the movement. Used as reference during the 
 *  movement.
 */
@property (nonatomic) CGAffineTransform initialRotationTransform;

- (void)refreshFont;

- (void)autosize;

#pragma mark - Serialization

/**
 *  Creates a new JotTouchObject from a serialized dictionary
 *
 *  @param dictionary the serialization
 *
 *  @return the new JotTouchObject.
 */
+ (instancetype)fromSerialized:(NSDictionary*)dictionary on:(CGFloat)ratioForAspectFitAgainstiPhone6 with:(UIEdgeInsets)textInsets bounds:(CGRect)superBounds;

/**
 *  Convert the object to a dictionary
 *
 *  @return the object, as a NSDictionary
 */
- (NSMutableDictionary*)serialize:(CGFloat)ratioForAspectFitAgainstiPhone6;

/**
 *  Unserialize the object from a dictionary
 *
 *  @param the NSDictionary representing the object
 */
- (void)unserialize:(NSDictionary*)dictionary on:(CGFloat)ratioForAspectFitAgainstiPhone6 bounds:(CGRect)superBounds;


@end
