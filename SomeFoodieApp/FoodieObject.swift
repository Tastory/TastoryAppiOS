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
  
  
  struct FoodieOperation {
    // Location, Name and Callback?
  }
  
  
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
  
  
  // MARK: - Public Variables
  var operationState: OperationStates? { return protectedOperationState }
  
  
  
  // MARK: - Private Variables
  fileprivate var protectedOperationState: OperationStates?  // nil if Undetermined
  fileprivate var protectedOperationError: Error?  // Need specific Error object class?
  
  
  // MARK: - Public Functions
  
  // Function to traverse EVERTYHING to determine the object's state
  func determineStates() {
    DebugPrint.fatal("determineStates must be implemented by each specific child object")
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
  
  
  func childSaveCompletion(to location: StorageLocation,
                           withName name: String? = nil,
                           withBlock callback: (Bool, Error?) -> Void) -> Void {
    DebugPrint.fatal("childSaveCompletion must be implemented by each specific Foodie Object classes")
  }
  
  
  // Each specific object to implement, to determine what needs to be save before itself can be saved. Callback should handle state transition
  func saveRecursive(to location: StorageLocation, withName name: String? = nil, withBlock callback: @escaping BooleanErrorBlock) -> Bool {
    DebugPrint.fatal("saveRecursive must be implemented by each specific Foodie Object classes")
  }
  
  
  // Each specific object to implement, to determine what needs to be done before itself can be deleted. Callback should handle state transition
  func deleteRecursive(from location: StorageLocation, withName name: String? = nil, withBlock callback: @escaping BooleanErrorBlock) -> Bool {
    DebugPrint.fatal("deleteRecursive must be implemented by each specific Foodie Object classes")
  }
  
  
  // Factor out common code that perform state transition when save completes
  func stateTransitionForSaveComplete(to location: StorageLocation, withBlock callback: @escaping (Bool, Error?) -> Void) {
    
    // Check if operation completed in Error
    
    // State Transition for Save Error
    if (location == .local) && (operationState == .savingToLocal) {
      // Dial back the state
      self.protectedOperationState = .objectModified
      
    } else if (location == .server) && (operationState == .savingToServer) {
      // Dial back the state
      self.protectedOperationState = .savedToLocal
      
    } else {
      // Unexpected state combination
      DebugPrint.assert("Unexpected state combination for Error. Location: \(location), State: \(operationState)")
    }
    
    // State Transition for Success
    
  }
  
  
  // Factor out common code that perform state transition for saves
  func stateTransitionForSave(to location: StorageLocation, withBlock callback: @escaping (Bool, Error?) -> Void) -> Bool? {
    
    guard let operationState = protectedOperationState else {
      // Valid operation state needed to perform save
      return false
    }
    
    // Is save even allowed? Return false here if illegal state transition. Otherwise do state transition
    switch location {
    case .local:
      switch operationState {
      case .objectSynced:
        // No child object needs saving. Callback success in background
        DispatchQueue.global(qos: .userInitiated).async { callback(true, nil) }
        return true
      case .objectModified:
        protectedOperationState = .savingToLocal
      default:
        DebugPrint.error("Illegal State Transition. Save to Local attempt not from .objectModified state.")
        return false
      }
      
    case .server:
      switch operationState {
      case .objectSynced:
        // No child object needs saving. Callback success in background
        DispatchQueue.global(qos: .userInitiated).async { callback(true, nil) }
        return true
      case .savedToLocal:
        protectedOperationState = .savingToServer
      default:
        DebugPrint.error("Illegal State Transition. Save to Sever attempt not from .savedToLocal state.")
        return false
      }
    }
    
    return nil
  }
  
  
  // Factor out common code that evaluates operation states upon child's completion
  func didSaveComplete(for object: FoodieObject, to location: StorageLocation) -> Bool {
    guard let operationState = object.operationState else {
      DebugPrint.fatal("unable to proceed due to nil state from child. Location: \(location)")
    }
    
    if ((location == .local) && (operationState == .savingToLocal)) ||
      ((location == .server) && (operationState == .savingToServer)) {
      // Save still in progress
      return false
    } else if ((location == .local) && (operationState == .savedToLocal)) ||
      ((location == .server) && (operationState == .savedToServer)) {
      // Saved!
    } else if (operationState == .objectSynced) {
      // Nothing needs to be done to begin with
    } else if ((location == .local) && (operationState == .objectModified)) ||
      ((location == .server) && (operationState == .savedToLocal)) {
      // There must have been a unwind in state due to error
    } else {
      // Unexpected state transition. Barf
      DebugPrint.fatal("Unable to proceed due to unexpected state transition. Location: \(location), State: \(operationState)")
    }
    return true
  }
  
  
  // Factor out common code that calls child's save recursive with block
  func saveChild(_ object: FoodieObject,
                 to location: StorageLocation,
                 withName name: String? = nil,
                 withBlock callback: @escaping (Bool, Error?) -> Void) -> Bool {
    
    // Save Recursive for each moment. Call childSaveCompletion when done and without errors
    if !object.saveRecursive(to: location, withName: name, withBlock: { [unowned self] (success, error) in
      if !success {
        if let hasError = error {
          self.protectedOperationError = hasError
        } else {
          DebugPrint.assert("saveChild failed but block contained no Error")
        }
      }
      self.childSaveCompletion(to: location, withName: name, withBlock: callback)
    }) {
      return false // Return false upon child reporting illegal state transition, only log for the original illegal detection
    } else {
      return true
    }
  }
  
  
  // Function to save this and all child Parse objects from local.
  func saveToLocal(withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    if let hasName = name {
      pinInBackground(withName: hasName, block: callback)
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
