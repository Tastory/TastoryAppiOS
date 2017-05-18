//
//  FoodieMedia.swift
//  SomeFoodieApp
//
//  Created by Victor Tsang on 2017-05-08.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import Foundation


class FoodieMedia {
 
  // MARK: - Public Instance Variable
  var foodieObject = FoodieObject()
  var mediaUrlString: String?
  
  // MARK: - Public Instance Function
  init(with urlString: String) {
    foodieObject.delegate = self
    mediaUrlString = urlString
  }
}


// MARK: - Foodie Object Delegate Conformance
extension FoodieMedia: FoodieObjectDelegate {
  
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
    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
    
    if let earlySuccess = earlyReturnStatus.success {
      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
      return
    }
    
    
  }
  
  func saveToLocal(withName name: String?, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
  }
  
  func saveToServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
  }
  
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       withName name: String?,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
  }
  
  func deleteFromLocal(withName name: String?, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
  }
  
  func deleteFromServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
  }
  
  func foodieObjectType() -> String {
    return "FoodieMedia"
  }
}
