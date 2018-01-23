//
//  AVPlayerItemStatus.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-18.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import AVFoundation

extension AVPlayerItemStatus {
  var string: String {
    switch self {
    case .unknown:
      return "unknown"
    case .readyToPlay:
      return "readyToPlay"
    case .failed:
      return "failed"
    }
  }
}
