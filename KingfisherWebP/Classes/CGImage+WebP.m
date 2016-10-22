//
//  CGImage+WebP.m
//  Pods
//
//  Created by yeatse on 2016/10/20.
//
//

#import "CGImage+WebP.h"
#import "webp/decode.h"
#import "webp/encode.h"

CGImageRef __nullable CGImageCreateWithWebPData(CFDataRef __nonnull webpData)
{
    // get features
    WebPBitstreamFeatures features;
    if (WebPGetFeatures(CFDataGetBytePtr(webpData), CFDataGetLength(webpData), &features) != VP8_STATUS_OK) {
        return NULL;
    }
    
    int width = 0, height = 0;
    uint8_t* buffer = NULL;
    if (features.has_alpha) {
        buffer = WebPDecodeRGBA(CFDataGetBytePtr(webpData), CFDataGetLength(webpData), &width, &height);
    } else {
        buffer = WebPDecodeRGB(CFDataGetBytePtr(webpData), CFDataGetLength(webpData), &width, &height);
    }
    
    size_t bytesPerPixel = features.has_alpha ? 4 : 3;
    
    // create image provider on output of webp decoder
    CFDataRef decodedData = CFDataCreate(kCFAllocatorDefault, buffer, width * height * bytesPerPixel);
    WebPFree(buffer);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(decodedData);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = features.has_alpha ? kCGImageAlphaLast : kCGImageAlphaNone;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef image = CGImageCreate(width, height, 8, bytesPerPixel * 8, width * bytesPerPixel, colorSpace, bitmapInfo, provider, NULL, NO, renderingIntent);
    
    // clean up
    CGColorSpaceRelease(colorSpace); 
    CGDataProviderRelease(provider);
    CFRelease(decodedData);
    
    return image;
}


CFDataRef WebPRepresentationDataCreateWithImage(CGImageRef image)
{
    // Create an rgba bitmap context
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast;
    size_t bytesPerPixel = 4;
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * bytesPerPixel, colorSpace, bitmapInfo);
    
    // Render image into the context
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    
    UInt8* bitmapData = (UInt8*)CGBitmapContextGetData(context);
    
    // Get real rgb from premultiplied one
    for (int i = 0; i < width * height * bytesPerPixel; i += bytesPerPixel) {
        UInt8 alpha = bitmapData[i + 3];
        if (alpha == 0 || alpha == UINT8_MAX) {
            continue;
        }
        bitmapData[i] = (UInt8)round(bitmapData[i] * 255.0 / alpha);
        bitmapData[i + 1] = (UInt8)round(bitmapData[i] * 255.0 / alpha);
        bitmapData[i + 2] = (UInt8)round(bitmapData[i] * 255.0 / alpha);
    }
    
    // Encode
    uint8_t *output;
    size_t outputSize = WebPEncodeLosslessRGBA(bitmapData, width, height, width * bytesPerPixel, &output);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, output, outputSize);
    WebPFree(output);
    
    return data;
}
