//
//  FoodiePermission.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-09-29.
//  Copyright © 2017 Eatelly. All rights reserved.
//  This is sort of a helper class for the other Foodie Classes
//

//
//  How Permissions works for Objects
//
//   Objects shall be readable by everyone  - This is to faciliate Guest Users
//   Objects shall be writable by the author
//   Objects created by roles below Moderators shall be writeable by Moderators or above
//   Objects by Moderators or above shall be writable by any roles higher than them
//   Objects by Admin shall be writeable by each other
//
//
//  How Permission works for Users
//
//   Users shall be readable by everyone.  - This is to faciliate looking at people's profiles
//   Users shall be writable by the User themselves
//   Users with roles below Moderators shall be writeable by Moderators or above
//   Moderators or above shall be writable by any roles higher than them
//   Admins are not able to write into each other
//
//  
//  How Roles works
//
//   On the Parse DB side. Roles are hard defined through the Dashboard, with Limited User ACL set so anyone can write, this is so anyboduy can sign-up as a Limited User
//   Role inheritence is setup all the way from Limited User to Admin
//   There is also Class Level Permission settings for all the Foodie Object classes so there's Public Read, but only Write if you are Limited User or above
//
//
//  Limiting 'Limited User's audience
//   
//   This is done through the Query side. It's hard coded that one can only query items of their own, or ones created by regular Users or above
//
//


import Parse

class FoodiePermission : PFACL {

  // MARK: - Public Static Functions
  
  // Set Default Global Permission when PFObjects are created
  static func setDefaultGlobalObjectPermission() {
    let defaultACL = PFACL()
    defaultACL.getPublicReadAccess = true
    defaultACL.getPublicWriteAccess = false
    defaultACL.setWriteAccess(true, forRoleWithName: FoodieRole.Level.moderator.name)  // Users of Role with Moderator or above have Write Access by Default
    PFACL.setDefault(defaultACL, withAccessForCurrentUser: true)
  }
  

  static func setDefaultObjectPermission(for user: FoodieUser) {
    let defaultACL = PFACL(user: user)
    defaultACL.getPublicReadAccess = true
    defaultACL.getPublicWriteAccess = false
    
    if user.roleLevel < FoodieRole.Level.moderator.rawValue {
      defaultACL.setWriteAccess(true, forRoleWithName: FoodieRole.Level.moderator.name)
    }
      
    else if user.roleLevel <= FoodieRole.Level.admin.rawValue {
      defaultACL.setWriteAccess(true, forRoleWithName: FoodieRole.Level.admin.name)
    }
    
    PFACL.setDefault(defaultACL, withAccessForCurrentUser: true)
  }
  
  
  static func getDefaultUserPermission(for user: FoodieUser) -> FoodiePermission {
    let userPermission = FoodiePermission(user: user as PFUser) // For surely able to convert to PFUser object because FoodieUser is a sublcass of PFUser
    userPermission.getPublicReadAccess = true
    userPermission.getPublicWriteAccess = false
    
    if user.roleLevel < FoodieRole.Level.moderator.rawValue {
      userPermission.setWriteAccess(true, forRoleWithName: FoodieRole.Level.moderator.name)
    }
    
    else if user.roleLevel < FoodieRole.Level.admin.rawValue {  // Admin can't change each other's settings. Will require root/Master access
      userPermission.setWriteAccess(true, forRoleWithName: FoodieRole.Level.admin.name)
    }
    
    return userPermission
  }
}

