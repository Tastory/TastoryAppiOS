//
//  ReputableClaim.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-12-31.
//  Copyright © 2018 Tastory Lab Inc. All rights reserved.
//

import Parse
import Foundation


// !!! This class is purely Read-Only. Any attempt to write and Save will cause serious havoc !!!

class ReputableClaim: PFObject {
  
  // MARK: - Parse PFObject properties. All Read-only.
  
  var sourceId: String {
    return object(forKey: ReputableClaim.sourceIdKey) as? String ?? "undefined"
  }
  
  var targetId: String {
    return object(forKey: ReputableClaim.targetIdKey) as? String ?? "undefined"
  }
  
  var claimType: String {
    return object(forKey: ReputableClaim.claimTypeKey) as? String ?? "undefined"
  }

  // For Story Claims
  
  var storyClaimType: Int {
    return object(forKey: ReputableClaim.storyClaimTypeKey) as? Int ?? 0
  }
  
  var storyReactionType: Int {
    return object(forKey: ReputableClaim.storyReactionTypeKey) as? Int ?? 0
  }
  
  var storyActionType: Int {
    return object(forKey: ReputableClaim.storyActionTypeKey) as? Int ?? 0
  }
  
  var storyMomentNumber: Int {
    return object(forKey: ReputableClaim.storyMomentNumberKey) as? Int ?? 0
  }
  
  
  // Parse PFObject property keys
  
  private static let sourceIdKey = "sourceId"
  private static let targetIdKey = "targetId"
  private static let claimTypeKey = "claimType"
  private static let storyClaimTypeKey = "storyClaimType"
  private static let storyReactionTypeKey = "storyReactionType"
  private static let storyActionTypeKey = "storyActionType"
  private static let storyMomentNumberKey = "storyMomentNumber"
  
  
  // Extended key set for Cloud Function parameters
  
