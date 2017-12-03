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
  private let fetchLock = DispatchQueue(label: "Fetch Lock Queue", qos: .userInitiated)
  
  // MARK: - Public Instance Functions
  init() {
    fetchQueue.qualityOfService = .userInitiated
    fetchQueue.maxConcurrentOperationCount = Constants.ConcurrentFetchesAtATime
  }
  
  
  // Idea here is that each object can at most only have 1 operation per priority
  func queue(_ operation: FoodieOperation, at priority: Operation.QueuePriority) {  // We can later make an intermediary sublcass to make it more diverse across any objects. Eg. Prefetch User Objects, etc
    
    fetchLock.async {
      guard let storyOp = operation as? StoryOperation, let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType else {
        CCLog.fatal("Expecting storyOp, story and type")
      }

      CCLog.debug("#Prefetch - Queuing Story \(story.getUniqueIdentifier()) for \(type.rawValue) operation. Queue now at \(self.fetchQueue.operationCount + 1) outstanding")
    
      operation.queuePriority = priority
      operation.completionBlock = { [unowned self] in
        CCLog.debug("#Prefetch - Completion for Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue now at \(self.fetchQueue.operationCount) outstanding")
      }
      self.fetchQueue.addOperation(operation)
    }
  }
  
  
  func cancel(for object: AnyObject) {
    fetchLock.async {
      for operation in self.fetchQueue.operations {
        if let storyOp = operation as? StoryOperation, storyOp.object === object {
          if let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType {
            CCLog.debug("#Prefetch - Cancel Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue at \(self.fetchQueue.operationCount) outstanding before cancel")
          } else {
            CCLog.warning("storyOp.object not a story!")
          }
          storyOp.cancel()
        }
      }
    }
  }
  
  
  func cancelAllButOne(_ object: AnyObject) {
    
    fetchLock.async {
      guard let story = object as? FoodieStory else {
        CCLog.fatal("Expected object to be of FoodieStory type")
      }
      CCLog.info("#Prefetch - Cancel All but Story \(story.getUniqueIdentifier()). Queue at \(self.fetchQueue.operationCount) outstanding before cancel")
      
      var needsToPrefetchNextMoment = true
      
      for operation in self.fetchQueue.operations {
        if let storyOp = operation as? StoryOperation {
          
          // Cancel anything that is not of the current story
          if storyOp.object !== object {
            
            if let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType {
              CCLog.debug("#Prefetch - Cancel Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue now at \(self.fetchQueue.operationCount) outstanding")
            } else {
              CCLog.warning("#Prefetch - storyOp.object not a story!")
            }
            storyOp.cancel()
            
          } else if let operationType = storyOp.type as? StoryOperation.OperationType, operationType == .allMedia {
            needsToPrefetchNextMoment = false
          }
        }
      }
      
      if needsToPrefetchNextMoment {
        CCLog.info("#Prefetch - Expected that there should already be a Story Prefech.allMedia for \(story.getUniqueIdentifier()), but didn't. Executing one now")
        let momentOperation = StoryOperation.createRecursive(with: .allMedia, on: story, at: .low)
        self.queue(momentOperation, at: .low)
      }
    }
  }
  
  
  // Object list should be sorted in decending order of priority for Pre-fetching
  func cancelAllBut(_ objects: [AnyObject]) {
    
    fetchLock.async {
      guard var stories = objects as? [FoodieStory] else {
        CCLog.fatal("Expected objects to be of FoodieStory type")
      }
      
      var debugStoryIdentifiers = "Story Identifiers:"
      for story in stories {
        debugStoryIdentifiers += " \(story.getUniqueIdentifier())"
      }
      
      CCLog.info("#Prefetch - Cancel All aside from the following Stories. Queue at \(self.fetchQueue.operationCount) outstanding before cancel")
      CCLog.info("#Prefetch - \(debugStoryIdentifiers)")
      
      for operation in self.fetchQueue.operations {
        if let storyOp = operation as? StoryOperation {
          
          guard let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType else {
            CCLog.fatal("storyOp.object not a story!")
          }
          
          // Cancel anything that is not of the current story
          if !objects.contains(where: { $0 === storyOp.object }) {
            CCLog.debug("#Prefetch - Cancel Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue at \(self.fetchQueue.operationCount) outstanding before cancel")
            storyOp.cancel()
            
          } else if type == .nextMedia || type == .allMedia {
            
            guard let indexToRemove = stories.index(where: { $0 === story }) else {
              CCLog.fatal("Story deemed Prefetching, but cannot be found from Object (story) argument list")
            }
            stories.remove(at: indexToRemove)
          }
        }
      }
      
      if stories.count > 0 {
        debugStoryIdentifiers = "StoryIdentifiers:"
        
        for story in stories {
          // let momentOperation = StoryOperation.createRecursive(with: .allMedia, on: story, at: .low)
          let momentOperation = StoryOperation(with: .nextMedia, on: story, completion: nil)
          self.queue(momentOperation, at: .low)
          debugStoryIdentifiers += " \(story.getUniqueIdentifier())"
        }

        CCLog.debug("#Prefetch - Expected that there should already be Prefetching for the following Stories, but didn't. Performing Prefetching Next now")
        CCLog.debug("#Prefetch - \(debugStoryIdentifiers)")
      }
    }
  }
  
  
  func cancelAll() {
    CCLog.info("#Prefetch - Cancelling All Prefetch Operations!")
    fetchLock.async { self.fetchQueue.cancelAllOperations() }
  }
  
  
  func printDebug() {
    CCLog.info("Fetch Queue has \(fetchQueue.operationCount) outstanding operations")
    for operation in fetchQueue.operations {
      if let storyOp = operation as? StoryOperation {
        if let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType {
          CCLog.info(" Story \(story.getUniqueIdentifier()) with \(type.rawValue) operation and index of \(storyOp.momentNumber)")
        }
      }
    }
  }
}











