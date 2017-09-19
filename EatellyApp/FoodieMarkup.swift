//
//  FoodieMarkup.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 Eatelly. All rights reserved.
//


import Parse

class FoodieMarkup: FoodiePFObject {
  
  // MARK: - Parse PFObject keys
  @NSManaged var data: NSDictionary?
  @NSManaged var dataType: String?
  @NSManaged var keyword: String?
  
  
  // MARK: - Types & Enumerations
  enum dataTypes: String {
    case jotLabel = "JotLabel"
    case jotDrawView = "JotDrawView"
  }
  
  
  // MARK: - Public Instance Functions
  override init() {
    super.init()
    foodieObject.delegate = self
  }
}


// MARK: - Foodie Object Delegate Conformance
extension FoodieMarkup: FoodieObjectDelegate {
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(from location: FoodieObject.StorageLocation,
                         type localType: FoodieObject.LocalType,
                         forceAnyways: Bool = false,
                         withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Retrieve self. This object have no children
    foodieObject.retrieveObject(from: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
//    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
//    
//    if let earlySuccess = earlyReturnStatus.success {
//      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
//      return
//    }
    
    DispatchQueue.global(qos: .userInitiated).async { /*[unowned self] in */
      self.foodieObject.savesCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
    }
  }
  
  
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       withBlock callback: FoodieObject.SimpleErrorBlock?) {

    // Delete self. For now, this object has no children
    foodieObject.deleteObject(from: location, type: localType, withBlock: callback)
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
