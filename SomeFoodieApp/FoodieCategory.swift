//
//  FoodieCategory.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//


import Parse

class FoodieCategory: FoodiePFObject, FoodieObjectDelegate {

  // MARK: - Public Instance Variable
  var foodieObject = FoodieObject()
  
  
  // MARK: - Public Instance Functions
  override init() {
    super.init()
    foodieObject.delegate = self
  }


  // MARK: - Foodie Object Delegate Conformance

  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     withName name: String?,
                     withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
    
    if let earlySuccess = earlyReturnStatus.success {
      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
      return
    }
  }
  
  
  // Trigger recursive saves against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       withName name: String?,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    DebugPrint.verbose("FoodieCategory.deleteRecursive from Location: \(location)")
    foodieObject.deleteRecursiveBasicBehavior(from: location, withBlock: callback)
  }
  
  func getNextDeleteObject() -> FoodieObjectDelegate? {
    return foodieObject.getNextDeleteObject()
  }
  
  func setNextDeleteObject(_ deleteObj: FoodieObjectDelegate) {
    foodieObject.setNextDeleteObject(deleteObj)
  }
  
  func verbose() {
    
  }
  
  
  func foodieObjectType() -> String {
    return "FoodieCategory"
  }
}


extension FoodieCategory: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieCategory"
  }
}
