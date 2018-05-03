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
#import "webp/demux.h"
#import "webp/mux.h"

#pragma mark - Helper Functions

FOUNDATION_STATIC_INLINE void WebPFreeInfoReleaseDataCallback(void *info, const void *data, size_t size) {
    if (info) {
        free(info);
    }
}

FOUNDATION_STATIC_INLINE CGColorSpaceRef WebPColorSpaceForDeviceRGB() {
    static CGColorSpaceRef colorSpace;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colorSpace = CGColorSpaceCreateDeviceRGB();
    });
    return colorSpace;
}

#pragma mark - Still Images

CGImageRef WebPImageCreateWithData(CFDataRef webpData) {
    WebPData webp_data;
    WebPDataInit(&webp_data);
    webp_data.bytes = CFDataGetBytePtr(webpData);
    webp_data.size = CFDataGetLength(webpData);
    
    WebPAnimDecoderOptions dec_options;
    WebPAnimDecoderOptionsInit(&dec_options);
    dec_options.use_threads = 1;
    dec_options.color_mode = MODE_rgbA;
    
    WebPAnimDecoder *dec = WebPAnimDecoderNew(&webp_data, &dec_options);
    if (!dec) {
        return NULL;
    }
    
    WebPAnimInfo anim_info;
    uint8_t *buf;
    int timestamp;
    if (!WebPAnimDecoderGetInfo(dec, &anim_info) || !WebPAnimDecoderGetNext(dec, &buf, &timestamp)) {
        WebPAnimDecoderDelete(dec);
        return NULL;
    }
    
    const size_t bufSize = anim_info.canvas_width * 4 * anim_info.canvas_height;
    void *bufCopy = malloc(bufSize);
    memcpy(bufCopy, buf, bufSize);
    WebPAnimDecoderDelete(dec);
        
    CGDataProviderRef provider = CGDataProviderCreateWithData(bufCopy, bufCopy, bufSize, WebPFreeInfoReleaseDataCallback);
    CGImageRef image = CGImageCreate(anim_info.canvas_width, anim_info.canvas_height, 8, 32, anim_info.canvas_width * 4, WebPColorSpaceForDeviceRGB(), (CGBitmapInfo)kCGImageAlphaPremultipliedLast, provider, NULL, false, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    
    return image;
}

CFDataRef WebPDataCreateWithImage(CGImageRef image) {
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

#pragma mark - Animated Images

const CFStringRef kWebPAnimatedImageDuration = CFSTR("kWebPAnimatedImageDuration");
const CFStringRef kWebPAnimatedImageLoopCount = CFSTR("kWebPAnimatedImageLoopCount");
const CFStringRef kWebPAnimatedImageFrames = CFSTR("kWebPAnimatedImageFrames");

NSUInteger WebPImageFrameCountGetFromData(CFDataRef webpData) {
    WebPData webp_data;
    WebPDataInit(&webp_data);
    webp_data.bytes = CFDataGetBytePtr(webpData);
    webp_data.size = CFDataGetLength(webpData);
    
    WebPDemuxer *dmux = WebPDemux(&webp_data);
    if (!dmux) {
        return 0;
    }
    
    NSUInteger frameCount = WebPDemuxGetI(dmux, WEBP_FF_FRAME_COUNT);
    WebPDemuxDelete(dmux);
    
    return frameCount;
}

CFDictionaryRef WebPAnimatedImageInfoCreateWithData(CFDataRef webpData) {
    WebPData webp_data;
    WebPDataInit(&webp_data);
    webp_data.bytes = CFDataGetBytePtr(webpData);
    webp_data.size = CFDataGetLength(webpData);
    
    WebPAnimDecoderOptions dec_options;
    WebPAnimDecoderOptionsInit(&dec_options);
    dec_options.use_threads = 1;
    dec_options.color_mode = MODE_rgbA;
    
    WebPAnimDecoder *dec = WebPAnimDecoderNew(&webp_data, &dec_options);
    if (!dec) {
        return NULL;
    }
    
    WebPAnimInfo anim_info;
    if (!WebPAnimDecoderGetInfo(dec, &anim_info)) {
        WebPAnimDecoderDelete(dec);
        return NULL;
    }
    
    CFMutableDictionaryRef imageInfo = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    CFMutableArrayRef imageFrames = CFArrayCreateMutable(kCFAllocatorDefault, anim_info.frame_count, &kCFTypeArrayCallBacks);
    
    int duration = 0;
    while (WebPAnimDecoderHasMoreFrames(dec)) {
        uint8_t *buf;
        
        if (!WebPAnimDecoderGetNext(dec, &buf, &duration)) {
            break;
        }
        
        const size_t bufSize = anim_info.canvas_width * 4 * anim_info.canvas_height;
        void *bufCopy = malloc(bufSize);
        memcpy(bufCopy, buf, bufSize);
        
        CGDataProviderRef provider = CGDataProviderCreateWithData(bufCopy, bufCopy, bufSize, WebPFreeInfoReleaseDataCallback);
        CGImageRef image = CGImageCreate(anim_info.canvas_width, anim_info.canvas_height, 8, 32, anim_info.canvas_width * 4, WebPColorSpaceForDeviceRGB(), (CGBitmapInfo)kCGImageAlphaPremultipliedLast, provider, NULL, false, kCGRenderingIntentDefault);
        CFArrayAppendValue(imageFrames, image);
        CGImageRelease(image);
        CGDataProviderRelease(provider);
    }
    
    // add last frame's duration
    const WebPDemuxer *dmux = WebPAnimDecoderGetDemuxer(dec);
    WebPIterator iter;
    if (WebPDemuxGetFrame(dmux, 0, &iter)) {
        duration += iter.duration;
        WebPDemuxReleaseIterator(&iter);
    }
    WebPAnimDecoderDelete(dec);
    
    CFDictionarySetValue(imageInfo, kWebPAnimatedImageFrames, imageFrames);
    CFRelease(imageFrames);
    
    CFNumberRef loopCount = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &anim_info.loop_count);
    CFDictionarySetValue(imageInfo, kWebPAnimatedImageLoopCount, loopCount);
    CFRelease(loopCount);
    
    double durationInSec = ((double)duration) / 1000;
    CFNumberRef durationRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &durationInSec);
    CFDictionarySetValue(imageInfo, kWebPAnimatedImageDuration, durationRef);
    CFRelease(durationRef);
    
    return imageInfo;
}

