//
//  AVDebugPlayer.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-12-06.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import AVFoundation

class AVDebugPlayer: AVPlayer {
  
  private var uniqueIdentifier: String? = nil
  
  override init() {
    if uniqueIdentifier == nil {
      uniqueIdentifier = UUID().uuidString
      CCLog.verbose("AVDebugPlayer init for \(uniqueIdentifier!)")
    }
    super.init()
  }
  
  override init(url: URL) {
    super.init(url: url)
  }
  
  override init(playerItem item: AVPlayerItem?) {
    super.init(playerItem: item)
  }
  
  deinit {
    CCLog.verbose("AVDebugPlayer deinit for \(uniqueIdentifier!)")
  }
}
