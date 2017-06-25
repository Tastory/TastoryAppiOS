//
//  FoodiePrefetch.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-06-24.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import Foundation


protocol FoodiePrefetchDelegate {
  
  func doPrefetch(on objectToFetch: AnyObject, for context: FoodiePrefetch.Context, withBlock callback: FoodiePrefetch.PrefetchCompletionBlock)
  
}


class FoodiePrefetch {
  
  // MARK: - Types & Enumerations
  typealias PrefetchCompletionBlock = (Context) -> Void
  
  
  // MARK: - Structs
  class Context {
    var contextPointerMutex = pthread_mutex_t()
    var prevContext: Context?
    var nextContext: Context?
    var delegate: FoodiePrefetchDelegate!
    var objectToFetch: AnyObject!
  }
  
  
  // MARK: - Public Static Variables
  static var global = FoodiePrefetch()
  
  
  // MARK: - Private Instance Variables
  fileprivate var blockCountMutex = pthread_mutex_t()
  fileprivate var blockCount = 0
  fileprivate var workQueueMutex = pthread_mutex_t()
  fileprivate var headOfWorkQueue: Context? = nil
  fileprivate var tailOfWorkQueue: Context? = nil
  
  
  // MARK: - Public Instance Function
  func prefetchNextIfNoBlock() {
    
    var letsFetch = false
    
    // Just sample the block to determine whether to fetch or not
    pthread_mutex_lock(&blockCountMutex)
    if blockCount == 0 { letsFetch = true }
    pthread_mutex_unlock(&blockCountMutex)
    
    if letsFetch {
      
      var workingContext: Context!
      var delegate: FoodiePrefetchDelegate!
      var objectToFetch: AnyObject!
      
      pthread_mutex_lock(&workQueueMutex)
      
      // Issue a Prefetch if the Work Queue is not empty
      if headOfWorkQueue != nil {
        workingContext = headOfWorkQueue
        delegate = workingContext.delegate
        objectToFetch = workingContext.objectToFetch
      } else {
        return
      }
      
      pthread_mutex_unlock(&workQueueMutex)

      delegate.doPrefetch(on: objectToFetch, for: workingContext){ (context) in
        
        // Prefetch completes. Remove if not already removed
        removePrefetchWork(for: context)
        
        // Do another prefetch if no block
        prefetchNextIfNoBlock()
      }
    }
  }
  
  
  func blockPrefetching() {
    pthread_mutex_lock(&blockCountMutex)
    blockCount += 1
    pthread_mutex_unlock(&blockCountMutex)
  }
  
  
  func unblockPrefetching() {
    pthread_mutex_lock(&blockCountMutex)
    blockCount -= 1
    pthread_mutex_unlock(&blockCountMutex)
    
    prefetchNextIfNoBlock()
  }
  
  
  func addPrefetchWork(for delegate: FoodiePrefetchDelegate, on objectToFetch: AnyObject) -> Context {
    
    let newContext = Context()
    newContext.delegate = delegate
    newContext.objectToFetch = objectToFetch
    newContext.nextContext = nil
    
    pthread_mutex_lock(&workQueueMutex)
    newContext.prevContext = tailOfWorkQueue
    
    if tailOfWorkQueue == nil {
      if headOfWorkQueue != nil {
        DebugPrint.fatal("headOfWorkQueue not nil when tailOfWorkQueue is nil")
      }
      headOfWorkQueue = newContext
      tailOfWorkQueue = newContext
    } else {
      tailOfWorkQueue!.nextContext = newContext
      tailOfWorkQueue = newContext
    }
    pthread_mutex_unlock(&workQueueMutex)
    
    // Kick off prefetch if no block
    prefetchNextIfNoBlock()
    
    return newContext
  }
  
  
  func removePrefetchWork(for context: Context) {
    
    pthread_mutex_lock(&workQueueMutex)
    
    if context.objectToFetch == nil {
      // Already removed, so just return
      pthread_mutex_unlock(&workQueueMutex)
      return
    }
    
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
    
    pthread_mutex_unlock(&workQueueMutex)
  }
  
  
  
  
  
  
  
  
  
  
  
}
