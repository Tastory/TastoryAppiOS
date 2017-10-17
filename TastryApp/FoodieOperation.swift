//
//  FoodieOperation.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-16.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Foundation

class FoodieOperation: AsyncOperation {
  var type: Any
  var object: AnyObject
  
  init(with type: Any, on object: AnyObject) {
    self.type = type
    self.object = object
  }
}


class StoryOperation: FoodieOperation {  // We can later make an intermediary sublcass to make it more diverse across any objects. Eg. Prefetch User Objects, etc
  
  // MARK: - Types & Enumerations
  enum OperationType: String {
    case digest
    case nextMoment
  }

  
  // MARK: - Error Types
  enum ErrorCode: LocalizedError {
    
    case allMomentsForStoryRetrieved
    
    var errorDescription: String? {
      switch self {
      case .allMomentsForStoryRetrieved:
        return NSLocalizedString("All moments for Story have been retrieved", comment: "An error type actually describing a successful completion of a long running series of operations")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Public Instance Variables
  var callback: SimpleErrorBlock?
  
  
  
  // MARK: - Public Static Functions
  static func createRecursive(with type: OperationType = .nextMoment, on story: FoodieStory, at priority: Operation.QueuePriority) -> StoryOperation {
    guard type == .nextMoment else {
      CCLog.fatal("Only .nextMoment is supported for recursive Story Prefetching")
    }
    
    return StoryOperation(with: type, on: story) { error in
      if let error = error {
        switch error {
        case ErrorCode.allMomentsForStoryRetrieved:
          CCLog.info("All Moments for Story \(story.getUniqueIdentifier()) retrieved")
          return
        default:
          CCLog.warning("Recursive Prefetch for Story \(story.getUniqueIdentifier()) resulted in Error - \(error.localizedDescription)")
          return
        }
      }
      let nextStoryOperation = createRecursive(with: type, on: story, at: priority)
      FoodieFetch.global.queue(nextStoryOperation, at: priority)
    }
  }
  
  
  // MARK: - Public Instance Functions
  init(with type: OperationType, on story: FoodieStory, completion callback: SimpleErrorBlock?) {
    super.init(with: type, on: story)
    self.callback = callback
  }
  
  override func main() {
    guard let story = object as? FoodieStory else {
      CCLog.fatal("Object in StoryOperation is not a Story")
    }
    
    guard let opType = type as? OperationType else {
      CCLog.fatal("type in StoryOperation is not an OperationType")
    }
    
    #if DEBUG
      CCLog.info("Fetch Story \(opType) Operation for \(story.getUniqueIdentifier()) Started")
    #else
      CCLog.debug("Fetch Story \(opType) Operation for \(story.getUniqueIdentifier()) Started")
    #endif
    
    switch opType {
    case .digest:
      story.retrieveDigest(from: .both, type: .cache) { error in
        self.callback?(error)
        self.finished()
      }
      
    case .nextMoment:
      // Find the next unfetched moment first
      guard let moments = story.moments else {
        CCLog.assert("No Moments in Story for Fetch Operation")
        return
      }
      
      var momentNum = 0
      for moment in moments {
        momentNum += 1
        if !moment.isRetrieved {
          
          #if DEBUG
            CCLog.info("Moment \(momentNum)/\(moments.count) to fetch for Story \(story.getUniqueIdentifier()) is \(moment.getUniqueIdentifier())")
          #else
            CCLog.debug("Moment \(momentNum)/\(moments.count) to fetch for Story \(story.getUniqueIdentifier()) is \(moment.getUniqueIdentifier())")
          #endif
          
          moment.retrieveRecursive(from: .both, type: .cache) { error in //withReady: nil
            self.callback?(error)
            self.finished()
          }
          return
        }
      }
      
      // All Moments have been Retrieved!
      self.callback?(ErrorCode.allMomentsForStoryRetrieved)
      self.finished()
    }
  }
  
  override func cancel() {
    super.cancel()
    guard let story = object as? FoodieStory else {
      CCLog.fatal("Object in StoryOperation is not a Story")
    }
    story.cancelRetrieveFromServerRecursive()
  }
}
