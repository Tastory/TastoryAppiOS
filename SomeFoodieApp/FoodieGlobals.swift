//
//  FoodieGlobals.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-05-20.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

// MARK: - Types & Enums
enum FoodieMediaType: String {
  case photo = "image/jpeg"
  case video = "video/mp4"
  //case unknown = "application/octet-stream"
}

struct FoodieConstants {
  static let ThumbnailPixels = 640.0
  static let JpegCompressionQuality: Double = 0.8
  static let ThemeColor: UIColor = .orange
  static let MomentsToBufferAtATime = 5
  static let JournalFeedPaginationCount = 50  // TODO: Need to implement pagination
  static let DefaultServerRequestRetryCount = 3
  static let DefaultServerRequestRetryDelay = 3.0
}