  private static let setNotClearKey = "setNotClear"
  
  
  
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
    case shared = 4
  }
  
  
  
  // MARK: - Error Types
  
  enum ErrorCode: LocalizedError {
    
    case storyCloudFunctionNoStoryId
    case storyCloudFunctionNoRepReturned
    case cannotCreatePFQuery
    
    var errorDescription: String? {
      switch self {
      case .storyCloudFunctionNoStoryId:
        return NSLocalizedString("Story Cloud Function attempted without objectId to Story", comment: "Error message generated from Reputable Claim processing")
      case .storyCloudFunctionNoRepReturned:
        return NSLocalizedString("Story Cloud Function did not return Story Reputation", comment: "Error message generated from Reputable Claim processing")
      case .cannotCreatePFQuery:
        return NSLocalizedString("Cannot create PFQuery, unable to perform the Query", comment: "Error description for a Reputable Claim error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Static Public Functions
  
  static func storyReaction(for story: FoodieStory, setNotClear: Bool, reactionType: StoryReactionType, withBlock callback: RepStoryErrorBlock?) {
    
    guard let storyId = story.objectId else {
      CCLog.assert("story.objectId = nil")
      callback?(nil, ErrorCode.storyCloudFunctionNoStoryId)
      return
    }
    
    let cloudFunctionName = ReputableClaimType.storyClaim.rawValue
    
    // Setup parameters and submit Cloud function
    var parameters = [AnyHashable: Any]()
    parameters[targetIdKey] = storyId
    parameters[storyClaimTypeKey] = StoryClaimType.reaction.rawValue
    parameters[storyReactionTypeKey] = reactionType.rawValue
    parameters[setNotClearKey] = setNotClear
    
    PFCloud.callFunction(inBackground: cloudFunctionName, withParameters: parameters) { (object, error) in
      
      if let error = error {
        CCLog.warning("PFCloud Function \(cloudFunctionName) failed - \(error.localizedDescription)")
        callback?(nil, error)
        return
      }
      
      guard let reputableStory = object as? ReputableStory else {
        CCLog.warning("PFCloud Function \(cloudFunctionName) expected to return Story Reputation")
        callback?(nil, ErrorCode.storyCloudFunctionNoRepReturned)
        return
      }
      
      CCLog.debug("PFCloud Function \(cloudFunctionName) repsonse success")
      callback?(reputableStory, nil)
    }
  }
  
  
  static func storyViewAction(for story: FoodieStory, actionType: StoryActionType, withBlock callback: RepStoryErrorBlock?) {
    
    guard let storyId = story.objectId else {
      CCLog.assert("story.objectId = nil")
      callback?(nil, ErrorCode.storyCloudFunctionNoStoryId)
      return
    }
    
    let cloudFunctionName = ReputableClaimType.storyClaim.rawValue
    
    // Setup parameters and submit Cloud function
    var parameters = [AnyHashable: Any]()
    parameters[targetIdKey] = storyId
    parameters[storyClaimTypeKey] = StoryClaimType.storyAction.rawValue
    parameters[storyActionTypeKey] = actionType.rawValue
    
    PFCloud.callFunction(inBackground: cloudFunctionName, withParameters: parameters) { (object, error) in
      
      if let error = error {
        CCLog.warning("PFCloud Function \(cloudFunctionName) failed - \(error.localizedDescription)")
        callback?(nil, error)
        return
      }
      
      guard let reputableStory = object as? ReputableStory else {
        CCLog.warning("PFCloud Function \(cloudFunctionName) expected to return Story Reputation")
        callback?(nil, ErrorCode.storyCloudFunctionNoRepReturned)
        return
      }
      
      CCLog.debug("PFCloud Function \(cloudFunctionName) repsonse success")
      callback?(reputableStory, nil)
    }
  }
  
  
  static func storyViewed(for story: FoodieStory, on momentNumber: Int, withBlock callback: RepStoryErrorBlock?) {
    
    guard let storyId = story.objectId else {
      CCLog.assert("story.objectId = nil")
      callback?(nil, ErrorCode.storyCloudFunctionNoStoryId)
      return
    }
    
    let cloudFunctionName = ReputableClaimType.storyClaim.rawValue
    
    // Setup parameters and submit Cloud function
    var parameters = [AnyHashable: Any]()
    parameters[targetIdKey] = storyId
    parameters[storyClaimTypeKey] = StoryClaimType.storyViewed.rawValue
    parameters[storyMomentNumberKey] = momentNumber
    
    PFCloud.callFunction(inBackground: cloudFunctionName, withParameters: parameters) { (object, error) in
      
      if let error = error {
        CCLog.warning("PFCloud Function \(cloudFunctionName) failed - \(error.localizedDescription)")
        callback?(nil, error)
        return
      }
      
      guard let reputableStory = object as? ReputableStory else {
        CCLog.warning("PFCloud Function \(cloudFunctionName) expected to return Story Reputation")
        callback?(nil, ErrorCode.storyCloudFunctionNoRepReturned)
        return
      }
      
      CCLog.debug("PFCloud Function \(cloudFunctionName) repsonse success")
      callback?(reputableStory, nil)
    }
  }
  
  
  static func queryStoryClaims(from sourceId: String, to targetId: String, of storyClaimType: StoryClaimType? = nil, withBlock callback: AnyErrorBlock?) {

    guard let claimsQuery = ReputableClaim.query() else {
      CCLog.assert("Cannot create a PFQuery object from ReputableClaim")
      callback?(nil, ErrorCode.cannotCreatePFQuery)
      return
    }
    
    claimsQuery.whereKey(sourceIdKey, equalTo: sourceId)
    claimsQuery.whereKey(targetIdKey, equalTo: targetId)
    
    if let storyClaimType = storyClaimType {
      claimsQuery.whereKey(storyClaimTypeKey, equalTo: storyClaimType.rawValue)
    }
    
    claimsQuery.findObjectsInBackground { (objects, error) in callback?(objects, error) }
  }
  
  
  static func storyReactionClaimExists(of type: ReputableClaim.StoryReactionType, in claims: [ReputableClaim]) -> Bool {
    let matchingClaims = claims.filter({ $0.storyClaimType == StoryClaimType.reaction.rawValue &&
                                         $0.storyReactionType == type.rawValue })
    if matchingClaims.count > 1 { CCLog.warning("More than 1 matching claims found") }
    
    return !matchingClaims.isEmpty
  }
  
  
  static func storyActionClaimExists(of type: ReputableClaim.StoryActionType, in claims: [ReputableClaim]) -> Bool {
    let matchingClaims = claims.filter({ $0.storyClaimType == StoryClaimType.storyAction.rawValue &&
                                         $0.storyActionType == type.rawValue })
    if matchingClaims.count > 1 { CCLog.warning("More than 1 matching claims found") }
    
    return !matchingClaims.isEmpty
  }
  
  
  static func storyViewedMomentNumber(in claims: [ReputableClaim]) -> Int? {
    let matchingClaims = claims.filter({ $0.storyClaimType == StoryClaimType.storyViewed.rawValue })
    if matchingClaims.count > 1 { CCLog.warning("More than 1 matching claims found") }
    
    if matchingClaims.isEmpty {
      return nil
    } else {
      return matchingClaims[0].storyMomentNumber
    }
  }
}


extension ReputableClaim: PFSubclassing {
  static func parseClassName() -> String {
    return "ReputableClaim"
  }
}
