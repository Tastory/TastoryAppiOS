 //
//  FoodieObject.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-05.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

import Foundation

protocol FoodieObjectDelegate: class {
  
  func retrieve(forceAnyways: Bool, withBlock callback: FoodieObject.RetrievedObjectBlock?)
  // Automatically resolves everything. Already in memory or Local or Network? Automatically caches.
  
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     withName name: String?,
                     withBlock callback: FoodieObject.BooleanErrorBlock?)
  
  func saveToLocal(withName name: String?, withBlock callback: FoodieObject.BooleanErrorBlock?)
  
  func saveToServer(withBlock callback: FoodieObject.BooleanErrorBlock?)
  
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       withName name: String?,
                       withBlock callback: FoodieObject.BooleanErrorBlock?)
  
  func deleteFromLocal(withName name: String?, withBlock callback: FoodieObject.BooleanErrorBlock?)
  
  func deleteFromServer(withBlock callback: FoodieObject.BooleanErrorBlock?)
  
  func verbose()
  
  func getUniqueIdentifier() -> String
  
  func foodieObjectType() -> String
}


class FoodieObject {
  
  // MARK: - Types & Enumerations
  typealias BooleanErrorBlock = (Bool, Error?) -> Void
  typealias QueryResultBlock = ([AnyObject]?, Error?) -> Void
  typealias RetrievedObjectBlock = (Any?, Error?) -> Void
  
  
  enum OperationStates {
    case objectSynced
    case objectModified
    case savingToLocal
    case savedToLocal
    case savingToServer
    case savedToServer
    case saveError
    case pendingDelete
    case deletingFromLocal
    case deletedFromLocal
    case deletingFromServer
    case deletedFromServer
    case deleteError
  }
  
  enum StorageLocation {
    case local
    case server
    case both
  }
  
  
  // MARK: Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case saveStateTransitionNoState
    case saveStateTransitionSaveAlreadyInProgress
    case saveStateTransitionIllegalStateTransition
    
    case deleteStateTransitionNoState
    case deleteStateTransitionSaveAlreadyInProgress
    case deleteStateTransitionIllegalStateTransition
    case deleteRetryError
    
