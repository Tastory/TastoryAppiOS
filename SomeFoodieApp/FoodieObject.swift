//
//  FoodieObject.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-05.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import Parse


// This is intended to never have an instance - aka Abstract. However there is no abstract class in Swift
class FoodieObject: PFObject {
  
  // The following tracks status of the FoodieObjects. All potential statuses are tentative
  @NSManaged var statusInMemory: Bool
  @NSManaged var statusInLocal: Bool
  @NSManaged var statusInNetwork: Bool
  @NSManaged var statusPendingLoad: Bool  // This is referring to load from local disk
  @NSManaged var statusPendingDownload: Bool  // This is referring to downloading from networked backend
  @NSManaged var statusPendingDelete: Bool
  @NSManaged var statusPendingSave: Bool  // This is referring save to local
  @NSManaged var statusPendingSync: Bool  // This is referring to sync to networked backend
}
