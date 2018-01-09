//
//  ReputableClaim.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-12-31.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Parse
import Foundation


// !!! This class is purely Read-Only. Any attempt to write and Save will cause serious havoc !!!

class ReputableClaim: PFObject {
  
  // MARK: - Parse PFObject keys. All Read-only.
  
  var sourceId: String {
    return object(forKey: "sourceId") as? String ?? "undefined"
  }
  
  var targetId: String {
    return object(forKey: "targetId") as? String ?? "undefined"
  }
  
  var claimType: String {
    return object(forKey: "claimType") as? String ?? "undefined"
  }

  // For Story Claims
  
  var storyClaimType: Int {
    return object(forKey: "storyClaimType") as? Int ?? 0
  }
  
  var storyReactionType: Int {
    return object(forKey: "storyReactionType") as? Int ?? 0
  }
  
  var storyActionType: Int {
    return object(forKey: "storyActionType") as? Int ?? 0
  }
  
  var storyMomentNumber: Int {
    return object(forKey: "storyMomentNumber") as? Int ?? 0
  }
  
  
  
  // MARK: - Types & Enumeration
  
  enum ReputableClaimType: String {
    case storyClaim
  }
  
  enum StoryClaimType: Int {
    case reaction = 1
    case storyAction = 2
    case storyViewed = 3
  }
  
  enum StoryReactionType: Int {
    case like = 1
  }
  
  enum StoryActionType: Int {
    case swiped = 1
    case venue = 2
    case profile = 3
  }
  
  
  
  // MARK: - Error Types
  
  enum ErrorCode: LocalizedError {
    
    case storyReactionNoStoryId
    
    var errorDescription: String? {
      switch self {
      case .storyReactionNoStoryId:
        return NSLocalizedString("Story Reaction attempted without objectId to Story", comment: "Error message generated from Reputation Claim processing")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  
  // MARK: - Static Public Functions
  
  static func storyReaction(for story: FoodieStory, setNotClear: Bool, reactionType: StoryReactionType, withBlock callback: AnyErrorBlock?) {
    
    guard let storyId = story.objectId else {
      CCLog.assert("story.objectId = nil")
      callback?(nil, ErrorCode.storyReactionNoStoryId)
      return
    }
    
    let cloudFunctionName = ReputableClaimType.storyClaim.rawValue
    
    // Setup parameters and submit Cloud function
    var parameters = [AnyHashable: Any]()
    parameters["storyClaimType"] = StoryClaimType.reaction.rawValue
    parameters["storyId"] = storyId
    parameters["setNotClear"] = setNotClear
    parameters["reactionType"] = reactionType.rawValue
    
    PFCloud.callFunction(inBackground: cloudFunctionName, withParameters: parameters) { (object, error) in
      
      if let error = error {
        CCLog.warning("PFCloud Function \(cloudFunctionName) failed - \(error.localizedDescription)")
        callback?(nil, error)
        return
      }
      
      CCLog.verbose("PFCloud Function \(cloudFunctionName) repsonse success")
      
//      guard let reputableStory = object as? ReputableStory else {
//
//      }
    }
  }
  
  static func storyViewAction(actionType: StoryActionType) {
    
  }
  
  static func storyViewed(on momentNumber: Int) {
    
  }
  
}


extension ReputableClaim: PFSubclassing {
  static func parseClassName() -> String {
    return "ReputableClaim"
  }
}
