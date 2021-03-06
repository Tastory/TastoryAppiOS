//
//  FoodieMarkup.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
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
                         for parentOperation: AsyncOperation? = nil,
                         withReady readyBlock: SimpleBlock? = nil,
                         withCompletion callback: SimpleErrorBlock?) -> AsyncOperation? {
    
    // Retrieve self. This object have no children
    foodieObject.retrieveObject(from: location, type: localType, forceAnyways: forceAnyways) { error in
      if error == nil { readyBlock?() }
      callback?(error)
    }
    return nil
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     for parentOperation: AsyncOperation? = nil,
                     withBlock callback: SimpleErrorBlock?) {

    CCLog.verbose("Parent PFObject shouldn't need to call saveRecurisve on Markups. Parse will auto Recurse on Save")
  }
  
  
  func saveWhole(to location: FoodieObject.StorageLocation,
                 type localType: FoodieObject.LocalType,
                 for parentOperation: AsyncOperation? = nil,
                 withBlock callback: SimpleErrorBlock?) {
    
    foodieObject.saveObject(to: location, type: localType, withBlock: callback)
  }
  
  
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       for parentOperation: AsyncOperation? = nil,
                       withBlock callback: SimpleErrorBlock?) {

    // Delete self. For now, this object has no children
    foodieObject.deleteObject(from: location, type: localType, withBlock: callback)
  }
  
  
  func cancelRetrieveFromServerRecursive() {
    // At this point, nothing can be cancelled for Markups
    return
  }
  
  
  func cancelSaveToServerRecursive() {
    // At this point, nothing can be cancelled for Markups
    return
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
