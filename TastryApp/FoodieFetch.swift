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
    fetchQueue.qualityOfService = .userInitiated
    fetchQueue.maxConcurrentOperationCount = Constants.ConcurrentFetchesAtATime
  }
  
  // Idea here is that each object can at most only have 1 operation per priority
  func queue(_ operation: FoodieOperation, at priority: Operation.QueuePriority) {  // We can later make an intermediary sublcass to make it more diverse across any objects. Eg. Prefetch User Objects, etc
    
    var dispatchPriority = DispatchQoS.QoSClass.utility
    if priority.rawValue >= Operation.QueuePriority.high.rawValue {
      dispatchPriority = .userInitiated
    }
    
    DispatchQueue.global(qos: dispatchPriority).async {
      guard let storyOp = operation as? StoryOperation, let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType else {
        CCLog.fatal("Expecting storyOp, story and type")
      }
      
      #if DEBUG
        CCLog.info("#Prefetch - Queuing Story \(story.getUniqueIdentifier()) for \(type.rawValue) operation. Queue now at \(self.fetchQueue.operationCount + 1) outstanding")
      #else
      CCLog.debug("Queuing Story \(story.getUniqueIdentifier()) for \(type.rawValue) operation. Queue now at \(self.fetchQueue.operationCount + 1) outstanding")
      #endif
    
      operation.queuePriority = priority
      operation.completionBlock = {
        #if DEBUG
          CCLog.info("#Prefetch - Completion for Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue now at \(self.fetchQueue.operationCount) outstanding")
        #else
          CCLog.debug("Completion for Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue now at \(self.fetchQueue.operationCount) outstanding")
        #endif
      }
      self.fetchQueue.addOperation(operation)
    }
  }
  
  func cancel(for object: AnyObject) {

    DispatchQueue.global(qos: .utility).async {
      for operation in self.fetchQueue.operations {
        if let storyOp = operation as? StoryOperation {
          if storyOp.object === object {
            
            if let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType {
            #if DEBUG
              CCLog.info("#Prefetch - Cancel Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue at \(self.fetchQueue.operationCount) outstanding before cancel")
            #else
              CCLog.debug("Completion Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue now at \(self.fetchQueue.operationCount) outstanding")
            #endif
            } else {
              CCLog.warning("storyOp.object not a story!")
            }
            storyOp.cancel()
          }
        }
      }
    }
  }
  
  func cancelAllButOne(_ object: AnyObject) {
    
    DispatchQueue.global(qos: .utility).async {
      guard let story = object as? FoodieStory else {
        CCLog.fatal("Expected object to be of FoodieStory type")
      }
      #if DEBUG
        CCLog.info("#Prefetch - Cancel All but Story \(story.getUniqueIdentifier()). Queue at \(self.fetchQueue.operationCount) outstanding before cancel")
      #else
        CCLog.debug("Cancel All but Story \(story.getUniqueIdentifier()). Queue at \(self.fetchQueue.operationCount) outstanding before cancel")
      #endif
      
      var needsToPrefetchNextMoment = true
      
      for operation in self.fetchQueue.operations {
        if let storyOp = operation as? StoryOperation {
          
          // Cancel anything that is not of the current story
          if storyOp.object !== object {
            
            if let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType {
              #if DEBUG
                CCLog.info("#Prefetch - Cancel Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue at \(self.fetchQueue.operationCount) outstanding before cancel")
              #else
                CCLog.debug("Cancel Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue now at \(self.fetchQueue.operationCount) outstanding")
              #endif
            }  else {
              CCLog.warning("storyOp.object not a story!")
            }
            storyOp.cancel()
            
          } else if let operationType = storyOp.type as? StoryOperation.OperationType, operationType == .next {
            needsToPrefetchNextMoment = false
          }
        }
      }
      
      if needsToPrefetchNextMoment {
        CCLog.info("Expected that there should already be a Story Prefech.next for \(story.getUniqueIdentifier()), but didn't. Executing one now")
        let momentOperation = StoryOperation.createRecursive(with: .next, on: story, at: .low)
        self.queue(momentOperation, at: .low)
      }
    }
  }
  
  
  // Object list should be sorted in decending order of priority for Pre-fetching
  func cancelAllBut(_ objects: [AnyObject]) {
    DispatchQueue.global(qos: .utility).async {
      guard var stories = objects as? [FoodieStory] else {
        CCLog.fatal("Expected objects to be of FoodieStory type")
      }
      
      var debugStoryIdentifiers = "Story Identifiers:"
      for story in stories {
        debugStoryIdentifiers += " \(story.getUniqueIdentifier())"
      }
      
      #if DEBUG
        CCLog.info("#Prefetch - Cancel All aside from the following Stories. Queue at \(self.fetchQueue.operationCount) outstanding before cancel")
        CCLog.info("#Prefetch - \(debugStoryIdentifiers)")
      #else
        CCLog.debug("Cancel All but Story \(story.getUniqueIdentifier()). Queue at \(self.fetchQueue.operationCount) outstanding before cancel")
        CCLog.debug(debugStoryIdentifiers)
      #endif
      
      //var storiesNeedingPrefetch = stories
      
      for operation in self.fetchQueue.operations {
        if let storyOp = operation as? StoryOperation {
          
          guard let story = storyOp.object as? FoodieStory, let type = storyOp.type as? StoryOperation.OperationType else {
            CCLog.fatal("storyOp.object not a story!")
          }
          
          // Cancel anything that is not of the current story
          if !objects.contains(where: { $0 === storyOp.object }) {
            
            #if DEBUG
              CCLog.info("#Prefetch - Cancel Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue at \(self.fetchQueue.operationCount) outstanding before cancel")
            #else
              CCLog.debug("Cancel Story \(story.getUniqueIdentifier()) on \(type.rawValue) operation. Queue now at \(self.fetchQueue.operationCount) outstanding")
            #endif
            storyOp.cancel()
            
          } else if type == .next {
            if let indexToRemove = stories.index(where: { $0 === story } ) {
              stories.remove(at: indexToRemove)
            }
          }
        }
      }
      
      if stories.count > 0 {
        debugStoryIdentifiers = "StoryIdentifiers:"
        
        for story in stories {
          let momentOperation = StoryOperation.createRecursive(with: .first, on: story, at: .low)
          self.queue(momentOperation, at: .low)
          debugStoryIdentifiers += " \(story.getUniqueIdentifier())"
        }
      
        #if DEBUG
          CCLog.info("#Prefetch - Expected that there should already be Story Prefech.next for the following Stories, but didn't. Executing them now")
          CCLog.info("#Prefetch - \(debugStoryIdentifiers)")
        #else
          CCLog.debug("Expected that there should already be Story Prefech.next for the following Stories, but didn't. Executing them now")
          CCLog.debug("debugStoryIdentifiers")
        #endif
      }
    }
  }
  
  
  func cancelAll() {
    CCLog.info("Cancelling All Prefetch Operations!")
    fetchQueue.cancelAllOperations()
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











