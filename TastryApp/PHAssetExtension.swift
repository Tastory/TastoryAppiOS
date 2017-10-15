//
//  PHAssetExtension.swift
//  TastryApp
//
//  Created by Victor Tsang on 2017-10-07.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Photos

extension PHAsset {

  func copyMediaFile(withName fileName: String, withBlock callback: @escaping (URL?, Error?) ->Void ) -> Void {
    if self.mediaType != .video {
      CCLog.verbose("Tryping to copy a media that is not a video")
      callback(nil,nil)
    }

    guard let resource = PHAssetResource.assetResources(for: self).first else {
      CCLog.assert("The asset resource is not available")
      return
    }

    let writeURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = false
    PHAssetResourceManager.default().writeData(for: resource, toFile: writeURL, options: options, completionHandler: { error in
      callback(writeURL, error)
    })
  }

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
