//
//  JotDrawView.h
//  jot
//
//  Created by Laura Skelton on 4/30/15.
//
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

extern NSString const* kObjects;
extern NSString const* kUndoArray;

@protocol JotDrawViewDelegate <NSObject>

- (void)shouldDisableUndo;
- (void)shouldEnableUndo;

@end

/**
 *  Private class to handle touch drawing. Change the properties
 *  in a JotViewController instance to configure this private class.
 */
@interface JotDrawView : UIView

@property (nonatomic, weak) id<JotDrawViewDelegate> delegate;

/**
 *  Set to YES if you want the stroke width to be constant,
 *  NO if the stroke width should vary depending on drawing
 *  speed.
 *
 *  @note Set drawingConstantStrokeWidth in JotViewController
 *  to control this setting.
 */
@property (nonatomic, assign) BOOL constantStrokeWidth;

/**
 *  Sets the stroke width if constantStrokeWidth is true,
 *  or sets the base strokeWidth for variable drawing paths.
 *
 *  @note Set drawingStrokeWidth in JotViewController
 *  to control this setting.
 */
@property (nonatomic, assign) CGFloat strokeWidth;

/**
 *  Sets the stroke color. Each path can have its own stroke color.
 *
 *  @note Set drawingColor in JotViewController
 *  to control this setting.
 */
@property (nonatomic, strong) UIColor *strokeColor;

/**
 *  Yes if the line should dashed, No otherwise
 */
@property (nonatomic, assign) BOOL dashedLine;

/**
 *  Yes to constraint lines to be right angle only
 */
@property (nonatomic, assign) BOOL rightAngleLinesOnly;

/**
 *  Clears all paths from the drawing, giving a blank slate.
 *
 *  @note Call clearDrawing or clearAll in JotViewController
 *  to trigger this method.
 */
- (void)clearDrawing;

- (BOOL)canUndo;

/**
 *  Undo the last paths, from the last touchBegan event
 *
 *  @note Call undoDrawing in JotViewController
 *  to trigger this method.
 */
- (void)undo;

/**
 *  Redo the last undoed paths
 *
 *  @note Call redoDrawing in JotViewController
 *  to trigger this method.
 */
- (void)redo;

/**
 *  Refreshes the drawing, for instance after a canvas size change
 */
- (void)refreshBitmap;

/**
 *  Tells the JotDrawView to handle a touchesBegan event.
 *
 *  @param touchPoint The point in this view's coordinate
 *  system where the touch began.
 *
 *  @note This method is triggered by the JotDrawController's
 *  touchesBegan event.
 */
- (void)drawTouchBeganAtPoint:(CGPoint)touchPoint;

/**
 *  Tells the JotDrawView to handle a touchesMoved event.
 *
 *  @param touchPoint The point in this view's coordinate
 *  system where the touch moved.
 *
 *  @note This method is triggered by the JotDrawController's
 *  touchesMoved event.
 */
- (void)drawTouchMovedToPoint:(CGPoint)touchPoint;

/**
 *  Tells the JotDrawView to handle a touchesEnded event.
 *
 *  @param touchPoint The point in this view's coordinate
 *  system where the touch ended.
 *
 *  @note This method is triggered by the JotDrawController's
 *  touchesEnded event.
 */
- (void)drawTouchEndedAtPoint:(CGPoint)touchPoint;


/**
 *  The three methods that handle draw evens for lines
 *
 *  @param touchPoint The point in this view's coordinate
 *  system where the touch began/moved/ended.
 *
 *  @note This method is triggered by JotDrawController's
 *  touch events.
 */
- (void)drawLineBeganAtPoint:(CGPoint)touchPoint;
- (void)drawLineMovedToPoint:(CGPoint)touchPoint;
- (void)drawLineEndedAtPoint:(CGPoint)touchPoint;

/**
 *  Initialize the view with an UImageView to be drawn on.
 *
 *  @param imageView The UIImageView containing the background image to be drawn on.
 *  @note This method only needs to be called if the image being drawn on has been scaled.
 *  The UIImageView is needed to calculate the proper scaling for rendering.
 */
- (void)setupForImageView:(UIImageView *)imageView;

/**
 *  Overlays the drawing on the image passed in on setup, rendering
 *  the drawing at the full resolution of the image.
 *  The canvas position and the image share the same top left corner and
 *  the resulting image size is the maximum size beetween canvas size and image
 *  size.
 *
 *  @return An image of the rendered drawing on the background image.
 *
 *  @note Use this method after the setup.
 */
- (UIImage *)drawOnImage;

/**
 *  Overlays drawing onto the given background image.
 *  The canvas position and the image share the same top left corner and
 *  the resulting image size is the maximum size beetween canvas size and image
 *  size.
 *
 *  @return An image of the rendered drawing on the background image.
 *
 *  @note Call drawOnImage: in JotViewController
 *  to trigger this method. This method does not account for scaling
 */
- (UIImage *)drawOnImage:(UIImage *)image;

/**
 *  Renders the drawing at full resolution for the given size.
 *
 *  @param size The size of the image to return.
 *
 *  @return An image of the rendered drawing.
 *
 *  @note Call renderWithSize: in JotViewController
 *  to trigger this method.
 */
- (UIImage *)renderDrawingWithSize:(CGSize)size;

#pragma mark - Serialization

/**
 *  Convert the draw view into a dictionary
 *
 *  @return the object, as a NSDictionary
 */
- (NSDictionary*)serialize;

/**
 *  Unserialize the draw view from a dictionary
 *
 *  @param the NSDictionary representing the object
 */
- (void)unserialize:(NSDictionary*)dictionary;

@end
