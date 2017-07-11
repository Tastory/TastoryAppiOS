//
//  UIImageView+ImageFrame.m
//  Pods
//
//  Created by Ritchie on 2016-06-28.
//
//

#import "UIImageView+ImageFrame.h"

@implementation UIImageView (ImageFrame)

- (CGRect)frameForImage {
    switch (self.contentMode) {
        case UIViewContentModeScaleAspectFit:
            return [self frameForAspectFitImage];
        case UIViewContentModeScaleAspectFill:
            return [self frameForAspectFillImage];
        default:
            return CGRectZero;
    }
}

- (CGFloat)scaleFactorForImage {
    switch (self.contentMode) {
        case UIViewContentModeScaleAspectFit:
            return [self scaleFactorForAspectFit];
        case UIViewContentModeScaleAspectFill:
            return [self scaleFactorForAspectFill];
        default:
            return 0;
    }
}

- (CGRect)frameForAspectFitImage {
    CGSize imageSize = self.image.size;
    CGFloat imageScale = fminf(CGRectGetWidth(self.bounds)/imageSize.width, CGRectGetHeight(self.bounds)/imageSize.height);
    CGSize scaledImageSize = CGSizeMake(imageSize.width*imageScale, imageSize.height*imageScale);
    CGRect imageFrame = CGRectMake(roundf(0.5f*(CGRectGetWidth(self.bounds)-scaledImageSize.width)), roundf(0.5f*(CGRectGetHeight(self.bounds)-scaledImageSize.height)), roundf(scaledImageSize.width), roundf(scaledImageSize.height));
    
    return imageFrame;
}

- (CGRect)frameForAspectFillImage {
    if (!self.image) {
        return CGRectZero;
    }
    
    CGSize imageSize = self.image.size;
    CGSize containerSize = self.bounds.size;
    CGFloat scale = [self scaleFactorForAspectFill];
    CGSize scaledImageSize = CGSizeMake(imageSize.width / scale,
                                        imageSize.height / scale);
    CGPoint offset = CGPointMake(containerSize.width - scaledImageSize.width,
                                 containerSize.height - scaledImageSize.height);
    return CGRectMake(offset.x / 2.f, offset.y / 2.f, scaledImageSize.width, scaledImageSize.height);
}

- (CGFloat)scaleFactorForAspectFit {
    CGSize imageSize = self.image.size;
    return 1 / fminf(CGRectGetWidth(self.bounds)/imageSize.width, CGRectGetHeight(self.bounds)/imageSize.height);
}

- (CGFloat)scaleFactorForAspectFill {
    CGFloat heightRatio = self.image.size.height / self.bounds.size.height;
    CGFloat widthRatio = self.image.size.width / self.bounds.size.width;
    
    CGFloat scale = heightRatio < widthRatio ? heightRatio : widthRatio;
    return scale;
}

@end
