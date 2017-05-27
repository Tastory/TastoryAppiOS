//
//  FoodieGlobals.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-05-20.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import Foundation

// MARK: - Types & Enums
enum FoodieMediaType: String {
  case photo = "image/jpeg"
  case video = "video/mp4"
  //case unknown = "application/octet-stream"
}

struct FoodieConstants {
  static let thumbnailPixels = 640.0
  static let jpegCompressionQuality: Double = 0.8
}
