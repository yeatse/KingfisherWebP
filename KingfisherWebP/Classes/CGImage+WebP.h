//
//  CGImage+WebP.h
//  Pods
//
//  Created by yeatse on 2016/10/20.
//
//

#import <CoreGraphics/CoreGraphics.h>

CF_IMPLICIT_BRIDGING_ENABLED

CGImageRef __nullable CGImageCreateWithWebPData(CFDataRef __nonnull webpData);

CFDataRef __nullable WebPRepresentationDataCreateWithImage(CGImageRef __nonnull image);

CF_IMPLICIT_BRIDGING_DISABLED
