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
    case next
    case recursive
    
    // Digest Operation type and Moment Operation type have been deprecated
    case digest
    case moment
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
  
  
  // MARK: - Private Instance Variable
  private var prefetchOperation: AsyncOperation?
  
  
  // MARK: - Public Instance Variables
  var callback: SimpleErrorBlock?
  var momentNumber: Int = 999
  
  
  // MARK: - Public Static Functions
  static func createRecursive(with type: OperationType = .next, on story: FoodieStory, at priority: Operation.QueuePriority) -> StoryOperation {
    if type != .recursive {
      CCLog.fatal("Only .recursive is supported for recursive Story Prefetching")
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
  init(with type: OperationType, on story: FoodieStory, for momentIndex: Int? = nil, completion callback: SimpleErrorBlock?) {
    super.init(with: type, on: story)
    if let momentIndex = momentIndex {
      self.momentNumber = momentIndex
    }
    self.callback = callback
  }
  
  override func main() {
    guard let story = object as? FoodieStory else {
      CCLog.fatal("Object in StoryOperation is not a Story")
    }
    
    guard let opType = type as? OperationType else {
      CCLog.fatal("type in StoryOperation is not an OperationType")
    }
    
    guard let moments = story.moments  else {
      CCLog.fatal("Story has no moments")
    }
    
    switch opType {
    case .digest:
      CCLog.fatal("Digest Operation is no longer supported")
//      CCLog.debug("#Prefetch - Fetch Story \(story.getUniqueIdentifier()) for \(opType.rawValue) operation started")
//      prefetchOperation = story.retrieveDigest(from: .both, type: .cache) { error in
//        self.callback?(error)
//        self.finished()
//      }
      
    case .moment:
      CCLog.fatal("Moment Operation is no longer supported")
//      debug("#Prefetch - Fetch Story \(story.getUniqueIdentifier()) for \(opType.rawValue) operation with \(momentNumber) started")
//      prefetchOperation = moments[momentNumber].retrieveMedia(from: .both, type: .cache) { error in
//        self.callback?(error)
//        self.finished()
//      }
      
    case .next:
      fallthrough
      
    case .recursive:
      
      var momentNum = 0
      for moment in moments {
        if !moment.isMediaReady {
          
          if momentNum == 0 {
            // Retrieve all the Moments for the Story in 1 go
            FoodieMoment.batchRetrieve(moments) { objects, error in
              if let error = error {
                CCLog.warning("FoodieMoment.batchRetrieve Error - \(error.localizedDescription)")
                self.callback?(error)
                self.finished()
              }
              
              CCLog.debug("#Prefetch - Fetch Story \(story.getUniqueIdentifier()) at Moment 0/\(moments.count) is \(moments[0].getUniqueIdentifier())")
              self.prefetchOperation = moments[0].retrieveMedia(from: .both, type: .cache) { error in //withReady: nil
                self.callback?(error)
                self.finished()
              }
            }
          }
          
          else {
            CCLog.debug("#Prefetch - Fetch Story \(story.getUniqueIdentifier()) at Moment \(momentNum)/\(moments.count) is \(moment.getUniqueIdentifier())")
            prefetchOperation = moment.retrieveMedia(from: .both, type: .cache) { error in //withReady: nil
              self.callback?(error)
              self.finished()
            }
          }
          return
        }
        
        momentNum += 1
      }
      
      if opType == .recursive {
        // All Moments have been Retrieved!
        self.callback?(ErrorCode.allMomentsForStoryRetrieved)
        self.finished()
      }
    }
  }
  
  
  override func cancel() {
    super.cancel()
    if let prefetchOperation = prefetchOperation {
      prefetchOperation.cancel()
    }
  }
}
