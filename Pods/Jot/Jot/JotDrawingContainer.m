//
//  JotDrawingContainer.m
//  jot
//
//  Created by Laura Skelton on 5/12/15.
//
//

#import "JotDrawingContainer.h"
#import "JotGridHelperView.h"

@interface JotDrawingContainer ()

@property (nonatomic, strong) JotGridHelperView *gridView;

@end

@implementation JotDrawingContainer

#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
	CGPoint touch = [[touches anyObject] locationInView:self];
	if ([self shouldDiscretise]) {
		touch = [self discretized:touch];
	}
    [self.delegate jotDrawingContainerTouchBeganAtPoint:touch];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesMoved:touches withEvent:event];
	CGPoint touch = [[touches anyObject] locationInView:self];
	if ([self shouldDiscretise]) {
		touch = [self discretized:touch];
	}
    [self.delegate jotDrawingContainerTouchMovedToPoint:touch];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];
	CGPoint touch = [[touches anyObject] locationInView:self];
	if ([self shouldDiscretise]) {
		touch = [self discretized:touch];
	}
	[self.delegate jotDrawingContainerTouchEndedAtPoint:touch];
}

- (BOOL)shouldDiscretise {
	return (self.discreteGridSize > 1 &&
			[self.delegate respondsToSelector:@selector(jotDrawingContainerShouldDiscretise)] &&
			[self.delegate jotDrawingContainerShouldDiscretise]);
}

- (CGPoint)discretized:(CGPoint)point {
	return CGPointMake(roundf(point.x / (float)self.discreteGridSize)*self.discreteGridSize,
					   roundf(point.y / (float)self.discreteGridSize)*self.discreteGridSize);
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark GETTERS
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (JotGridHelperView*)gridView {
	if (!_gridView) {
		_gridView = [[JotGridHelperView alloc] initWithFrame:self.bounds];
		[self addSubview:_gridView];
		[self sendSubviewToBack:_gridView];
	}
	return _gridView;
}

- (void)setDiscreteGridSize:(NSUInteger)discreteGridSize {
	if (_discreteGridSize != discreteGridSize) {
		_discreteGridSize = discreteGridSize;
		
		if (discreteGridSize > 1) {
			self.gridView.hidden = NO;
			self.gridView.gridSize = discreteGridSize;
		}
		else {
			self.gridView.hidden = YES;
		}
	}
}

@end
