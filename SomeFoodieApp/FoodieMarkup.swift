//
//  FoodieMarkup.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//


import Parse

class FoodieMarkup: FoodiePFObject {
  // @NSManaged var markupText: String  // Unicode, so Emoji allowed?
  // @NSMnaaged var fontSize: Int
  // @NSManaged var markupGif: String?
  // @NSManaged var frameX: Double
  // @NSManaged var frameY: Double
  // @NSManaged var frameWidth: Double
  // @NSManaged var frameHeight: Double
  // @NSManaged var frameAngle: Double
  
  
  // MARK: - Public Instance Variable
  var foodieObject = FoodieObject()
  
  
  // MARK: - Public Instance Functions
  override init() {
    super.init()
    foodieObject.delegate = self
  }
}


// MARK: - Foodie Object Delegate Conformance
extension FoodieMarkup: FoodieObjectDelegate {
  
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
    
    DebugPrint.verbose("FoodieMarkUp.deleteRecursive from \(objectId) Location: \(location)")
    self.foodieObject.deleteRecursiveBase(from: location, withBlock: callback)
  }
  
  func verbose() {
    
  }
  
  
  func foodieObjectType() -> String {
    return "FoodieMarkup"
  }
}

extension FoodieMarkup: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieMarkup"
  }
}
