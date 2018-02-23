//
//  ReputableStory.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-12-31.
//  Copyright © 2018 Tastory Lab Inc. All rights reserved.
//

import Parse
import Foundation

typealias RepStoryErrorBlock = (ReputableStory?, Error?) -> Void


// !!! This class is purely Read-Only. Any attempt to write and Save will cause serious havoc !!!

class ReputableStory: PFObject {
  
  // MARK: - Parse PFObject keys. All Read-only.
  
  var storyId: String {
    return object(forKey: "storyId") as? String ?? "undefined"
  }
  
  var scoreMetricVer: Int {
    return object(forKey: "scoreMetricVer") as? Int ?? 0
  }
  
  var usersViewed: Int {
    return object(forKey: "usersViewed") as? Int ?? 0
  }
  
  var usersLiked: Int {
    return object(forKey: "usersLiked") as? Int ?? 0
  }
  
  var usersSwipedUp: Int {
    return object(forKey: "usersSwipedUp") as? Int ?? 0
  }
  
  var usersClickedVenue: Int {
    return object(forKey: "usersClickedVenue") as? Int ?? 0
  }
  
  var usersClickedProfile: Int {
    return object(forKey: "usersClickedProfile") as? Int ?? 0
  }
  
  var usersShared: Int {
    return object(forKey: "usersShared") as? Int ?? 0
  }
  
  var totalMomentNumber: Int {
    return object(forKey: "totalMomentNumber") as? Int ?? 0
  }
  
  var totalViews: Int {
    return object(forKey: "totalViews") as? Int ?? 0
  }
}


extension ReputableStory: PFSubclassing {
  static func parseClassName() -> String {
    return "ReputableStory"
  }
}

