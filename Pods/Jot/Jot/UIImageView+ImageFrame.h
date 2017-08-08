//
//  UIImageView+ImageFrame.h
//  Pods
//
//  Created by Ritchie on 2016-06-28.
//
//

#import <UIKit/UIKit.h>

@interface UIImageView (ImageFrame)

- (CGRect)frameForImage;
- (CGFloat)scaleFactorForImage;

@end
