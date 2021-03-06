//
//  Date+Extension.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2017-12-11.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
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

  func dayOfTheWeek() -> String {
    let weekdays = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Satudrday"
    ]
    return weekdays[Calendar.current.component(.weekday, from: Date()) - 1]
  }
}
