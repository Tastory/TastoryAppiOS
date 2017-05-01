//
//  FoodieObject.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-05.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

import Parse

/****************************************************************/
/*                                                              */
/*     Do not attempt to register this class against Parse!     */
/*                                                              */
/****************************************************************/

class FoodieObject: PFObject {  // Abstract
  
  // The following tracks status of the FoodieObjects. All potential statuses are tentative
  // Was considering bit-wise statuses, but probably too complicated for high level programming
  @NSManaged var statusInMemory: Bool
  @NSManaged var statusInLocal: Bool
  @NSManaged var statusInNetwork: Bool
  @NSManaged var statusPendingLoad: Bool  // This is referring to load from local disk
  @NSManaged var statusPendingDownload: Bool  // This is referring to downloading from networked backend
  @NSManaged var statusPendingDelete: Bool
  @NSManaged var statusPendingSave: Bool  // This is referring save to local
  @NSManaged var statusPendingSync: Bool  // This is referring to sync to networked backend
}
