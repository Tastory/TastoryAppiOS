//
//  FoodieCategory.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//


import Parse

class FoodieCategory: FoodiePFObject {

  // MARK: - Public Instance Variable
  var foodieObject = FoodieObject()
  
  
  // MARK: - Public Instance Functions
  override init() {
    super.init()
    foodieObject.delegate = self
  }
}


// MARK: - Foodie Object Delegate Conformance
extension FoodieCategory: FoodieObjectDelegate {
  
  // Function for processing a completion from a child save
  func saveCompletionFromChild(to location: FoodieObject.StorageLocation,
                               withName name: String?,
                               withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    foodieObject.savesCompletedFromAllChildren(to: location, withName: name, withBlock: callback)
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     withName name: String?,
                     withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
    if let earlyReturnStatus = foodieObject.saveStateTransition(to: location) {
      DispatchQueue.global(qos: .userInitiated).async { callback?(earlyReturnStatus, nil) }
    }
  }
  
  
  // Trigger recursive saves against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       withName name: String?,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
  }
}


extension FoodieCategory: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieCategory"
  }
}
