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
    var timerUUID: UInt32 = 0
    var heldtimer: Timer?
    var blocktimer: Timer?
    var tryFailedFor: Int = 0
    var lockHoldingFunction: String = ""
    var lockHoldingFile: String = ""
    var lockHoldingLine: Int = 0
    
    
    // MARK: - Public Instance Functions
    init() {
      var rtn = pthread_mutexattr_init(&attr)
      if rtn != 0 { CCLog.assert("pthread_mutexattr_init() returned \(rtn)") }
      
      rtn = pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ERRORCHECK)
      if rtn != 0 { CCLog.assert("pthread_mutexaatr_settype() returned \(rtn)") }
      
      rtn = pthread_mutexattr_setprotocol(&attr, PTHREAD_PRIO_INHERIT)
      if rtn != 0 { CCLog.assert("pthread_mutexattr_setprotocol() returned \(rtn)") }
      
      rtn = pthread_mutex_init(&core, &attr)
      if rtn != 0 { CCLog.assert("pthread_mutex_init() returned \(rtn)") }
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
          tryFailedFor += 1
          
          if blocktimer == nil {
            blocktimer = Timer.scheduledTimer(withTimeInterval: Constant.secondsMutexConsideredTooLong,
                                              repeats: true) { timer in
              CCLog.warning("\(thread)Blocked by mutex held by function: \(self.lockHoldingFunction), file: \(self.lockHoldingFile), line: \(self.lockHoldingLine) for +100ms", function: function, file: file, line: line)
            }
            
          } else if tryFailedFor >= Constant.tryStopLimit {
            CCLog.fatal("Try returned \(rtn). \(thread)Mutex held by function: \(lockHoldingFunction), file: \(lockHoldingFile), line: \(lockHoldingLine) for +100ms", function: function, file: file, line: line)
            
          } else if tryFailedFor >= Constant.tryLogLimit {
            CCLog.debug("Try returned \(rtn). \(thread)Mutex held by function: \(lockHoldingFunction), file: \(lockHoldingFile), line: \(lockHoldingLine) for +100ms", function: function, file: file, line: line)

          } else {
            usleep(Constant.trySleepPeriodus)
          }
        }
      } while rtn != 0
      
      // Got the lock, invalidate block timer if it was started
      if let timer = blocktimer {
        timer.invalidate()
        blocktimer = nil
      }
      
      // Start the timer measuring how long this lock is going to be held
      timerUUID = arc4random()
      CCLog.verbose("Lock heldTimer UUID - \(timerUUID)")
      heldtimer = Timer.scheduledTimer(withTimeInterval: Constant.secondsMutexConsideredTooLong,
                                       repeats: true) { timer in
        CCLog.warning("\(thread)Held mutex for +100ms", function: function, file: file, line: line)
      }
      
      // Record whose the lock holder
      lockHoldingFunction = function
      lockHoldingFile = file
      lockHoldingLine = line
    }
    
    func unlock() {
      let rtn = pthread_mutex_unlock(&core)
      if rtn != 0 {
        CCLog.assert("pthread_mutex_unlock returned \(rtn)")
      }
      // Stop the holding timer
      CCLog.verbose("Unlock heldTimer UUID - \(timerUUID)")
      if let timer = heldtimer {
        timer.invalidate()
        heldtimer = nil
      }
      // Remove lock hold tracking variables
      lockHoldingFile = ""
      lockHoldingFunction = ""
      lockHoldingLine = 0
    }
  }
  
  // MARK: - Constants
  struct Constant {
    fileprivate static let secondsMutexConsideredTooLong = 0.1
    fileprivate static let trySleepPeriodus: UInt32 = 25000  // Put in some sleep between lock retries. Set at 25ms each
    fileprivate static let tryLogLimit = 4  // Log that lock is held too long at the +100ms mark
    fileprivate static let tryStopLimit = 120  // Kill the app if a lock is held for 3 seconds
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
    if rtn != 0 { CCLog.assert("pthread_mutexattr_init() returned \(rtn)") }
    
    rtn = pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ERRORCHECK)
    if rtn != 0 { CCLog.assert("pthread_mutexaatr_settype() returned \(rtn)") }
    
    rtn = pthread_mutexattr_setprotocol(&attr, PTHREAD_PRIO_INHERIT)
    if rtn != 0 { CCLog.assert("pthread_mutexattr_setprotocol() returned \(rtn)") }
    
    rtn = pthread_mutex_init(&mutex, &attr)
    if rtn != 0 { CCLog.assert("pthread_mutex_init() returned \(rtn)") }
    
    return mutex
  }
  
  // MARK: - Public Static Functions
  static func lock(_ pointer: UnsafeMutablePointer<SwiftMutex.Instance>) {
    let lockValue = pthread_mutex_lock(pointer)
    if lockValue != 0 {
      CCLog.assert("pthread_mutex_lock returned \(lockValue)")
    }
  }
  
  static func unlock(_ pointer: UnsafeMutablePointer<SwiftMutex.Instance>) {
    let unlockValue = pthread_mutex_unlock(pointer)
    if unlockValue != 0 {
      CCLog.assert("pthread_mutex_unlock returned \(unlockValue)")
    }
  }
  
  #endif
}
