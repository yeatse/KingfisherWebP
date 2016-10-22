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

static void ReleaseWebPConfig(void *info, const void *data, size_t size)
{
    WebPDecoderConfig* config = (WebPDecoderConfig*)info;
    WebPFreeDecBuffer(&config->output);
    free(config);
}

CGImageRef __nullable CGImageCreateWithWebPData(CFDataRef __nonnull webpData)
{
    WebPDecoderConfig* config = (WebPDecoderConfig*)malloc(sizeof(WebPDecoderConfig));
    if (!WebPInitDecoderConfig(config)) {
        free(config);
        return NULL;
    }
    
    if (WebPGetFeatures(CFDataGetBytePtr(webpData), CFDataGetLength(webpData), &config->input) != VP8_STATUS_OK) {
        free(config);
        return NULL;
    }
    
    config->options.use_threads = 1;
    config->output.colorspace = MODE_rgbA;
    
    if (WebPDecode(CFDataGetBytePtr(webpData), CFDataGetLength(webpData), config) != VP8_STATUS_OK) {
        free(config);
        return NULL;
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(config, config->output.u.RGBA.rgba, config->output.u.RGBA.size, ReleaseWebPConfig);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef image = CGImageCreate(config->input.width, config->input.height, 8, 32, config->output.u.RGBA.stride, colorSpace, bitmapInfo, provider, NULL, NO, renderingIntent);
    
    // clean up
    CGColorSpaceRelease(colorSpace); 
    CGDataProviderRelease(provider);
    
    return image;
}


CFDataRef WebPRepresentationDataCreateWithImage(CGImageRef image)
{
    // Create an rgba bitmap context
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    size_t bytesPerPixel = 4;
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * bytesPerPixel, colorSpace, bitmapInfo);
    
    // Render image into the context
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    
    UInt8* bitmapData = (UInt8*)CGBitmapContextGetData(context);
    size_t pixelCount = width * height;
    
    // Get real rgb from premultiplied ones
    for (; pixelCount-- > 0; bitmapData += 4) {
        UInt8 alpha = bitmapData[3];
        if (alpha != UINT8_MAX && alpha != 0) {
            bitmapData[0] = (UInt8)(((unsigned)bitmapData[0] * UINT8_MAX + alpha / 2) / alpha);
            bitmapData[1] = (UInt8)(((unsigned)bitmapData[1] * UINT8_MAX + alpha / 2) / alpha);
            bitmapData[2] = (UInt8)(((unsigned)bitmapData[2] * UINT8_MAX + alpha / 2) / alpha);
        }
    }
    
    // Encode
    uint8_t *output;
    size_t outputSize = WebPEncodeLosslessRGBA(CGBitmapContextGetData(context), (int)width, (int)height, (int)(width * bytesPerPixel), &output);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, output, outputSize);
    WebPFree(output);
    
    return data;
}
