//
//  OpenCVWrapper.h
//  ChopShopOpenSource
//
//  Created by Cory Liu on 2021-06-08.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject
//Apply grabcut with source image and mask image. Returns a dictionary with result image and resulting contours.
+(NSDictionary *)applyGrabCutWithDownSample:(BOOL)downsample
                                sourceImage:(UIImage *)src
                                  maskImage:(UIImage*)mask;
@end

NS_ASSUME_NONNULL_END
