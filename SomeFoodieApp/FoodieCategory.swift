//
//  FoodieCategory.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//


import Parse

class FoodieCategory: FoodieObject {

}


extension FoodieCategory: PFSubclassing {
  static func parseClassName() -> String {
    return "foodieCategory"
  }
}
