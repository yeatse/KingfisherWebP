//
//  Kingfisher+WebP.swift
//  Pods
//
//  Created by yeatse on 2016/10/22.
//
//

import Kingfisher

extension Kingfisher where Base: ImageView {
    
    @discardableResult
    public func setWebPImage(with resource: Resource?,
                             placeholder: Image? = nil,
                             options: KingfisherOptionsInfo? = [.processor(WebPProcessor.default), .cacheSerializer(WebPSerializer.default)],
                             progressBlock: DownloadProgressBlock? = nil,
                             completionHandler: CompletionHandler? = nil) -> RetrieveImageTask
    {
        return setImage(with: resource, placeholder: placeholder, options: options, progressBlock: progressBlock, completionHandler: completionHandler)
    }
}
