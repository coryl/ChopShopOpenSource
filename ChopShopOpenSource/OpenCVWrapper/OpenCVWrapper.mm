//
//  OpenCVWrapper.mm
//  ChopShopOpenSource
//
//  Created by Cory Liu on 2021-06-08.
//
#import "OpenCVWrapper.h"
#import <opencv2/opencv.hpp>
#import <UIKit/UIKit.h>


@implementation OpenCVWrapper

+(NSDictionary *)applyGrabCutWithDownSample:(BOOL)downsample sourceImage:(UIImage*)src maskImage:(UIImage*)mask{
    if (!src || !mask) {
        return nil; //safety check
    }
    
    if(downsample){
        NSLog(@"Begin LQ grabcut.");
    } else {
        NSLog(@"Begin HQ grabcut.");
    }
    clock_t tStart = clock();
    cv::Mat srcImage = [OpenCVWrapper cvMatFromUIImage:src];
    cv::Mat maskMat = [OpenCVWrapper cvMatFromUIImage:mask];
    cv::Mat image;
    
    if (downsample) {
        //Low quality
        NSLog(@"srcimage cols is %i, width %i", srcImage.cols, srcImage.rows);
        NSLog(@"maskMat cols is %i, rows %i", maskMat.cols, maskMat.rows);
        cv::pyrDown(srcImage, image, cv::Size(srcImage.cols/2, srcImage.rows/2));
        cv::pyrDown(maskMat, maskMat, cv::Size(srcImage.cols/2, srcImage.rows/2));
    } else {
        //High quality
        image = srcImage;
        NSLog(@"srcimage cols is %i, width %i", srcImage.cols, srcImage.rows);
        NSLog(@"maskMat cols is %i, rows %i", maskMat.cols, maskMat.rows);
    }
    cv::cvtColor(image, image, cv::COLOR_RGBA2BGR);
    cv::cvtColor(maskMat, maskMat, cv::COLOR_RGBA2BGR);
    
    //First, get a black and white mask matrix for red and green. Each pixel will be either 0 or (red/green RGB value):
    cv::Mat onlyRedMask(maskMat.size(), CV_8UC1);
    cv::inRange(maskMat, cv::Scalar(100,0,0), cv::Scalar(255,0,0), onlyRedMask);
    
    cv::Mat onlyGreenMask(maskMat.size(), CV_8UC1);
    cv::inRange(maskMat, cv::Scalar(0,100,0), cv::Scalar(0,255,0), onlyGreenMask);
    
    //Need a green mask to continue: return otherwise.
    if(cv::countNonZero(onlyGreenMask) < 1){
        return nil;
    }
    
    //Threshold the mask, so that 0 values remain 0, and everything else is either GC_PR_BGD (2) or GC_PR_FGD (3) respectively
    cv::Mat redMaskForGrabcut, greenMaskForGrabcut;
    int tempValue = 7;
    cv::threshold(onlyRedMask, redMaskForGrabcut, 0, tempValue, cv::THRESH_BINARY); //I'm using 7 as a temporary holder. I want to set it as cv::GC_BGD, but that value is 0, so the array will just be full of 0's. I'll replace the 7's after.
    cv::threshold(onlyGreenMask, greenMaskForGrabcut, 0, cv::GC_FGD, cv::THRESH_BINARY);
    
    //Combine the red/green masks. Each pixel is now set to 0, GC_FGD, or tempValue (GC_BGD):
    cv::Mat combinedMask(maskMat.size(), CV_8UC1);
    cv::bitwise_or(greenMaskForGrabcut, redMaskForGrabcut, combinedMask);
    
    //combinedMask has a lot of 0's, which represent GC_BGD, which is too strong a declaration for grabCut. Set them to GC_PR_BGD (2):
    cv::Mat zeromask;
    cv::inRange(combinedMask, 0, 0, zeromask); //find and mark all the zeroes into a zeromask
    combinedMask.setTo(cv::GC_PR_BGD, zeromask);   //change those zeroes to 2's
    
    //Replace 7's with 0's, which is just restoring the red mask (GC_BGD) values.
    cv::Mat sevenmask;
    cv::inRange(combinedMask, tempValue, tempValue, sevenmask);
    combinedMask.setTo(cv::GC_BGD, sevenmask);
    
    //Run grabcut
    cv::Mat bgdmodel, fgdmodel;
    int iterations = 5;
    cv::grabCut(image, combinedMask, cv::Rect(), bgdmodel,fgdmodel, iterations, cv::GC_INIT_WITH_MASK);
    
    //Parse results: only need GC_FGD (1) and GC_PR_FGD (3) flags from the resulting combinedMask
    cv::Mat result = (combinedMask == cv::GC_FGD) | (combinedMask == cv::GC_PR_FGD);

    /* POLISH THE RESULT MASK:
     'result' gives us the resulting mask which contains either GC_FGD and GC_PR_FGD.
     However, sometimes this will include pixels outside of the user's selection area,
     just because they match colors (based on grabcut).
     
     We'll do a contour analysis on the 'result' mask to find separate bodies of pixels.
     If the user marked any pixels in that body with GC_FGD, we'll know to keep that body.
     */
    
    std::vector<cv::Vec4i> hierarchy;
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(result, contours, hierarchy, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE, cv::Point(0, 0));

    //Go through hierarchy, add all children contours to a children array:
    //Potential inefficiency: currently all I do is get an array of ALL contours with a parent. Might be good to check whether that child falls within the marked contour.
    std::vector<std::vector<cv::Point>> children;
    for(int i = 0; i < hierarchy.size(); i++){
        int parent = hierarchy[i][3];
        if (parent >= 0) {
            children.push_back(contours[i]);
        }
    }

    //Find contours explicitly marked as FGD or BGD:
    std::vector<std::vector<cv::Point>> markedFGDContours = [OpenCVWrapper findMarkedContoursFrom:contours withGrabcutMask:combinedMask flag: cv::GC_FGD];

    std::vector<std::vector<cv::Point>> markedBGDContours = [OpenCVWrapper findMarkedContoursFrom:children withGrabcutMask:combinedMask flag:cv::GC_BGD];

    //Create masks for each contour by filling them with white:
    cv::Mat fgdMask(image.size(), CV_8UC1, cv::Scalar(0));
    for (std::vector<cv::Point> contour : markedFGDContours){
        cv::Scalar color = CV_RGB(255, 255, 255);
        drawContours(fgdMask, std::vector<std::vector<cv::Point>>(1,contour), -1, color, -1, cv::LINE_AA);
    }

    cv::Mat bgdMask(image.size(), CV_8UC1, cv::Scalar(0));
    for (std::vector<cv::Point> contour : markedBGDContours){
        cv::Scalar color = CV_RGB(255, 255, 255);
        drawContours(bgdMask, std::vector<std::vector<cv::Point>>(1,contour), -1, color, -1, cv::LINE_AA);
    }
    //For bgdMask (contours highlighted as do not keep), invert the mask so its black. Use bitwise_and operator with fgdMask to merge them:
    cv::bitwise_not(bgdMask, bgdMask);
    cv::bitwise_and(bgdMask, fgdMask, fgdMask);

    //Make sure source image has an alpha channel so final image can have transparent pixels.
    cv::cvtColor(image, image, cv::COLOR_BGR2RGBA);
    cv::Mat contoursMat;
    if(downsample){
        /*Upsample the mask, then resize it to equal the original. This is because its dimensions
         may have been rounded to be even on downsample. */
        cv::pyrUp(fgdMask, fgdMask, cv::Size(image.cols*2, image.rows*2));
        cv::resize(fgdMask, fgdMask, cv::Size(srcImage.cols, srcImage.rows));
        //Upsample the contours image:
        contoursMat = [self createImageOfContours:markedFGDContours size:cv::Size(image.cols*2, image.rows*2) downsampled:YES];
        cv::pyrUp(contoursMat, contoursMat, cv::Size(image.cols*2, image.rows*2));
    } else {
        contoursMat = [self createImageOfContours:markedFGDContours size:cv::Size(image.cols, image.rows) downsampled:NO];
    }

    //Build final image:
    cv::Mat foreground(srcImage.size(),CV_8UC4, cv::Scalar(0,0,0,0));
    srcImage.copyTo(foreground, fgdMask);
        
    UIImage *finalImage = [self UIImageFromCVMat:foreground];
    UIImage *contourImage = [self UIImageFromCVMat:contoursMat];
    
    NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:finalImage, @"finalImage", contourImage, @"contourImage", nil];
    if(downsample){
        NSLog(@"Low quality process:");
    } else {
        NSLog(@"High quality process:");
    }
    printf("Grabcut method processing time: %f s\n", (clock() - tStart)/(double)CLOCKS_PER_SEC);
    return dictionary;
}

