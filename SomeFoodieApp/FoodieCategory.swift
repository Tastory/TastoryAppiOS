//
//  FoodieCategory.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//


import Parse

class FoodieCategory: FoodiePFObject, FoodieObjectDelegate {
  
  // MARK: - Public Instance Functions
  
  // This is the Initilizer Parse will call upon Query or Retrieves
  override init() {
    super.init(withState: .notAvailable)
    foodieObject.delegate = self
  }
  
  
  // This is the Initializer we will call internally
  override init(withState operationState: FoodieObject.OperationStates) {
    super.init(withState: operationState)
    foodieObject.delegate = self
  }


  // MARK: - Foodie Object Delegate Conformance

  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(forceAnyways: Bool = false, withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    
    // Retrieve self. This object have no children
    retrieve(forceAnyways: forceAnyways, withBlock: callback)
  }
  
  
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
