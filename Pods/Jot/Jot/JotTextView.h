//
//  JotTextView.h
//  jot
//
//  Created by Laura Skelton on 4/30/15.
//
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@class JotLabel;

/**
 *  Private class to handle text display and gesture interactions.
 *  Change the properties in a JotViewController instance to 
 *  configure this private class.
 */
@interface JotTextView : UIView

/**
 *  The text string the JotTextView is currently displaying.
 *
 *  @note Set textString in JotViewController
 *  to control or read this property.
 */
@property (nonatomic, strong) NSString *textString;

/**
 *  The color of the text displayed in the JotTextView.
 *
 *  @note Set textColor in JotViewController
 *  to control this property.
 */
@property (nonatomic, strong) UIColor *textColor;

/**
 *  The font of the text displayed in the JotTextView.
 *
 *  @note Set font in JotViewController to control this property.
 *  To change the default size of the font, you must also set the
 *  fontSize property to the desired font size.
 */
@property (nonatomic, assign) UIFont *font;

/**
 *  The initial font size of the text displayed in the JotTextView. The
 *  displayed text's font size will get proportionally larger or smaller 
 *  than this size if the viewer pinch zooms the text.
 *
 *  @note Set fontSize in JotViewController to control this property,
 *  which overrides the size of the font property.
 */
@property (nonatomic, assign) CGFloat fontSize;

/**
 *  The alignment of the text displayed in the JotTextView, which only
 *  applies if fitOriginalFontSizeToViewWidth is true.
 *
 *  @note Set textAlignment in JotViewController to control this property,
 *  which will be ignored if fitOriginalFontSizeToViewWidth is false.
 */
@property (nonatomic, assign) NSTextAlignment textAlignment;

/**
 *  Greyscale & alpha value of the textView background color
 */
@property (nonatomic, assign) CGFloat whiteValue;
@property (nonatomic, assign) CGFloat alphaValue;

/**
 *  The initial insets of the text displayed in the JotTextView, which only
 *  applies if fitOriginalFontSizeToViewWidth is true. If fitOriginalFontSizeToViewWidth
 *  is true, then initialTextInsets sets the initial insets of the displayed text relative to the
 *  full size of the JotTextView. The user can resize, move, and rotate the text from that
 *  starting position, but the overall proportions of the text will stay the same.
 *
 *  @note Set initialTextInsets in JotViewController to control this property,
 *  which will be ignored if fitOriginalFontSizeToViewWidth is false.
 */
@property (nonatomic, assign) UIEdgeInsets initialTextInsets;

/**
 *  If fitOriginalFontSizeToViewWidth is true, then the text will wrap to fit within the width
 *  of the JotTextView, with the given initialTextInsets, if any. The layout will reflect
 *  the textAlignment property as well as the initialTextInsets property. If this is false,
 *  then the text will be displayed as a single line, and will ignore any initialTextInsets and
 *  textAlignment settings
 *
 *  @note Set fitOriginalFontSizeToViewWidth in JotViewController to control this property.
 */
@property (nonatomic, assign) BOOL fitOriginalFontSizeToViewWidth;

@property (nonatomic, strong) JotLabel *selectedLabel;




/**
 *  Clears all the texts from the drawing, giving a blank slate.
 *
 *  @note Call clearText or clearAll in JotViewController
 *  to trigger this method.
 */
- (void)clearAll;

/**
 *  Returns the label at the given position
 *
 *  @param point the position, in the JotTextView coordinates
 *
 *  @return return the label, or nil if no label found
 */
- (JotLabel*)labelAtPosition:(CGPoint)point;

/**
 *  Calls labelAtPosition: and select the label if found
 *
 *  @param point the position, in the JotTextView coordinates
 *
 *  @return return the selected label, or nil
 */
- (JotLabel*)selectLabelAtPosition:(CGPoint)point;


/**
 *  Deselects the label
 */
- (void)deselectLabel;

/**
 *  Adds a new label at the given position
 *
 *  @param point the position, in the JotTextView coordinates
 *
 *  @return the newly added label
 */
- (JotLabel*)addLabelAtPosition:(CGPoint)point;

/**
 *  Deletes the currently selected label
 */
- (void)deleteSelectedLabel;

/**
 *  Overlays the text on the given background image with the appropriate scaling.
 *
 *  @param backgroundImage The image containing the background image to render text on top of.
 *  @param scale The amount the image has been scaled by to fit it's container.
 *  @param frame The frame of the image inside the imageView.
 *
 *  @return An image of the rendered drawing on the background image.
 *
 *  @note Call drawOnImage: in JotViewController
 *  to trigger this method.
 */
- (UIImage *)drawTextOnImage:(UIImage *)backgroundImage withScaledFrame:(CGRect)frame scaleFactor:(CGFloat)scale;

/**
 *  Tells the JotTextView to handle a pan gesture.
 *
 *  @param recognizer The pan gesture recognizer to handle.
 *
 *  @note This method is triggered by the JotDrawController's
 *  internal pan gesture recognizer.
 */
- (void)handlePanGesture:(UIGestureRecognizer *)recognizer;

/**
 *  Tells the JotTextView to handle a pinch or rotate gesture.
 *
 *  @param recognizer The pinch or rotation gesture recognizer to handle.
 *
 *  @note This method is triggered by the JotDrawController's
 *  internal pinch and rotation gesture recognizers.
 */
- (void)handlePinchOrRotateGesture:(UIGestureRecognizer *)recognizer;

#pragma mark - Serialization

/**
 *  Convert the draw view into an array
 *
 *  @return the object, as a NSArray
 */
- (NSArray*)serialize:(CGFloat)ratioForAspectFitAgainstiPhone6;

/**
 *  Unserialize the draw view from an array
 *
 *  @param the NSArray representing the object
 */
- (void)unserialize:(NSArray*)array on:(CGFloat)ratioForAspectFitAgainstiPhone6;

@end
