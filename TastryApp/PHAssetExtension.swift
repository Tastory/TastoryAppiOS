//
//  PHAssetExtension.swift
//  TastryApp
//
//  Created by Victor Tsang on 2017-10-07.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Photos

extension PHAsset {

  func getURL(completionHandler : @escaping ((_ responseURL : URL?) -> Void)){
    if self.mediaType == .image {
      let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
      options.canHandleAdjustmentData = {(adjustmeta: PHAdjustmentData) -> Bool in
        return true
      }
      self.requestContentEditingInput(with: options, completionHandler: {(contentEditingInput: PHContentEditingInput?, info: [AnyHashable : Any]) -> Void in
        completionHandler(contentEditingInput!.fullSizeImageURL as URL?)
      })
    } else if self.mediaType == .video {
      let options: PHVideoRequestOptions = PHVideoRequestOptions()
      options.version = .original
      PHImageManager.default().requestAVAsset(forVideo: self, options: options, resultHandler: {(asset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable : Any]?) -> Void in
        if let urlAsset = asset as? AVURLAsset {
          let localVideoUrl: URL = urlAsset.url as URL
          completionHandler(localVideoUrl)
        } else {
          completionHandler(nil)
        }
      })
    }
  }
}
