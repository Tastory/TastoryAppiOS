//
//  AVPlayerTinmeControlStatus+Extension.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-18.
//  Copyright © 2017 Tastry. All rights reserved.
//

import AVFoundation

extension AVPlayerTimeControlStatus {
  var string: String {
    switch self {
    case .paused:
      return "paused"
    case .waitingToPlayAtSpecifiedRate:
      return "waitingToPlayAtSpecifiedRate"
    case .playing:
      return "playing"
    }
  }
}
