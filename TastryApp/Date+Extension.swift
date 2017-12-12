//
//  Date+Extension.swift
//  TastryApp
//
//  Created by Victor Tsang on 2017-12-11.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Foundation

extension Date {
  var yesterday: Date {
    return Calendar.current.date(byAdding: .day, value: -1, to: noon)!
  }
  var tomorrow: Date {
    return Calendar.current.date(byAdding: .day, value: 1, to: noon)!
  }
  var noon: Date {
    return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
  }
  
  func offsetToNoon(byNumberOfDays numberOfDays: Int) -> Date {
    return Calendar.current.date(byAdding: .day, value: numberOfDays, to: noon)!
  }
}
