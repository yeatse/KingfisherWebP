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

static void FreeWebPDecoderConfig(WebPDecoderConfig* config)
{
    WebPFreeDecBuffer(&(config->output));
    free(config);
}

// Callback function of CoreGraphics to free underlying memory
static void FreeImageData(void *info, const void *data, size_t size)
{
    if(info != NULL) {
        FreeWebPDecoderConfig((WebPDecoderConfig *) info);
    } else {
        free((void *)data);
    }
}

CGImageRef __nullable CGImageCreateWithWebPData(CFDataRef __nonnull webpData)
{
    int width = 0, height = 0;
    if (!WebPGetInfo(CFDataGetBytePtr(webpData), CFDataGetLength(webpData), &width, &height)) {
        return NULL;
    }
    
    // Configure decoder
    WebPDecoderConfig *config = malloc(sizeof(WebPDecoderConfig));
    if (!WebPInitDecoderConfig(config)) {
        FreeWebPDecoderConfig(config);
        return NULL;
    }
    
#if defined(TARGET_OS_IPHONE) || defined(TARGET_IPHONE_SIMULATOR)
    // speed on iphone
    config->options.no_fancy_upsampling = 1;
#else
    // quality on mac
    config->options.no_fancy_upsampling = 0;
#endif
    
    config->options.bypass_filtering = 0;
    config->options.use_threads = 1;
    config->output.colorspace = config->input.has_alpha ? MODE_rgbA : MODE_RGB;
    
    // decode image
    if (WebPDecode(CFDataGetBytePtr(webpData), CFDataGetLength(webpData), config) != VP8_STATUS_OK) {
        FreeWebPDecoderConfig(config);
        return NULL;
    }
    
    // create image provider on output of webp decoder
    CGDataProviderRef provider = CGDataProviderCreateWithData(config, config->output.u.RGBA.rgba, config->output.u.RGBA.size, FreeImageData);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = config->input.has_alpha ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNone;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    size_t components = config->input.has_alpha ? 4 : 3;
    
    CGImageRef imageRef = CGImageCreate(width, height, 8, components * 8, config->output.u.RGBA.stride, colorSpace, bitmapInfo, provider, NULL, NO, renderingIntent);
    
    // clean up
    CGColorSpaceRelease(colorSpace); 
    CGDataProviderRelease(provider);
    
    return imageRef;
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
    
    CFDataRef data = CFDataCreate(CFAllocatorGetDefault(), output, outputSize);
    WebPFree(*output);
    
    return data;
}
