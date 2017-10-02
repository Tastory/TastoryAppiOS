//
//  FoodieRole.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-09-28.
//  Copyright © 2017 Tastry. All rights reserved.
//


import Parse


class FoodieRole {
  
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
//    case superAdmin = 500
    
    var name: String {
      switch self {
      case .limitedUser:  return "Limited User"
      case .user:         return "User"
      case .moderator:    return "Moderator"
      case .admin:        return "Administrator"
      }
    }
  }
  
  
  // MARK: - Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case addUserFoundNonRole
    case addUserFoundNot1Role
    
    var errorDescription: String? {
      switch self {
      case .addUserFoundNonRole:
        return NSLocalizedString("Find Role during addUser() returned non PFRole object", comment: "Error description when trying to addUser to a Role")
      case .addUserFoundNot1Role:
        return NSLocalizedString("Find Role during addUser() returned not exactly 1 role", comment: "Error desciprtion when trying to addUser to a Role")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Public Static Functions
  static func addUser(_ user: FoodieUser, to level: Level, withBlock callback: SimpleErrorBlock?) {
    
    // Just go ahead. Let the Server reject and return error if the user doesn't have the required permission to do so
    guard let query = PFRole.query() else {
      CCLog.fatal("Can't even create a Parse Query")
    }
    
    query.whereKey("name", equalTo: level.name)
    query.findObjectsInBackground { (objects, error) in
      
      if let error = error {
        CCLog.assert("Failed to find role for '\(level.name)' in background - \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      guard let roles = objects as? [PFRole] else {
        CCLog.assert("Find role for '\(level.name)' in background returned non-PFRole object")
        callback?(ErrorCode.addUserFoundNonRole)
        return
      }
      
      guard roles.count == 1 else {
        CCLog.assert("Find role for '\(level.name)' in background returned \(roles.count) roles instead of 1")
        callback?(ErrorCode.addUserFoundNot1Role)
        return
      }
      
      // Finally add the user to the role
      let role = roles[0]
      role.users.add(user as PFUser)
      
      // Now save the role
      role.saveInBackground { (success, error) in
        FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback)
      }
    }
  }
  
}
