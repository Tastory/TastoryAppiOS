//
//  ReputableClaim.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-12-31.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Parse
import Foundation

class ReputableClaim: PFObject {
  
  // MARK: - Parse PFObject keys
  
  @NSManaged var sourceId: String?
  @NSManaged var targetId: String?
  @NSManaged var claimType: String?

  // For Story Claims
  @NSManaged var storyClaimType: Int
  @NSManaged var reactionType: Int
  @NSManaged var actionType: Int
  @NSManaged var momentNumber: Int
  
  
  
  // MARK: - Types & Enumeration
  
  enum Type: String {
    case storyClaim
  }
  
  enum StoryClaimType: Int {
    case reaction = 1
    case storyAction = 2
    case storyViewed = 3
  }
  
  enum ReactionType: Int {
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
  
  static func storyReaction(for story: FoodieStory, setNotClear: Bool, reactionType: ReactionType, withBlock callback: AnyErrorBlock?) {
    
    guard let storyId = story.objectId else {
      CCLog.assert("story.objectId = nil")
      callback?(nil, ErrorCode.storyReactionNoStoryId)
      return
    }
    
    let cloudFunctionName = Type.storyClaim.rawValue
    
    // Setup parameters and submit Cloud function
    var parameters = [AnyHashable: Any]()
    parameters["storyClaimType"] = StoryClaimType.reaction.rawValued
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