FOUNDATION_STATIC_INLINE int WebPPictureImportCGImage(WebPPicture *picture, CGImageRef image) {
    // Create an rgba bitmap context
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    size_t bytesPerPixel = 4;
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * bytesPerPixel, WebPColorSpaceForDeviceRGB(), bitmapInfo);
    
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
    
    picture->width = (int)width;
    picture->height = (int)height;
    picture->use_argb = 1;

    int result = WebPPictureImportRGBA(picture, CGBitmapContextGetData(context), (int)(width * bytesPerPixel));
    CGContextRelease(context);
    return result;
}

CFDataRef WebPDataCreateWithAnimatedImageInfo(CFDictionaryRef imageInfo) {
    CFNumberRef loopCount = CFDictionaryGetValue(imageInfo, kWebPAnimatedImageLoopCount);
    CFNumberRef durationRef = CFDictionaryGetValue(imageInfo, kWebPAnimatedImageDuration);
    CFArrayRef imageFrames = CFDictionaryGetValue(imageInfo, kWebPAnimatedImageFrames);
    
    if (!imageFrames || CFArrayGetCount(imageFrames) < 1) {
        return NULL;
    }
    
    WebPAnimEncoderOptions enc_options;
    WebPAnimEncoderOptionsInit(&enc_options);
    if (loopCount) {
        CFNumberGetValue(loopCount, kCFNumberSInt32Type, &enc_options.anim_params.loop_count);
    }
    
    CGImageRef firstImage = (CGImageRef)CFArrayGetValueAtIndex(imageFrames, 0);
    WebPAnimEncoder *enc = WebPAnimEncoderNew((int)CGImageGetWidth(firstImage), (int)CGImageGetHeight(firstImage), &enc_options);
    if (!enc) {
        return NULL;
    }
    
    int frameDurationInMilliSec = 100;
    if (durationRef) {
        double totalDurationInSec;
        CFNumberGetValue(durationRef, kCFNumberDoubleType, &totalDurationInSec);
        frameDurationInMilliSec = (int)(totalDurationInSec * 1000 / CFArrayGetCount(imageFrames));
    }
    
    for (CFIndex i = 0; i < CFArrayGetCount(imageFrames); i ++) {
        WebPPicture frame;
        WebPPictureInit(&frame);
        if (WebPPictureImportCGImage(&frame, (CGImageRef)CFArrayGetValueAtIndex(imageFrames, i))) {
            WebPConfig config;
            WebPConfigInit(&config);
            config.lossless = 1;
            config.quality = 0;
            config.method = 0;
            WebPAnimEncoderAdd(enc, &frame, (int)(frameDurationInMilliSec * i), &config);
        }
        WebPPictureFree(&frame);
    }
    WebPAnimEncoderAdd(enc, NULL, (int)(frameDurationInMilliSec * CFArrayGetCount(imageFrames)), NULL);
    
    WebPData webp_data;
    WebPDataInit(&webp_data);
    WebPAnimEncoderAssemble(enc, &webp_data);
    WebPAnimEncoderDelete(enc);
    
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, webp_data.bytes, webp_data.size);
    WebPDataClear(&webp_data);
    
    return data;
}