+(std::vector<std::vector<cv::Point>>)findMarkedContoursFrom:(std::vector<std::vector<cv::Point>>)contours withGrabcutMask:(cv::Mat)mask flag:(cv::GrabCutClasses)flag{
    
    std::vector<std::vector<cv::Point>> markedContours;
    for (std::vector<cv::Point> contour : contours){
        cv::Rect boundingRect = cv::boundingRect(contour);
        if ([self boundingRect:boundingRect containsFlag:flag inMask:mask]) {
            markedContours.push_back(contour);
        }
    }
    
    return markedContours;
}

+(BOOL)boundingRect:(cv::Rect)boundingRect containsFlag:(cv::GrabCutClasses)flag inMask:(cv::Mat)mat{
    int yLimit = boundingRect.y + boundingRect.height;
    int xLimit = boundingRect.x + boundingRect.width;
    for(int i = boundingRect.y; i < yLimit; i++){
        for(int j = boundingRect.x; j < xLimit; j++){
            uchar maskFlag = mat.at<uchar>(i,j);
            //NSLog(@"value of %d,%d is %d",i,j,maskFlag);
            if(maskFlag == flag){
                return YES;
                // printf("%d ", combinedMask.at<uchar>(i,j));
            }
        }
    }
    
    return NO;
}

