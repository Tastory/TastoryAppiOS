//
//  JotTouchLine.h
//  DrawModules
//
//  Created by Martin Prot on 06/10/2015.
//  Copyright © 2015 appricot. All rights reserved.
//

#import "JotTouchObject.h"

@interface JotTouchLine : JotTouchObject

+ (instancetype)withStartPoint:(CGPoint)a;

/**
 *  The CGPoint where the line starts
 */
@property (nonatomic, assign) CGPoint pointA;

/**
 *  The CGPoint where the line ends
 */
@property (nonatomic, assign) CGPoint pointB;

/**
 *  The stroke width to use for drawing the line.
 */
@property (nonatomic, assign) CGFloat strokeWidth;

/**
 *  YES if the line should be dashed
 */
@property (nonatomic, assign) BOOL dashed;

@end
