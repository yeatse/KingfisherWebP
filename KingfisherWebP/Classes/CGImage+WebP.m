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
    
    size_t components = features.has_alpha ? 4 : 3;
    
    // create image provider on output of webp decoder
    CFDataRef decodedData = CFDataCreate(kCFAllocatorDefault, buffer, width * height * components);
    WebPFree(buffer);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(decodedData);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = features.has_alpha ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNone;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef image = CGImageCreate(width, height, 8, components * 8, width * components, colorSpace, bitmapInfo, provider, NULL, NO, renderingIntent);
    
    // clean up
    CGColorSpaceRelease(colorSpace); 
    CGDataProviderRelease(provider);
    CFRelease(decodedData);
    
    return image;
}


CFDataRef WebPRepresentationDataCreateWithImage(CGImageRef image)
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image);
    if (CGColorSpaceGetModel(colorSpace) != kCGColorSpaceModelRGB) {
        return NULL;
    }
    
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(image);
    if (alphaInfo != kCGImageAlphaNone && alphaInfo != kCGImageAlphaPremultipliedLast) {
        return NULL;
    }
    
    CGDataProviderRef dataProvider = CGImageGetDataProvider(image);
    CFDataRef imageData = CGDataProviderCopyData(dataProvider);
    const UInt8 *rawData = CFDataGetBytePtr(imageData);
    
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    size_t stride = CGImageGetBytesPerRow(image);
    
    uint8_t *output;
    size_t outputSize;
    if (alphaInfo == kCGImageAlphaNone) {
        outputSize = WebPEncodeLosslessRGB(rawData, width, height, stride, &output);
    } else {
        outputSize = WebPEncodeLosslessRGBA(rawData, width, height, stride, &output);
    }
    CFRelease(imageData);
    
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, output, outputSize);
    WebPFree(*output);
    
    return data;
}
