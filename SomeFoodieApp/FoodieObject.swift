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
  enum OperationStates: Int {
    case objectModified
    case savingToLocal
    case savedToLocal
    case savingToServer
    case savedToServer
    case pendingDelete
    case deletingFromLocal
    case deletedFromLocal
    case deletingFromServer
    case deletedFromServer
  }
  
  
  // MARK: - Public Variables
  var state: OperationStates? { return operationState }
  
  
  // MARK: - Private Variables
  fileprivate var operationState: OperationStates?  // nil if Undetermined
  
  
  // MARK: - Public Functions
  
  // Function to traverse EVERTYHING to determine the object's state
  func determineStates() {
    
  }
  
  // Function to mark memory modified
  
  
  // Function to save object, traversing all child object states, saving child objects if needed
  
  
  // Function to delete object, traversing all child object states, managing child deletes if needed
  
  
  // MARK: - Private Functions
}
