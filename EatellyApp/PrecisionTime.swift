//
//  PrecisionTime.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-06-22.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import Foundation

class PrecisionTime: Comparable {
  
  // MARK: - Public Instance Variables
  var ticks: UInt64 {
    return tickValue
  }
  
  var seconds: Float {
    return Float(getNanoSeconds()) / 1000000000.0
  }
  
  var milliSeconds: Float {
    return Float(getNanoSeconds()) / 1000000.0
  }
  
  var microSeconds: Float {
    return Float(getNanoSeconds()) / 1000.0
  }
  
  var nanoSeconds: UInt64 {
    return getNanoSeconds()
  }

  
  // MARK: - Private Instance Variables
  private let tickValue: UInt64
  

  // MARK: - Public Static Functions
  static func now() -> PrecisionTime {
    return PrecisionTime(ticks: mach_absolute_time())
  }
  
  // This gives the absolute difference between the two times
  static func diff(timeOne: PrecisionTime, timeTwo: PrecisionTime) -> PrecisionTime {
    var earlierTicks: UInt64 = 0
    var laterTicks: UInt64 = 0
    
    if timeOne.ticks > timeTwo.ticks {
      laterTicks = timeOne.ticks
      earlierTicks = timeTwo.ticks
    } else {
      laterTicks = timeTwo.ticks
      earlierTicks = timeOne.ticks
    }
    
    return PrecisionTime(ticks: (laterTicks - earlierTicks))
  }
  
  static func ==(left: PrecisionTime, right: PrecisionTime) -> Bool {
    if left.ticks == right.ticks {
      return true
    } else {
      return false
    }
  }
  
  static func <(left: PrecisionTime, right: PrecisionTime) -> Bool {
    if left.ticks < right.ticks {
      return true
    } else {
      return false
    }
  }
  
  static func +(left: PrecisionTime, right: PrecisionTime) -> PrecisionTime {
    let sumOfTicks = left.ticks + right.ticks
    return PrecisionTime(ticks: sumOfTicks)
  }
  
  static func -(left: PrecisionTime, right: PrecisionTime) -> PrecisionTime {
    if left < right {
      CCLog.fatal("PrecisionTime left operator smaller than right in attempt to subtract. Fatal Error.")
    }
    return PrecisionTime(ticks: (left.ticks - right.ticks))
  }

  
  // MARK: - Public Instance Functions
  init(ticks: UInt64) {
    tickValue = ticks
  }
  

  // MARK: - Private Instance Functions
  private func getNanoSeconds() -> UInt64 {
    var timeBaseInfo = mach_timebase_info_data_t()
    mach_timebase_info(&timeBaseInfo)
    return tickValue * UInt64(timeBaseInfo.numer) / UInt64(timeBaseInfo.denom)
  }
}
