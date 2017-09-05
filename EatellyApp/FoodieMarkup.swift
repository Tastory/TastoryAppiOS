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
}


// MARK: - Foodie Object Delegate Conformance
extension FoodieMarkup: FoodieObjectDelegate {
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(forceAnyways: Bool = false, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Retrieve self. This object have no children
    retrieve(forceAnyways: forceAnyways, withBlock: callback)
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     withName name: String? = nil,
                     withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
//    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
//    
//    if let earlySuccess = earlyReturnStatus.success {
//      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
//      return
//    }
    
    DispatchQueue.global(qos: .userInitiated).async { /*[unowned self] in */
      self.foodieObject.savesCompletedFromAllChildren(to: location, withName: name, withBlock: callback)
    }
  }
  
  
  func deleteRecursive(withName name: String? = nil,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    CCLog.verbose("FoodieJournal.deleteRecursive \(getUniqueIdentifier())")
    
    // Object might not be retrieved, retrieve first to have access to children
    retrieve { error in
      
      if let hasError = error {
        callback?(false, hasError)
      }
      
      // Delete itself first
      self.foodieObject.deleteObjectLocalNServer(withName: name, withBlock: callback)
    }
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
