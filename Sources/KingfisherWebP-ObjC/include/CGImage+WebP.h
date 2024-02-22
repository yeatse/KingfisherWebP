//
//  CGImage+WebP.h
//  Pods
//
//  Created by yeatse on 2016/10/20.
//
//

#import <CoreGraphics/CoreGraphics.h>

CF_IMPLICIT_BRIDGING_ENABLED
CF_ASSUME_NONNULL_BEGIN

// still image
CGImageRef __nullable WebPImageCreateWithData(CFDataRef webpData);
CFDataRef __nullable WebPDataCreateWithImage(CGImageRef image, bool isLossy, float quality);

// animated image
CG_EXTERN const CFStringRef kWebPAnimatedImageDuration;
CG_EXTERN const CFStringRef kWebPAnimatedImageLoopCount;
CG_EXTERN const CFStringRef kWebPAnimatedImageFrames; // CFArrayRef of CGImageRef
CG_EXTERN const CFStringRef kWebPAnimatedImageFrameDurations; // CFArrayRef of CFNumberRef

uint32_t WebPImageFrameCountGetFromData(CFDataRef webpData);
CFDictionaryRef __nullable WebPAnimatedImageInfoCreateWithData(CFDataRef webpData);
CFDataRef __nullable WebPDataCreateWithAnimatedImageInfo(CFDictionaryRef imageInfo, bool isLossy, float quality);

// accumulative decoding
typedef struct WebPImageDecoder *WebPDecoderRef;

WebPDecoderRef __nullable WebPDecoderCreateWithData(CFDataRef webpData);
void WebPDecoderDestroy(WebPDecoderRef decoder);

uint32_t WebPDecoderGetFrameCount(WebPDecoderRef decoder);
CFTimeInterval WebPDecoderGetDurationAtIndex(WebPDecoderRef decoder, int index);
CGImageRef __nullable WebPDecoderCopyImageAtIndex(WebPDecoderRef decoder, int index);

CF_ASSUME_NONNULL_END
CF_IMPLICIT_BRIDGING_DISABLED
