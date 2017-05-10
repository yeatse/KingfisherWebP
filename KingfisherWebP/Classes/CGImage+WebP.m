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

#pragma mark - Helper Functions

/// Returns byte-aligned size.
static inline size_t ImageByteAlign(size_t size, size_t alignment) {
    return ((size + (alignment - 1)) / alignment) * alignment;
}

static void ReleaseDataCallback(void *info, const void *data, size_t size) {
    if (info) free(info);
}

CGColorSpaceRef GetDeviceRGB_CGColorSpace() {
    static CGColorSpaceRef space;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        space = CGColorSpaceCreateDeviceRGB();
    });
    return space;
}

#pragma mark - Decode Functions

NSUInteger WebPDataGetFrameCount(CFDataRef __nullable webpData) {
    if (!webpData || CFDataGetLength(webpData) == 0) return 0;

    WebPData data = {CFDataGetBytePtr(webpData), CFDataGetLength(webpData)};
    WebPDemuxer *demuxer = WebPDemux(&data);
    if (!demuxer) return 0;
    NSUInteger webpFrameCount = WebPDemuxGetI(demuxer, WEBP_FF_FRAME_COUNT);
    WebPDemuxDelete(demuxer);
    return webpFrameCount;
}

#define FAIL_CGImageCreateWithWebPData \
{ \
if (destBytes) free(destBytes); \
if (iterInited) WebPDemuxReleaseIterator(&iter); \
if (demuxer) WebPDemuxDelete(demuxer); \
return NULL; \
}

CGImageRef __nullable CGImageCreateWithWebPData(CFDataRef __nullable webpData, BOOL useThreads, BOOL bypassFiltering, BOOL noFancyUpsampling) {
    WebPData data = {0};
    WebPDemuxer *demuxer = NULL;

    int frameCount = 0, canvasWidth = 0, canvasHeight = 0;
    WebPIterator iter = {0};
    BOOL iterInited = NO;
    const uint8_t *payload = NULL;
    size_t payloadSize = 0;
    WebPDecoderConfig config = {0};

    const size_t bitsPerComponent = 8, bitsPerPixel = 32;
    size_t bytesPerRow = 0, destLength = 0;
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;

    void *destBytes = NULL;

    if (!webpData || CFDataGetLength(webpData) == 0) return NULL;
    data.bytes = CFDataGetBytePtr(webpData);
    data.size = CFDataGetLength(webpData);
    demuxer = WebPDemux(&data);
    if (!demuxer) FAIL_CGImageCreateWithWebPData;

    // Call WebPDecode() on a multi-frame webp data will get an error (VP8_STATUS_UNSUPPORTED_FEATURE).
    
    // Use WebPDemuxer to unpack it first.
    frameCount = WebPDemuxGetI(demuxer, WEBP_FF_FRAME_COUNT);
    if (frameCount == 0) {
        FAIL_CGImageCreateWithWebPData;

    } else if (frameCount == 1) { // single-frame
        payload = data.bytes;
        payloadSize = data.size;
        if (!WebPInitDecoderConfig(&config)) FAIL_CGImageCreateWithWebPData;
        if (WebPGetFeatures(payload , payloadSize, &config.input) != VP8_STATUS_OK) FAIL_CGImageCreateWithWebPData;
        canvasWidth = config.input.width;
        canvasHeight = config.input.height;

    } else { // multi-frame
        canvasWidth = WebPDemuxGetI(demuxer, WEBP_FF_CANVAS_WIDTH);
        canvasHeight = WebPDemuxGetI(demuxer, WEBP_FF_CANVAS_HEIGHT);
        if (canvasWidth < 1 || canvasHeight < 1) FAIL_CGImageCreateWithWebPData;

        if (!WebPDemuxGetFrame(demuxer, 1, &iter)) FAIL_CGImageCreateWithWebPData;
        iterInited = YES;

        if (iter.width > canvasWidth || iter.height > canvasHeight) FAIL_CGImageCreateWithWebPData;
        payload = iter.fragment.bytes;
        payloadSize = iter.fragment.size;

        if (!WebPInitDecoderConfig(&config)) FAIL_CGImageCreateWithWebPData;
        if (WebPGetFeatures(payload , payloadSize, &config.input) != VP8_STATUS_OK) FAIL_CGImageCreateWithWebPData;
    }
    if (payload == NULL || payloadSize == 0) FAIL_CGImageCreateWithWebPData;

    bytesPerRow = ImageByteAlign(bitsPerPixel / 8 * canvasWidth, 32);
    destLength = bytesPerRow * canvasHeight;

    destBytes = calloc(1, destLength);
    if (!destBytes) FAIL_CGImageCreateWithWebPData;

    config.options.use_threads = useThreads;
    config.options.bypass_filtering = bypassFiltering;
    config.options.no_fancy_upsampling = noFancyUpsampling;

    config.output.colorspace = MODE_rgbA;
    config.output.is_external_memory = 1;
    config.output.u.RGBA.rgba = destBytes;
    config.output.u.RGBA.stride = (int)bytesPerRow;
    config.output.u.RGBA.size = destLength;

    VP8StatusCode result = WebPDecode(payload, payloadSize, &config);
    if ((result != VP8_STATUS_OK) && (result != VP8_STATUS_NOT_ENOUGH_DATA)) FAIL_CGImageCreateWithWebPData;

    CGDataProviderRef provider = CGDataProviderCreateWithData(destBytes, config.output.u.RGBA.rgba, config.output.u.RGBA.size, ReleaseDataCallback);
    destBytes = NULL;

    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;

    CGImageRef imageRef = CGImageCreate(canvasWidth, canvasHeight, bitsPerComponent, bitsPerPixel, bytesPerRow, GetDeviceRGB_CGColorSpace(), bitmapInfo, provider, NULL, false, renderingIntent);

    // clean up
    CGDataProviderRelease(provider);

    if (iterInited) WebPDemuxReleaseIterator(&iter);
    WebPDemuxDelete(demuxer);

    return imageRef;
}

#undef FAIL_CGImageCreateWithWebPData

#pragma mark - Encode Functions

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
