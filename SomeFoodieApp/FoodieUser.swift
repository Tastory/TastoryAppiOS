//
//  FoodieUser.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-03.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//


import Parse

class FoodieUser: PFUser {

  @NSManaged var displayName: String?
  @NSManaged var firstName: String?
  @NSManaged var lastName: String?
  @NSManaged var url: String?
  
  @NSManaged var journalsViewed: Int
  @NSManaged var momentsViewed: Int
  
}
