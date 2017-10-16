//
//  PHAssetExtension.swift
//  TastryApp
//
//  Created by Victor Tsang on 2017-10-07.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Photos

extension PHAsset {

  // MARK: - Error Types Definition
  enum ErrorCode: LocalizedError {

    case assetResourceNotFound

    var errorDescription: String? {
      switch self {
      case .assetResourceNotFound:
        return NSLocalizedString("Failed to get asset resource", comment: "Error description for an exception error code")
      }
    }

    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }

  func copyMediaFile(withName fileName: String, withBlock callback: @escaping (URL?, Error?) ->Void ) -> Void {
    if self.mediaType != .video {
      CCLog.verbose("Tryping to copy a media that is not a video")
      callback(nil,nil)
    }

    guard let resource = PHAssetResource.assetResources(for: self).first else {
      CCLog.assert("The asset resource is not available")
      callback(nil, ErrorCode.assetResourceNotFound)
    }

    let writeURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = false
    PHAssetResourceManager.default().writeData(for: resource, toFile: writeURL, options: options, completionHandler: { error in
      callback(writeURL, error)
    })
  }
}
