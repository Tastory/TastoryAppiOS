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
  
  #if DEBUG
  
  // MARK: - Types & Enumeration
  class Instance {
    var core = pthread_mutex_t()
    var attr = pthread_mutexattr_t()
    var heldtimer: Timer?
    var blocktimer: Timer?
    var elapsed = 0
    
    init() {
      var rtn = pthread_mutexattr_init(&attr)
      if rtn != 0 { DebugPrint.assert("pthread_mutexattr_init() returned \(rtn)") }
      
      rtn = pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ERRORCHECK)
      if rtn != 0 { DebugPrint.assert("pthread_mutexaatr_settype() returned \(rtn)") }
      
      rtn = pthread_mutexattr_setprotocol(&attr, PTHREAD_PRIO_INHERIT)
      if rtn != 0 { DebugPrint.assert("pthread_mutexattr_setprotocol() returned \(rtn)") }
      
      rtn = pthread_mutex_init(&core, &attr)
      if rtn != 0 { DebugPrint.assert("pthread_mutex_init() returned \(rtn)") }
    }
    
    func lock(function: String = #function, file: String = #file, line: Int = #line) {
      
      var thread: String = ""
      
      // Indicate it's Main thread when lock held/blocked for too long
      if Thread.isMainThread {
        thread = "Main Thread "
      }
      
      // Try the lock first. Start block timer if fails. Then keep trying the lock
      var rtn: Int32 = 0
      repeat {
        rtn = pthread_mutex_trylock(&core)
        if rtn != 0 {
          DebugPrint.log("Mutex Lock Value Returned \(rtn) on \(thread)", function: function, file: file, line: line)
          if blocktimer == nil {
            blocktimer = Timer.scheduledTimer(withTimeInterval: Constant.secondsMutexConsideredTooLong,
                                              repeats: true) { timer in
                                                DebugPrint.error("\(thread)Blocked by mutex for +100ms", function: function, file: file, line: line)
            }
          } else {
            usleep(Constant.tryLockSleepPeriodus)
          }
        }
      } while rtn != 0
      
      // Got the lock, invalidate block timer if it was started
      if let timer = blocktimer {
        timer.invalidate()
      }
      
      // Start the timer measuring how long this lock is going to be held
      heldtimer = Timer.scheduledTimer(withTimeInterval: Constant.secondsMutexConsideredTooLong,
                                       repeats: true) { timer in
                                        DebugPrint.error("\(thread)Held mutex for +100ms", function: function, file: file, line: line)
      }
    }
    
    func unlock() {
      let rtn = pthread_mutex_unlock(&core)
      if rtn != 0 {
        DebugPrint.assert("pthread_mutex_unlock returned \(rtn)")
      }
      // Stop the holding timer
      if let timer = heldtimer {
        timer.invalidate()
      }
    }
  }
  
  // MARK: - Constants
  struct Constant {
    fileprivate static let secondsMutexConsideredTooLong = 0.1
    fileprivate static let tryLockSleepPeriodus: UInt32 = 30000
  }
  
  // MARK: - Public Static Functions
  static func create() -> Instance {
    return Instance()
  }
  
  static func lock(_ instance: UnsafeMutablePointer<SwiftMutex.Instance>, function: String = #function, file: String = #file, line: Int = #line) {
    instance.pointee.lock(function: function, file: file, line: line)
  }
  
  static func unlock(_ instance: UnsafeMutablePointer<SwiftMutex.Instance>) {
    instance.pointee.unlock()
  }
  
  #else
  
  // MARK: - Types & Enumeration
  typealias Instance = __darwin_pthread_mutex_t
  
  static func create() -> Instance {
    var mutex = pthread_mutex_t()
    var attr = pthread_mutexattr_t()
    
    var rtn = pthread_mutexattr_init(&attr)
    if rtn != 0 { DebugPrint.assert("pthread_mutexattr_init() returned \(rtn)") }
    
    rtn = pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ERRORCHECK)
    if rtn != 0 { DebugPrint.assert("pthread_mutexaatr_settype() returned \(rtn)") }
    
    rtn = pthread_mutexattr_setprotocol(&attr, PTHREAD_PRIO_INHERIT)
    if rtn != 0 { DebugPrint.assert("pthread_mutexattr_setprotocol() returned \(rtn)") }
    
    rtn = pthread_mutex_init(&mutex, &attr)
    if rtn != 0 { DebugPrint.assert("pthread_mutex_init() returned \(rtn)") }
    
    return mutex
  }
  
  // MARK: - Public Static Functions
  static func lock(_ pointer: UnsafeMutablePointer<SwiftMutex.Instance>) {
    let lockValue = pthread_mutex_lock(pointer)
    if lockValue != 0 {
      DebugPrint.assert("pthread_mutex_lock returned \(lockValue)")
    }
  }
  
  static func unlock(_ pointer: UnsafeMutablePointer<SwiftMutex.Instance>) {
    let unlockValue = pthread_mutex_unlock(pointer)
    if unlockValue != 0 {
      DebugPrint.assert("pthread_mutex_unlock returned \(unlockValue)")
    }
  }
  
  #endif
}
