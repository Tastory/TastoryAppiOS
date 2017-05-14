//
//  FoodieHistory.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

// Class object to track each user's interaction with each Journal. View, clickthroughs, ratings, etc.
// TODO: To be implemented on later revisions

import Parse

class FoodieHistory: FoodieObject {
  
  @NSManaged var journal: FoodieJournal?
  @NSManaged var eatery: FoodieEatery?
  @NSManaged var user: FoodieUser?
  @NSManaged var journalRating: Double // TODO: Placeholder for later rev
  @NSManaged var eateryRating: Double // TODO: Placeholder for later rev
  
  // Date created vs Date modified is given for free
}


extension FoodieHistory: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieHistory"
  }
}
