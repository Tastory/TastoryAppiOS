//
//  FoodieMarkup.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

// Class object to for Markups on Moments
// TODO: To be implemented on later revisions

import Parse

class FoodieMarkup: FoodieObject {
  // @NSManaged var markupText: String  // Unicode, so Emoji allowed?
  // @NSMnaaged var fontSize: Int
  // @NSManaged var markupGif: PFFile?
  // @NSManaged var frameX: Double
  // @NSManaged var frameY: Double
  // @NSManaged var frameWidth: Double
  // @NSManaged var frameHeight: Double
  // @NSManaged var frameAngle: Double
}


extension FoodieMarkup: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieMarkup"
  }
}
