//
//  FoodiePrefetch.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-06-24.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import Foundation


protocol FoodiePrefetchDelegate {
  
  func removePrefetchContexts()
  func doPrefetch(on objectToFetch: AnyObject, for context: FoodiePrefetch.Context, withBlock callback: FoodiePrefetch.PrefetchCompletionBlock?)
}


class FoodiePrefetch {
  
  // MARK: - Types & Enumerations
  typealias PrefetchCompletionBlock = (Context) -> Void
  
  
  // MARK: - Structs
  class Context {
    //var contextPointerMutex = SwiftMutex.create()
    var prevContext: Context?
    var nextContext: Context?
    var delegate: FoodiePrefetchDelegate!
    var objectToFetch: AnyObject!
  }
  
  
  // MARK: - Public Static Variables
  static var global: FoodiePrefetch!
  
  
  // MARK: - Private Instance Variables
  fileprivate var blockCountMutex = SwiftMutex.create()
  fileprivate var blockCount = 0
  fileprivate var workQueueMutex = SwiftMutex.create()
  fileprivate var headOfWorkQueue: Context? = nil
  fileprivate var tailOfWorkQueue: Context? = nil
  
  
  // MARK: - Public Instance Function
  func prefetchNextIfNoBlock() {
    
    CCLog.verbose("prefetchNextIfNoBlock")
    var letsFetch = false
    
    // Just sample the block to determine whether to fetch or not
    SwiftMutex.lock(&blockCountMutex)
    if blockCount == 0 { letsFetch = true }
    SwiftMutex.unlock(&blockCountMutex)
    
    if letsFetch {
      
      CCLog.verbose("prefetchNextIfNoBlock, letsFetch = true")
      
      var workingContext: Context!
      var delegate: FoodiePrefetchDelegate!
      var objectToFetch: AnyObject!
      
      SwiftMutex.lock(&workQueueMutex)
      
      // Issue a Prefetch if the Work Queue is not empty
      if headOfWorkQueue != nil {
        workingContext = headOfWorkQueue
        delegate = workingContext.delegate
        objectToFetch = workingContext.objectToFetch
      } else {
        SwiftMutex.unlock(&workQueueMutex)
        return
      }
      
      SwiftMutex.unlock(&workQueueMutex)
      CCLog.verbose("prefetchNextIfNoBlock, doPrefetch")
      delegate.doPrefetch(on: objectToFetch, for: workingContext) { context in
        
        // Prefetch completes. Remove if not already removed
        self.removePrefetchWork(for: context)
        
        // Do another prefetch if no block
        self.prefetchNextIfNoBlock()
      }
    }
  }
  
  
  func blockPrefetching() {
    SwiftMutex.lock(&blockCountMutex)
    blockCount += 1
    let debugCount = blockCount
    SwiftMutex.unlock(&blockCountMutex)
    
    CCLog.verbose("blockPrefetching up to blockCount of \(debugCount)")
  }
  
  
  func unblockPrefetching() {
    SwiftMutex.lock(&blockCountMutex)
    if blockCount >= 1 {
      blockCount -= 1
    }
    let debugCount = blockCount
    SwiftMutex.unlock(&blockCountMutex)
    
    CCLog.verbose("unblockPrefetching down to blockCount of \(debugCount)")
    prefetchNextIfNoBlock()
  }
  
  
  func addPrefetchWork(for delegate: FoodiePrefetchDelegate, on objectToFetch: AnyObject) -> Context {
    CCLog.verbose("addPrefetchWork")
    
    var firstInQueue = false
    let newContext = Context()
    newContext.delegate = delegate
    newContext.objectToFetch = objectToFetch
    newContext.nextContext = nil
    
    SwiftMutex.lock(&workQueueMutex)
    newContext.prevContext = tailOfWorkQueue
    
    if tailOfWorkQueue == nil {
      if headOfWorkQueue != nil {
        CCLog.fatal("headOfWorkQueue not nil when tailOfWorkQueue is nil")
      }
      headOfWorkQueue = newContext
      tailOfWorkQueue = newContext
      firstInQueue = true
    } else {
      tailOfWorkQueue!.nextContext = newContext
      tailOfWorkQueue = newContext
    }
    SwiftMutex.unlock(&workQueueMutex)
    
    // Kick off prefetch if first in queue and no block
    if firstInQueue {
      prefetchNextIfNoBlock()
    }
    return newContext
  }
  
  
  func removePrefetchWork(for context: Context) {
    CCLog.verbose("removePrefetchWork")
    SwiftMutex.lock(&workQueueMutex)
    
    if context.objectToFetch == nil {
      // Already removed, so just return
      SwiftMutex.unlock(&workQueueMutex)
      return
    }
    
    // Remove context pointer the delegate holds
    context.delegate.removePrefetchContexts()
    
    if context.prevContext != nil {
      // Context is not at head
      context.prevContext!.nextContext = context.nextContext
    } else {
      // Context is at head
      headOfWorkQueue = context.nextContext
    }
    
    if context.nextContext != nil {
      // Context is not at tail
      context.nextContext!.prevContext = context.prevContext
    } else {
      // Context is at tail
      tailOfWorkQueue = context.prevContext
    }

    // Nobody should be pointing at this context by now
    context.prevContext = nil
    context.nextContext = nil
    context.delegate = nil
    context.objectToFetch = nil
    
    SwiftMutex.unlock(&workQueueMutex)
  }
  
  
  func removeAllPrefetchWork() {
    CCLog.verbose("removeAllPrefetchWork")
    SwiftMutex.lock(&workQueueMutex)
    
    while headOfWorkQueue != nil {
      if let context = headOfWorkQueue {
        if context.objectToFetch != nil {
          
          // Remove context pointer the delegate holds
          context.delegate.removePrefetchContexts()
          
          // Context is at head
          headOfWorkQueue = context.nextContext
          
          if context.nextContext != nil {
            // Context is not at tail
            context.nextContext!.prevContext = context.prevContext
          } else {
            // Context is at tail
            tailOfWorkQueue = context.prevContext
          }
          
          // Nobody should be pointing at this context by now
          context.prevContext = nil
          context.nextContext = nil
          context.delegate = nil
          context.objectToFetch = nil
        }
      }
    }
    SwiftMutex.unlock(&workQueueMutex)
  }
  
}