+(cv::Mat)createImageOfContours:(std::vector<std::vector<cv::Point>>)markedContours size:(cv::Size)dimensions downsampled:(BOOL)downsampled{
    //Draw some nifty contours on the canvas image to show what they selected:
    CGFloat width = dimensions.width;
    CGFloat height = dimensions.height;
    if(downsampled){
        height /= 2;
        width /= 2;
    }
    cv::Mat contoursOverlay(height, width, CV_8UC4, cv::Scalar(0,0,0,0));
    
    //Do a bit of contour smoothing:
    std::vector<std::vector<cv::Point>> curvedContours;
    for (std::vector<cv::Point> contour : markedContours){
        std::vector<cv::Point> curve;
        cv::approxPolyDP(contour, curve, 1, NO);
        curvedContours.push_back(curve);
    }
    
    //Draw the contours, then run some erosion + blurring on them to help smoothen:
    cv::drawContours(contoursOverlay, curvedContours, -1, cv::Scalar(230, 230, 5, 255), (downsampled ? 2 : 3), 8);
    /*
     cv::bitwise_not(contoursOverlay, contoursOverlay);
     int erosion_size = 2;
     cv::Mat element = getStructuringElement( cv::MORPH_RECT,
     cv::Size( 2*erosion_size + 1, 2*erosion_size+1 ),
     cv::Point( erosion_size, erosion_size ) );
     cv::erode(contoursOverlay, contoursOverlay, element);
     cv::bitwise_not(contoursOverlay, contoursOverlay);
     */
    if(!downsampled)
        cv::GaussianBlur(contoursOverlay, contoursOverlay, cv::Size(3,3), 15, 15);
    
    return contoursOverlay;
}


/* Image Converter methods: */

+(cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = CGImageGetWidth(image.CGImage);
    CGFloat rows = CGImageGetHeight(image.CGImage);
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

+(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaLast|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

@end
