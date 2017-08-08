//
//  JotGridHelperView.m
//  DrawModules
//
//  Created by Martin Prot on 06/10/2015.
//  Copyright © 2015 appricot. All rights reserved.
//

#import "JotGridHelperView.h"

@implementation JotGridHelperView

- (void)setGridSize:(NSUInteger)gridSize {
	self.opaque = NO;
	if (_gridSize != gridSize) {
		_gridSize = gridSize;
		[self setNeedsDisplay];
	}
}

- (void)drawRect:(CGRect)rect {
	[super drawRect:rect];
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextClearRect(context, rect);
	if (_gridSize > 1) {
		[[UIColor lightGrayColor] setStroke];
		CGContextSetLineWidth(context, 1);
		CGFloat lengths[] = {2, 2};
		CGContextSetLineDash(context, 0, lengths, 2);
		
		for (int i=0; i<self.bounds.size.width/_gridSize; i++) {
			CGContextMoveToPoint(context, i*_gridSize, 0);
			CGContextAddLineToPoint(context, i*_gridSize, self.bounds.size.height);
		}
		for (int i=0; i<self.bounds.size.height/_gridSize; i++) {
			CGContextMoveToPoint(context, 0, i*_gridSize);
			CGContextAddLineToPoint(context, self.bounds.size.width, i*_gridSize);
		}
		CGContextStrokePath(context);
	}
}

@end
