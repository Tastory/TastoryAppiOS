//
//  JotTouchBezier.h
//  jot
//
//  Created by Laura Skelton on 4/30/15.
//
//

#import "JotTouchObject.h"

/**
 *  Private class to handle drawing variable-width cubic bezier paths in a JotDrawView.
 */
@interface JotTouchBezier : JotTouchObject

/**
 *  The path ref of the bezier curve
 */
@property (nonatomic, assign, readonly) CGMutablePathRef path;

/**
 *  The start point of the cubic bezier path.
 */
@property (nonatomic, assign) CGPoint startPoint;

/**
 *  The end point of the cubic bezier path.
 */
@property (nonatomic, assign) CGPoint endPoint;

/**
 *  The first control point of the cubic bezier path.
 */
@property (nonatomic, assign) CGPoint controlPoint1;

/**
 *  The second control point of the cubic bezier path.
 */
@property (nonatomic, assign) CGPoint controlPoint2;

/**
 *  The starting width of the cubic bezier path.
 */
@property (nonatomic, assign) CGFloat startWidth;

/**
 *  The ending width of the cubic bezier path.
 */
@property (nonatomic, assign) CGFloat endWidth;

/**
 *  YES if the line is a constant width, NO if variable width.
 */
@property (nonatomic, assign) BOOL constantWidth;

/**
 *  Returns an instance of JotTouchBezier with the given points
 *
 *  @param startPoint    the start point
 *  @param endPoint      the end point
 *  @param controlPoint1 the start control point
 *  @param controlPoint2 the end control point
 *
 *  @return an instance of JotTouchBezier
 */
+ (instancetype)withStartPoint:(CGPoint)startPoint endPoint:(CGPoint)endPoint controlPoint1:(CGPoint)controlPoint1 controlPoint2:(CGPoint)controlPoint2 scaleFactor:(CGFloat)scaleFactor;

@end
