//
//  SwiftMutex.swift
//  EatellyApp
//  Super thin struct around C Mutexes
//
//  Created by Howard Lee on 2017-08-30.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import Foundation

struct SwiftMutex {
  
  typealias Instance = pthread_mutex_t
  
  static func lock(_ pointer: UnsafeMutablePointer<pthread_mutex_t>) -> Int32 {
    #if DEBUG
      if Thread.isMainThread {
        DebugPrint.assert("Mutex lock executed out of Main Thread")
      }
    #endif
    return pthread_mutex_lock(pointer)
  }
  
  static func unlock(_ pointer: UnsafeMutablePointer<pthread_mutex_t>) -> Int32 {
    return pthread_mutex_unlock(pointer)
  }
}
