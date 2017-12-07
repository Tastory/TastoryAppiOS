//
//  AVDebugPlayer.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-12-06.
//  Copyright © 2017 Tastry. All rights reserved.
//

import AVFoundation

class AVDebugPlayer: AVPlayer {
  
  private let uniqueIdentifier: String
  
  override init() {
    uniqueIdentifier = UUID().uuidString
    CCLog.verbose("AVDebugPlayer init for \(uniqueIdentifier)")
    super.init()
  }
  
  override init(url: URL) {
    uniqueIdentifier = url.lastPathComponent
    CCLog.verbose("AVDebugPlayer init for \(uniqueIdentifier)")
    super.init(url: url)
  }
  
  override init(playerItem item: AVPlayerItem?) {
    if let item = item, let urlAsset = item.asset as? AVURLAsset {
      uniqueIdentifier = urlAsset.url.lastPathComponent
    } else {
      uniqueIdentifier = UUID().uuidString
    }
    CCLog.verbose("AVDebugPlayer init for \(uniqueIdentifier)")
    super.init(playerItem: item)
  }
  
  deinit {
    CCLog.verbose("AVDebugPlayer deinit for \(uniqueIdentifier)")
  }
}
