//
//  FoodieMarkup.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

// Class object to for Markups on Moments
// TODO: To be implemented on later revisions

import Parse

class FoodieMarkup: FoodieObject {
  
}


extension FoodieMarkup: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieMarkup"
  }
}
