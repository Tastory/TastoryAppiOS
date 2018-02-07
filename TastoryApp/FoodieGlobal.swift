//
//  FoodieGlobal.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-05-20.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit
import QuadratTouch


// MARK: - Types & Enums
typealias BooleanErrorBlock = (Bool, Error?) -> Void
typealias AnyErrorBlock = (Any?, Error?) -> Void
typealias SimpleErrorBlock = (Error?) -> Void
typealias UserErrorBlock = (FoodieUser?, Error?) -> Void
typealias StoryErrorBlock = (FoodieStory?, Error?) -> Void
typealias StoriesErrorBlock = ([FoodieStory]?, Error?) -> Void
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
    static let ThemeColor = UIColor(displayP3Red: 250/256, green: 9/256, blue: 9/256, alpha: 1.0)
    static let TextColor = UIColor(displayP3Red: 74/256, green: 74/256, blue: 74/256, alpha: 1.0)
    static let StoryFeedPaginationCount = 50
    static let DefaultServerRequestRetryCount = 3
    static let DefaultServerRequestRetryDelay = 3.0
    static let DefaultTransitionAnimationDuration: TimeInterval = 0.4
    static let DefaultUIDisappearanceDuration: TimeInterval = 0.15
    static let DefaultTransitionUnderVCAlpha: CGFloat = 0.1
    static let DefaultMomentAspectRatio: CGFloat = 9/16
    static let DefaultSlideVCGapSize: CGFloat = 5.0
    static let DefaultUIShadowOffset = CGSize(width: 0.0, height: 0.0)
    static let DefaultUIShadowRadius: CGFloat = 3.0
    static let DefaultUIShadowOpacity: Float = 0.38
    static let DefaultDeepLinkWaitDelay = 0.5
  }

  struct RefreshFeedNotification {
    static let NotificationId = "FeedUpdateNotify"
    static let WorkingStoryKey = "WorkingStory"
    static let ActionKey = "Action"
    static let UpdateAction = "Update"
    static let DeleteAction = "Delete"
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
    
    // Do Periodic Cache Clean-up
    FoodieFileObject.cleanUpCache()
  }
  
  
  static func booleanToSimpleErrorCallback(_ success: Bool, _ error: Error?, function: String = #function, file: String = #file, line: Int = #line, _ callback: SimpleErrorBlock?) {
    #if DEBUG  // Do this sanity check now and never need to worry about it again
      if (success && error != nil) || (!success && error == nil) {
        CCLog.assert("Parse layer come back with Success and Error mismatch")
      }
    #endif
    
    if !success {
      CCLog.warning("\(function) Failed with Error - \(error!.localizedDescription) on line \(line) of \((file as NSString).lastPathComponent)")
    }
    callback?(error)
  }
}
