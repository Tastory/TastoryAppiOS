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
    case objectSynced       = 0
    case objectModified     = 1
    case savingToLocal      = 2
    case savedToLocal       = 3
    case savingToServer     = 4
    case savedToServer      = 5  // Goes back to Synced
    case saveError          = 9  // Are we really going to use this?
    case pendingDelete      = 11
    case deletingFromLocal  = 12
    case deletedFromLocal   = 13
    case deletingFromServer = 14
    case deletedFromServer  = 15  // Goes back to Synced
    case deleteError        = 19  // Are we really going to use this?
  }
  
  enum StorageLocation {
    case local
    case server
  }
  
  struct FoodieOperation {
    var location: StorageLocation
    var name: String? = nil
    var callback: BooleanErrorBlock? = nil
  }
  
  
  // MARK: - Public Variables
  var operationState: OperationStates? { return protectedOperationState }
  var operationError: Error? { return protectedOperationError }
  
  
  // MARK: - Private Variables
  fileprivate var protectedOperationState: OperationStates?  // nil if Undetermined
  fileprivate var protectedOperationError: Error?  // Need specific Error object class?
  
  
  // MARK: - Public Functions
  
  // Function to traverse EVERTYHING to determine the object's state
  func determineStates() {

  }
  
  
  // Function to mark memory modified
  func markModified() -> Bool {
    
    // Allowed to modify as long as not from one of the delete states
    if let currentState = protectedOperationState {
      if currentState.rawValue > 10 {
        return false
      }
    }
    protectedOperationState = .objectModified
    return true
  }
  
  
  // Each specific object to implement, for their each of their child's save completion
  func saveCompletionFromChild(to location: StorageLocation, withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    DebugPrint.fatal("saveCompletionFromChild must be implemented by each specific Foodie Object classes")
  }
  
  
  // Each specific object to implement, to determine what needs to be save before itself can be saved. Callback should handle state transition
  func saveRecursive(to location: StorageLocation, withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    DebugPrint.fatal("saveRecursive must be implemented by each specific Foodie Object classes")
  }
  
  
  // Each specific object to implement, to determine what needs to be done before itself can be deleted. Callback should handle state transition
  func deleteRecursive(from location: StorageLocation, withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    DebugPrint.fatal("deleteRecursive must be implemented by each specific Foodie Object classes")
  }
  
  
  // Factor out common code that perform state transition when save completes
  func saveCompleteStateTransition(to location: StorageLocation) {
    
    guard let state = protectedOperationState else {
      DebugPrint.fatal("Unable to proceed due to nil state from object. Location: \(location)")
    }
    
    // State Transition for Save Error
    if protectedOperationError != nil {
      
      if (location == .local) && (state == .savingToLocal) {
        // Dial back the state
        self.protectedOperationState = .objectModified
        
      } else if (location == .server) && (state == .savingToServer) {
        // Dial back the state
        self.protectedOperationState = .savedToLocal
        
      } else {
        // Unexpected state combination
        DebugPrint.assert("Unexpected state combination for Error. Location: \(location), State: \(state)")
      }
    }
      
    // State Transition for Success
    else {
      
      if (location == .local) && (state == .savingToLocal) {
        // Dial back the state
        self.protectedOperationState = .savedToLocal
        
      } else if (location == .server) && (state == .savingToServer) {
        // Dial back the state
        self.protectedOperationState = .savedToServer
        
      } else {
        // Unexpected state combination
        DebugPrint.assert("Unexpected state combination for Error. Location: \(location), State: \(state)")
      }
    }
  }
  
  
  func savesCompletedFromAllChildren(to location: StorageLocation, withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    // If children all came back and there is error, unwind state and call callback
    if protectedOperationError != nil {
      saveCompleteStateTransition(to: location)
      callback?(false, operationError)
    }
      
    // If children all came back and no error, Save yourself!
    else {
      saveObject(to: location) { [unowned self] (success, error) in
        if !success {
          if let hasError = error {
            self.protectedOperationError = hasError
          } else {
            DebugPrint.assert("saveObject failed but block contained no Error")
          }
        }
        
        // State transition accordingly and call callback
        self.saveCompleteStateTransition(to: location)
        callback?(false, self.protectedOperationError)
      }
    }
  }
  
  
  // Factor out common code that evaluates operation states upon child's completion
  func isSaveCompleted(to location: StorageLocation) -> Bool {
    guard let state = protectedOperationState else {
      DebugPrint.fatal("Unable to proceed due to nil operationState. Location: \(location)")
    }
    
    if ((location == .local) && (state == .savingToLocal)) ||
      ((location == .server) && (state == .savingToServer)) {
      // Save still in progress
      return false
    } else if ((location == .local) && (state == .savedToLocal)) ||
      ((location == .server) && (state == .savedToServer)) {
      // Saved!
    } else if (state == .objectSynced) {
      // Nothing needs to be done to begin with
    } else if ((location == .local) && (state == .objectModified)) ||
      ((location == .server) && (state == .savedToLocal)) {
      // There must have been an unwind in state due to error
    } else {
      // Unexpected state transition. Barf
      DebugPrint.fatal("Unable to proceed due to unexpected state transition. Location: \(location), State: \(state)")
    }
    return true
  }
  
  
  // Factor out common code that perform state transition for saves
  func saveStateTransition(to location: StorageLocation) -> Bool? {
    
    guard let state = protectedOperationState else {
      DebugPrint.assert("Valid operationState expected to perform Save")
      return false
    }
    
    // Is save even allowed? Return false here if illegal state transition. Otherwise do state transition
    switch location {
    case .local:
      switch state {
      case .objectSynced:
        // No child object needs saving. Callback success in background
        return true
      case .objectModified:
        protectedOperationState = .savingToLocal
      default:
        DebugPrint.assert("Illegal State Transition. Save to Local attempt not from .objectModified state.")
        return false
      }
      
    case .server:
      switch state {
      case .objectSynced:
        // No child object needs saving. Callback success in background
        return true
      case .savedToLocal:
        protectedOperationState = .savingToServer
      default:
        DebugPrint.assert("Illegal State Transition. Save to Sever attempt not from .savedToLocal state.")
        return false
      }
    }
    
    return nil
  }
  
  
  // Factor out common code that calls child's save recursive with block
  func saveChild(_ object: FoodieObject,
                 to location: StorageLocation,
                 withName name: String? = nil,
                 withBlock callback: BooleanErrorBlock?) {
    
    // Save Recursive for each moment. Call saveCompletionFromChild when done and without errors
    object.saveRecursive(to: location, withName: name) { [unowned self] (success, error) in
      if !success {
        if let hasError = error {
          self.protectedOperationError = hasError
        } else {
          DebugPrint.assert("saveChild failed but block contained no Error")
        }
      }
      self.saveCompletionFromChild(to: location, withName: name, withBlock: callback)
    }
  }
  
  
  // Function to save this and all child Parse objects
  func saveObject(to location: StorageLocation, withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    switch location {
    case .local:
      saveToLocal(withName: name, withBlock: callback)
    case .server:
      saveToServer(withBlock: callback)
    }
  }
  
  
  // Function to save this and all child Parse objects to local.
  func saveToLocal(withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    if let hasName = name {
      pinInBackground(withName: hasName, block: callback)
    } else {
      pinInBackground(block: callback)
    }
  }
  
  
  // Function to save this and all child Parse objects to server
  func saveToServer(withBlock callback: BooleanErrorBlock?) {
    saveInBackground(block: callback)
  }
  
  
  // Function to delete this and all child Parse objects from local
  func deleteFromLocal(withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    if let hasName = name {
      unpinInBackground(withName: hasName, block: callback)
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
