//
//  AudioControl.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-11-22.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import Foundation

class AudioControl: NSObject {
  
  typealias AudioControlBlock = (AudioControl) -> Void
  
  static let global = AudioControl()
  
  static var isAppMuted: Bool {
    return AudioControl.global.appWideMute
  }
  
  @objc dynamic private var appWideMute = true
  
  var isAppMuted: Bool {
    return appWideMute
  }
  
  static func observeMuteState(withBlock callback: @escaping AudioControlBlock) -> NSKeyValueObservation {
    return AudioControl.global.observe(\.appWideMute) { audioController, change in
      callback(audioController)
    }
  }
  
  static func unobserveMuteState(_ observation: NSKeyValueObservation) {
    observation.invalidate()
  }
  
  static func mute() {
    AudioControl.global.appWideMute = true
  }
  
  static func unmute() {
    AudioControl.global.appWideMute = false
  }
}
