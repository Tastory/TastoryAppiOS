//
//  AVPlayerItemStatus.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-18.
//  Copyright © 2017 Tastry. All rights reserved.
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
