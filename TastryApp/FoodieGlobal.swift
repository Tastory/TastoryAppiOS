//
//  FoodieGlobal.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-05-20.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit
import QuadratTouch


// MARK: - Types & Enums
typealias BooleanErrorBlock = (Bool, Error?) -> Void
typealias AnyErrorBlock = (Any?, Error?) -> Void
typealias SimpleErrorBlock = (Error?) -> Void
typealias UserErrorBlock = (FoodieUser?, Error?) -> Void
typealias SimpleBlock = () -> Void


enum FoodieMediaType: String {
  case photo = "image/jpeg"
  case video = "video/mp4"
  //case unknown = "application/octet-stream"
}


struct FoodieGlobal {
  
  // MARK: - Constants
  
  struct Constants {
    static let ThumbnailPixels = 640.0
    static let JpegCompressionQuality: Double = 0.8
    static let ThemeColor = UIColor(hue: 10.0/360.0, saturation: 0.9, brightness: 1.0, alpha: 1.0)
    static let StoryFeedPaginationCount = 50  // TODO: Need to implement pagination
    static let DefaultServerRequestRetryCount = 3
    static let DefaultServerRequestRetryDelay = 3.0
    static let DefaultTransitionAnimationDuration: TimeInterval = 0.4
    static let DefaultTransitionUnderVCAlpha: CGFloat = 0.1
    static let DefaultMomentAspectRatio: CGFloat = 9/16
    static let DefaultSlideVCGapSize: CGFloat = 5.0
  }
  
  
  // MARK: - Public Static Functions
  
  static func initialize() {
    
    // This contains Parse.initialize, must come other Parse containing classes
    FoodiePFObject.pfConfigure()
    
    // Enable Automatic User
    FoodieUser.userConfigure(enableAutoUser: false)
    
    // Set Default Permissions
    FoodiePermission.setDefaultGlobalObjectPermission()
    
    // Initialize Das Quadrat
    FoodieVenue.venueConfigure()
    
    // Create S3 Manager singleton
    FoodieFileObject.fileConfigure()
  }
  
  
  static func booleanToSimpleErrorCallback(_ success: Bool, _ error: Error?, function: String = #function, file: String = #file, line: Int = #line, _ callback: SimpleErrorBlock?) {
    #if DEBUG  // Do this sanity check low and never need to worry about it again
      if (success && error != nil) || (!success && error == nil) {
        CCLog.fatal("Parse layer come back with Success and Error mismatch")
      }
    #endif
    
    if !success {
      CCLog.warning("\(function) Failed with Error - \(error!.localizedDescription) on line \(line) of \((file as NSString).lastPathComponent)")
    }
    callback?(error)
  }
}
