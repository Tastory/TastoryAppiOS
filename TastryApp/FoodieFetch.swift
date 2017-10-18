//
//  FoodieFetch.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-06-24.
//  Copyright © 2017 Tastry. All rights reserved.
//


import Foundation


class FoodieFetch {
  
  // MARK: - Constants
  struct Constants {
    static let ConcurrentFetchesAtATime = 3
  }
  
  
  // MARK: - Read Only Static Variable
  private(set) static var global = FoodieFetch()
  
  
  // MARK: - Private Instance Variable
  private let fetchQueue = OperationQueue()
  
  
  // MARK: - Public Instance Functions
  init() {
    fetchQueue.qualityOfService = QualityOfService.userInitiated  // The priority of this must be equal or higher than what's used throughout the recursive operations. Otherwise the FoodieModel will fall apart.
    fetchQueue.maxConcurrentOperationCount = Constants.ConcurrentFetchesAtATime
  }
  
  // Idea here is that each object can at most only have 1 operation per priority
  func queue(_ operation: FoodieOperation, at priority: Operation.QueuePriority) {  // We can later make an intermediary sublcass to make it more diverse across any objects. Eg. Prefetch User Objects, etc
    
    guard let storyOp = operation as? StoryOperation, let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType else {
      CCLog.fatal("Expecting storyOp, story and type")
    }
    
    #if DEBUG
      CCLog.info("#Prefetch - Queuing Story \(story.getUniqueIdentifier()) for \(type.rawValue) operation. Queue now at \(self.fetchQueue.operations.count + 1) outstanding")
    #else
    CCLog.debug("Queuing Story \(story.getUniqueIdentifier()) for \(type.rawValue) operation. Queue now at \(self.fetchQueue.operations.count + 1) outstanding")
    #endif
  
    operation.queuePriority = priority
    operation.completionBlock = {
      #if DEBUG
        CCLog.info("#Prefetch - Completion for Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue now at \(self.fetchQueue.operations.count) outstanding")
      #else
        CCLog.debug("Completion for Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue now at \(self.fetchQueue.operations.count) outstanding")
      #endif
    }
    fetchQueue.addOperation(operation)
  }
  
  func cancel(for object: AnyObject) {
    for operation in fetchQueue.operations {
      if let storyOp = operation as? StoryOperation {
        if storyOp.object === object {
          
          if let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType {
          #if DEBUG
            CCLog.info("#Prefetch - Cancel Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue at \(self.fetchQueue.operations.count) outstanding before cancel")
          #else
            CCLog.debug("Completion Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue now at \(self.fetchQueue.operations.count) outstanding")
          #endif
          } else {
            CCLog.warning("storyOp.object not a story!")
          }
          storyOp.cancel()
        }
      }
    }
  }
  
  func cancelAllBut(for object: AnyObject) {
    
    guard let story = object as? FoodieStory else {
      CCLog.fatal("Expected object to be of FoodieStory type")
    }
    #if DEBUG
      CCLog.info("#Prefetch - Cancel All but Story \(story.getUniqueIdentifier()). Queue at \(self.fetchQueue.operations.count) outstanding before cancel")
    #else
      CCLog.debug("Cancel All but Story \(story.getUniqueIdentifier()). Queue at \(self.fetchQueue.operations.count) outstanding before cancel")
    #endif
    
    for operation in fetchQueue.operations {
      if let storyOp = operation as? StoryOperation {
        if storyOp.object !== object {
          
          if let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType {
            #if DEBUG
              CCLog.info("#Prefetch - Cancel Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue at \(self.fetchQueue.operations.count) outstanding before cancel")
            #else
              CCLog.debug("Cancel Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue now at \(self.fetchQueue.operations.count) outstanding")
            #endif
          }  else {
            CCLog.warning("storyOp.object not a story!")
          }
          storyOp.cancel()
        }
      }
    }
  }
  
  func cancelAll() {
    fetchQueue.cancelAllOperations()
  }
  
  func printDebug() {
    CCLog.info("Fetch Queue has \(fetchQueue.operations.count) outstanding operations")
    for operation in fetchQueue.operations {
      if let storyOp = operation as? StoryOperation {
        if let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType {
          CCLog.info(" Story \(story.getUniqueIdentifier()) with \(type.rawValue) operation and index of \(storyOp.momentNumber)")
        }
      }
    }
  }
}











