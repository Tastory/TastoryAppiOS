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
  
  
  // MARK: - Types & Enumerations
  typealias BooleanErrorBlock = PFBooleanResultBlock
  
  
  enum OperationStates: Int {
    case objectModified     = 1
    case savingToLocal      = 2
    case savedToLocal       = 3
    case savingToServer     = 4
    case savedToServer      = 5
    case pendingDelete      = 11
    case deletingFromLocal  = 12
    case deletedFromLocal   = 13
    case deletingFromServer = 14
    case deletedFromServer  = 15
  }
  
  
  enum StorageLocation {
    case local
    case server
  }
  
  
  // MARK: - Public Variables
  var state: OperationStates? { return operationState }
  
  
  // MARK: - Private Variables
  fileprivate var operationState: OperationStates?  // nil if Undetermined
  
  
  // MARK: - Public Functions
  
  // Function to traverse EVERTYHING to determine the object's state
  func determineStates() {
    DebugPrint.fatal("determineStates must be implemented by each specific child object")
  }
  
  
  // Function to mark memory modified
  func markModified() -> Bool {
    
    // Allowed to modify as long as not from one of the delete states
    if let currentState = operationState {
      if currentState.rawValue > 10 {
        return false
      }
    }
    operationState = .objectModified
    return true
  }
  
  
  // Each specific object to implement, to determine what needs to be save before itself can be saved. Callback should handle state transition
  func saveRecursive(to location: StorageLocation, withName name: String? = nil, withBlock callback: BooleanErrorBlock) -> Bool {
    DebugPrint.fatal("saveRecursive must be implemented by each specific child object")
  }
  
  
  // Each specific object to implement, to determine what needs to be done before itself can be deleted. Callback should handle state transition
  func deleteRecursive(from location: StorageLocation, withName name: String? = nil, withBlock callback: BooleanErrorBlock) -> Bool {
    DebugPrint.fatal("deleteRecursive must be implemented by each specific child object")
  }
  
  
  // Function to save this and all child Parse objects from local.
  func saveToLocal(withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    if let haveName = name {
      pinInBackground(withName: haveName, block: callback)
    } else {
      pinInBackground(block: callback)
    }
  }
  
  
  // Function to save this and all child Parse objects from server
  func saveToServer(withBlock callback: BooleanErrorBlock?) {
    saveInBackground(block: callback)
  }
  
  
  // Function to delete this and all child Parse objects from local
  func deleteFromLocal(withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    if let haveName = name {
      unpinInBackground(withName: haveName, block: callback)
    } else {
      unpinInBackground(block: callback)
    }
  }
  
  
  // Function to delete this and all child Parse objects from server
  func deleteFromServer(withBlock callback: BooleanErrorBlock?) {
    deleteInBackground(block: callback)
  }
  
  
  // MARK: - Private Functions
}
