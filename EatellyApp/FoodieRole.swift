//
//  FoodieRole.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-09-28.
//  Copyright © 2017 Eatelly. All rights reserved.
//


import Parse


class FoodieRole: PFRole {
  
  @NSManaged var level: Int
  
  // MARK: - Types & Enumerations
  enum Level: Int {
    case limitedUser = 10
    case user = 20
//    case eliteUser = 30
//    case premiumUser = 40
//    case venue = 100
//    case premiumVenue = 110
    case moderator = 300
//    case moderatorLvl2 = 310
//    case moderatorlvl3 = 320
    case admin = 400
//    case adminLvl2 = 410
//    case adminLvl3 = 420
    case superAdmin = 500
    
    var name: String {
      switch self {
      case .limitedUser:  return "Limited User"
      case .user:         return "User"
      case .moderator:    return "Moderator"
      case .admin:        return "Administrator"
      case .superAdmin:   return "Super Administrator"
      }
    }
  }
}
