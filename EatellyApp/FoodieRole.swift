//
//  FoodieRole.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-09-28.
//  Copyright © 2017 Eatelly. All rights reserved.
//


import Parse


class FoodieRole: PFRole {
  
  // MARK: - Types & Enumerations
  enum Level: Int {
    case limitedUser = 10
    case regularUser = 20
    case premiumUser = 30
    case venue = 40
    case premiumVenue = 50
    case moderatorLvl1 = 60
    case moderatorLvl2 = 70
    case moderatorlvl3 = 80
    case adminLvl1 = 90
    case adminLvl2 = 100
    case adminLvl3 = 110
    case superadmin = 120
  }
}