    var errorDescription: String? {
      switch self {
      case .saveStateTransitionNoState:
        return NSLocalizedString("Save error as Foodie Object has no state", comment: "Error description for an exception error code")
      case .saveStateTransitionSaveAlreadyInProgress:
        return NSLocalizedString("Save error as save already in progress for Foodie Object", comment: "Error description for an exception error code")
      case .saveStateTransitionIllegalStateTransition:
        return NSLocalizedString("Save error due to illegal state transition", comment: "Error description for an exception error code")
     
      case .deleteStateTransitionNoState:
        return NSLocalizedString("Delete error as Foodie Object has no state", comment: "Error description for an exception error code")
      case .deleteStateTransitionSaveAlreadyInProgress:
        return NSLocalizedString("Delete error as save already in progress for Foodie Object", comment: "Error description for an exception error code")
      case .deleteStateTransitionIllegalStateTransition:
        return NSLocalizedString("Delete error due to illegal state transition", comment: "Error description for an exception error code")
      case .deleteRetryError:
        return NSLocalizedString("Delete Foodie Object failed with 2 attempts", comment: "Error description for an exception error code")
        
      }
    }
  
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      DebugPrint.error(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Public Instance Variables
  weak var delegate: FoodieObjectDelegate?
  var operationState: OperationStates? { return protectedOperationState }
  var operationError: Error? { return protectedOperationError }
  
  // MARK: - Private Instance Variables
  var protectedOperationState: OperationStates?  // nil if Undetermined
  fileprivate var protectedOperationError: Error?  // Need specific Error object class?
  fileprivate var criticalMutex = pthread_mutex_t()
  fileprivate var outstandingChildOperations = 0
  
  // MARK: - Public Instance Functions
  init() {
    protectedOperationState = .objectModified
    protectedOperationError = nil
    delegate = nil
  }
  
  
  init(delegateObject: FoodieObjectDelegate) {
    protectedOperationState = .objectModified
    protectedOperationError = nil
    delegate = delegateObject
  }
  
  // mark object for delete
  /*func markPendingDelete() {
      protectedOperationState = .pendingDelete
  }*/
  
  // Function to mark memory modified
  func markModified() -> Bool {
    
    // Allowed to modify as long as not from one of the delete states
//    if let currentState = protectedOperationState {
//      if currentState.rawValue > 10 {
//        return false
//      }
//    }
    protectedOperationState = .objectModified
    return true
  }
  

  // Function for state transition when all saves have completed
  func saveCompleteStateTransition(to location: StorageLocation) {
    
    guard let state = protectedOperationState else {
      DebugPrint.fatal("Unable to proceed due to nil state from object. Location: \(location)")
    }
    
    // State Transition for Save Error
    if protectedOperationError != nil {
      
      if (location == .local) && (state == .savingToLocal) {
        // Dial back the state
        protectedOperationState = .objectModified
        
      } else if (location == .server) && (state == .savingToServer) {
        // Dial back the state
        protectedOperationState = .savedToLocal
        
      } else {
        // Unexpected state combination
        DebugPrint.assert("Unexpected state combination for Error. Location: \(location), State: \(state)")
      }
    }
      
    // State Transition for Success
    else {
      
      if (location == .local) && (state == .savingToLocal) {
        // Advance to next state
        protectedOperationState = .savedToLocal
        
      } else if (location == .server) && (state == .savingToServer) {
        // Advance to next state
        protectedOperationState = .objectSynced
        
      } else {
        // Unexpected state combination
        DebugPrint.assert("Unexpected state combination for Error. Location: \(location), State: \(state)")
      }
    }
  }
  
  
  // Function when all child saves have completed
  func savesCompletedFromAllChildren(to location: StorageLocation, withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    
    DebugPrint.verbose("\(delegate!.foodieObjectType())(\(delegate!.getUniqueIdentifier())).Object.savesCompletedFromAllChildren to Location: \(location)")
    
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
        callback?(self.protectedOperationError == nil, self.protectedOperationError)
      }
    }
  }
  
  
  // Function for parent to inquire if this object's own save have completed
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
  
  
  // Function for state transition at the beginning of saveRecursive
  func saveStateTransition(to location: StorageLocation) -> (success: Bool?, error: LocalizedError?) {
    
    guard let state = protectedOperationState else {
      DebugPrint.assert("Valid operationState expected to perform Save")
      return (false, ErrorCode(.saveStateTransitionNoState))
    }
    
    // Is save even allowed? Return false here if illegal state transition. Otherwise do state transition
    switch state {
    case .savingToLocal, .savingToServer:
      // Save already occuring, another save not allowed
      return (false, ErrorCode(.saveStateTransitionSaveAlreadyInProgress))
    default:
      break
    }
    
    // Location dependent state transitions
    switch location {
    case .local:
      switch state {
      case .objectSynced:
        // No child object needs saving. Callback success in background
        return (true, nil)
      case .objectModified:
        protectedOperationState = .savingToLocal
      default:
        DebugPrint.assert("Illegal State Transition. Save to Local attempt not from .objectModified state. Current State = \(state)")
        return (false, ErrorCode(.saveStateTransitionIllegalStateTransition))
      }
      
    case .server:
      switch state {
      case .objectSynced:
        // No child object needs saving. Callback success in background
        return (true, nil)
      case .savedToLocal:
        protectedOperationState = .savingToServer
      default:
        DebugPrint.assert("Illegal State Transition. Save to Sever attempt not from .savedToLocal state. Current State = \(state)")
        return (false, ErrorCode(.saveStateTransitionIllegalStateTransition))
      }
    default:
    break
    }
    
    return (nil, nil)
  }
  
  
  // Function to call a child's saveRecursive
  func saveChild(_ child: FoodieObjectDelegate,
                 to location: StorageLocation,
                 withName name: String? = nil,
                 withBlock callback: BooleanErrorBlock?) {
    
    DebugPrint.verbose("\(delegate!.foodieObjectType())(\(delegate!.getUniqueIdentifier())).Object.saveChild of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) to Location: \(location)")
    
    outstandingChildOperations += 1
    
    // Save Recursive for each moment. Call saveCompletionFromChild when done and without errors
    child.saveRecursive(to: location, withName: name) { [unowned self] (success, error) in
      if !success {
        if let hasError = error {
          self.protectedOperationError = hasError
        } else {
          DebugPrint.assert("saveChild failed but block contained no Error")
        }
      }
      
      // This needs to be critical section or race condition between many childrens' completion can occur
      var childOperationsPending = true
      pthread_mutex_lock(&self.criticalMutex)
      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 { childOperationsPending = false }
      pthread_mutex_unlock(&self.criticalMutex)
      
      if !childOperationsPending {
        self.savesCompletedFromAllChildren(to: location, withName: name, withBlock: callback)
      }
    }
  }
  
  
  // Function to save this object
  func saveObject(to location: StorageLocation, withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    
    DebugPrint.verbose("\(delegate!.foodieObjectType())(\(delegate!.getUniqueIdentifier())).Object.saveObject to Location: \(location)")
    
    guard let delegateObj = delegate else {
      DebugPrint.fatal("delegate not expected to be nil in saveObject()")
    }
    switch location {
    case .local:
      delegateObj.saveToLocal(withName: name, withBlock: callback)
    case .server:
      delegateObj.saveToServer(withBlock: callback)
    default:
      break
    }
  }
  
  // Function for state transition at the beginning of delete
  /*func deleteStateTransition(to location: StorageLocation) -> (success: Bool?, error: LocalizedError?) {
    
    guard let state = protectedOperationState else {
      DebugPrint.assert("Valid operationState expected to perform Delete")
      return (false, ErrorCode(.deleteStateTransitionNoState))
    }
    
    // Is delete even allowed? Return false here if illegal state transition. Otherwise do state transition
    switch state {
    case .deletingFromLocal, .deletingFromServer:
      // Delete already occuring, another delete is not allowed
      return (false, ErrorCode(.deleteStateTransitionSaveAlreadyInProgress))
    default:
      break
    }
    
    // Location dependent state transitions
    switch location {
    case .local:
      switch state {
      case .objectSynced:
        // No child object needs deleting. Callback success in background
        return (true, nil)
      case .pendingDelete:
        protectedOperationState = .deletingFromLocal
      default:
        DebugPrint.assert("Illegal State Transition. Delete from Local attempt not from .objectSynced state. Current State = \(state)")
        return (false, ErrorCode(.deleteStateTransitionIllegalStateTransition))
      }
      
    case .server:
      switch state {
      case .objectSynced:
        // No child object needs deleting. Callback success in background
        return (true, nil)
      case .deletedFromLocal:
        protectedOperationState = .deletingFromServer
      default:
        DebugPrint.assert("Illegal State Transition. Save to Sever attempt not from .deletedFromLocal state. Current State = \(state)")
        return (false, ErrorCode(.deleteStateTransitionIllegalStateTransition))
      }
    default:
    break
    }
    
    return (nil, nil)
  }*/

  // Function for state transition at the end of delete
  /*func deleteCompleteStateTransition(to location: StorageLocation) {
    
    guard let state = protectedOperationState else {
      DebugPrint.fatal("Unable to proceed due to nil state from object. Location: \(location)")
    }
    
    // State Transition for Save Error
    if protectedOperationError != nil {
      
      if (location == .local) && (state == .deletingFromLocal) {
        // Dial back the state
        protectedOperationState = .pendingDelete
        
      } else if (location == .server) && (state == .deletingFromServer) {
        // Dial back the state
        protectedOperationState = .deletingFromLocal
        
      } else {
        // Unexpected state combination
        DebugPrint.assert("Unexpected state combination for Error. Location: \(location), State: \(state)")
      }
    }
      
      // State Transition for Success
    else {
      
      if (location == .local) && (state == .deletingFromLocal) {
        // Advance to next state
        protectedOperationState = .deletedFromLocal
        
      } else if (location == .server) && (state == .deletingFromServer) {
        // Advance to next state
        protectedOperationState = .objectSynced
        
      } else {
        // Unexpected state combination
        DebugPrint.assert("Unexpected state combination for Error. Location: \(location), State: \(state)")
      }
    }
  }*/
  
  // Function to delete this object
  func deleteObject(from location: StorageLocation, withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    
    DebugPrint.verbose("\(delegate!.foodieObjectType())(\(delegate!.getUniqueIdentifier())).Object.deleteObject from Location: \(location)")
    
    guard let delegateObj = delegate else {
      DebugPrint.fatal("delegate not expected to be nil in deleteObject()")
    }
    switch location {
    case .local:
      delegateObj.deleteFromLocal(withName: name, withBlock: callback)
    case .server:
      delegateObj.deleteFromServer(withBlock: callback)
    default:
      break
    }
  }
  
  func deleteRecursiveBasicBehavior(from location: FoodieObject.StorageLocation,
                                    withBlock callback: FoodieObject.BooleanErrorBlock?) {
    switch location {
      
    case .local,
         .server:
      // delete from local only
      performDelete(from: location, withBlock: callback)
    case .both:
      // delete from local first
      performDelete(from: .local, withBlock: { (success, error) in
        if(success) {
          self.performDelete(from: .server, withBlock: callback)
        } else {
          // error when deleting journal from local
          callback?(success, error)
        }
      })
    }
  }
  
  func deleteChild(_ child: FoodieObjectDelegate,
                   from location: FoodieObject.StorageLocation,
                   withBlock callback: FoodieObject.BooleanErrorBlock?) {

    self.outstandingChildOperations += 1
    var childOperationsPending = true
    
    child.deleteRecursive(from: location, withName: nil, withBlock: {(success, error) -> Void in
      
      if !success {
        if let hasError = error {
          self.protectedOperationError = hasError
        } else {
          DebugPrint.assert("deleteChild failed but block contained no Error")
        }
      }
      
      pthread_mutex_lock(&self.criticalMutex)
      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 {
        childOperationsPending = false
      }
      pthread_mutex_unlock(&self.criticalMutex)
      
      if !childOperationsPending {
        callback?(self.protectedOperationError == nil, self.protectedOperationError)
      }
    })
  }
  
  func performDelete(from location: FoodieObject.StorageLocation,
                           withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    /*let earlyReturnStatus  = deleteStateTransition(to: location)
    if let earlySuccess = earlyReturnStatus.success {
      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
      return
    }*/
    deleteObject(from: location, withBlock: {(success,error)-> Void in
      if let hasError = error {
        self.protectedOperationError = hasError
      }
      //self.deleteCompleteStateTransition(to: location)
      callback?(self.protectedOperationError == nil, self.protectedOperationError)
    })
  }
}
