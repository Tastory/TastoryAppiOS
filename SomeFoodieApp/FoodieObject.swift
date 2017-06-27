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
  
  func retrieveRecursive(forceAnyways: Bool, withBlock callback: FoodieObject.RetrievedObjectBlock?)
  
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
    case notAvailable
    case pendingRetrieval
    case retrieving
    
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
  }
  
  
  // MARK: Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case saveStateTransitionNoState
    case saveStateTransitionSaveAlreadyInProgress
    case saveStateTransitionIllegalStateTransition
    
    var errorDescription: String? {
      switch self {
      case .saveStateTransitionNoState:
        return NSLocalizedString("Save error as Foodie Object has no state", comment: "Error description for an exception error code")
      case .saveStateTransitionSaveAlreadyInProgress:
        return NSLocalizedString("Save error as save already in progress for Foodie Object", comment: "Error description for an exception error code")
      case .saveStateTransitionIllegalStateTransition:
        return NSLocalizedString("Save error due to illegal state transition", comment: "Error description for an exception error code")
      }
    }
  
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      DebugPrint.error(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Public Instance Variables
  weak var delegate: FoodieObjectDelegate?
  var operationState: OperationStates { return protectedOperationState }
  var operationError: Error? { return protectedOperationError }
  
  
  // MARK: - Private Instance Variables
  fileprivate var protectedOperationState: OperationStates = .notAvailable  // If this is not explicitly initiated, would be because it's from Parse, hence notAvailable.
  fileprivate var protectedOperationError: Error?  // Need specific Error object class?
  fileprivate var outstandingChildOperationsMutex = pthread_mutex_t()
  fileprivate var outstandingChildOperations = 0
  
  
  // MARK: - Public Instance Functions
  
  init(withState operationState: OperationStates) {
    protectedOperationState = operationState
    protectedOperationError = nil
  }
  
  
  // Reset outstandingChildOperations
  func resetOutstandingChildOperations() { outstandingChildOperations = 0 }
  
  
  // Function to mark memory modified
  func markModified() {
    // TODO: State transition sanity checks?
    protectedOperationState = .objectModified
  }
  
  
  // Function to mark pending retrieval
  func markPendingRetrieval() {
    // TODO: Need a mutex lock?
    if protectedOperationState == .notAvailable {
      protectedOperationState = .pendingRetrieval
    }
  }

  
  // Function when all child retrieves have completed
  func retrievesCompletedFromAllChildren(withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    
    // If children all came back and there is error, unwind state and call callback
    if protectedOperationError != nil {
      callback?(nil, operationError)
    }
      
    // If children all came back and no error, just call the callback
    else {
      callback?(self, nil)
    }
  }
  
  
  // Function to call a child's retrieveRecursive()
  func retrieveChild(_ child: FoodieObjectDelegate, forceAnyways: Bool = false, withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    
    outstandingChildOperations += 1
    
    child.retrieveRecursive(forceAnyways: forceAnyways) { /*[unowned self]*/ (object, error) in
      
      if let childError = error {
        self.protectedOperationError = childError
      }
      
      // This needs to be critical section or race condition between many childrens' completion can occur
      var childOperationsPending = true
      pthread_mutex_lock(&self.outstandingChildOperationsMutex)
      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 { childOperationsPending = false }
      pthread_mutex_unlock(&self.outstandingChildOperationsMutex)
      
      if !childOperationsPending {
        self.retrievesCompletedFromAllChildren(withBlock: callback)
      }
    }
  }
  
  
  // Function for state transition when all saves have completed
  func saveCompleteStateTransition(to location: StorageLocation) {
    
    // State Transition for Save Error
    if protectedOperationError != nil {
      
      if (location == .local) && (operationState == .savingToLocal) {
        // Dial back the state
        protectedOperationState = .objectModified
        
      } else if (location == .server) && (operationState == .savingToServer) {
        // Dial back the state
        protectedOperationState = .savedToLocal
        
      } else {
        // Unexpected state combination
        DebugPrint.assert("Unexpected state combination for Error. Location: \(location), State: \(operationState)")
      }
    }
      
    // State Transition for Success
    else {
      
      if (location == .local) && (operationState == .savingToLocal) {
        // Dial back the state
        protectedOperationState = .savedToLocal
        
      } else if (location == .server) && (operationState == .savingToServer) {
        // Dial back the state
        protectedOperationState = .objectSynced
        
      } else {
        // Unexpected state combination
        DebugPrint.assert("Unexpected state combination for Error. Location: \(location), State: \(operationState)")
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
      saveObject(to: location) { /*[unowned self]*/ (success, error) in
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
      // There must have been an unwind in state due to error
    } else {
      // Unexpected state transition. Barf
      DebugPrint.fatal("Unable to proceed due to unexpected state transition. Location: \(location), State: \(operationState)")
    }
    return true
  }
  
  
  // Function for state transition at the beginning of saveRecursive
  func saveStateTransition(to location: StorageLocation) -> (success: Bool?, error: LocalizedError?) {

    // Is save even allowed? Return false here if illegal state transition. Otherwise do state transition
    switch operationState {
    case .savingToLocal, .savingToServer:
      // Save already occuring, another save not allowed
      return (false, ErrorCode(.saveStateTransitionSaveAlreadyInProgress))
    default:
      break
    }
    
    // Location dependent state transitions
    switch location {
    case .local:
      switch operationState {
      case .objectSynced:
        // No child object needs saving. Callback success in background
        return (true, nil)
      case .objectModified:
        protectedOperationState = .savingToLocal
      default:
        DebugPrint.assert("Illegal State Transition. Save to Local attempt not from .objectModified state. Current State = \(operationState)")
        return (false, ErrorCode(.saveStateTransitionIllegalStateTransition))
      }
      
    case .server:
      switch operationState {
      case .objectSynced:
        // No child object needs saving. Callback success in background
        return (true, nil)
      case .savedToLocal:
        protectedOperationState = .savingToServer
      default:
        DebugPrint.assert("Illegal State Transition. Save to Sever attempt not from .savedToLocal state. Current State = \(operationState)")
        return (false, ErrorCode(.saveStateTransitionIllegalStateTransition))
      }
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
    child.saveRecursive(to: location, withName: name) { /*[unowned self]*/ (success, error) in
      if !success {
        if let hasError = error {
          self.protectedOperationError = hasError
        } else {
          DebugPrint.assert("saveChild failed but block contained no Error")
        }
      }
      
      // This need sto be critical section or race condition between many childrens' completion can occur
      var childOperationsPending = true
      pthread_mutex_lock(&self.outstandingChildOperationsMutex)
      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 { childOperationsPending = false }
      pthread_mutex_unlock(&self.outstandingChildOperationsMutex)
      
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
    }
  }
  

  // Function to retrieve if the Download status calls for
  func retrieveIfPending(withBlock callback: FoodieObject.RetrievedObjectBlock?) -> Bool {
    
    var needRetrieval = false
    
    // TODO: Need a mutex lock?
    if operationState == .pendingRetrieval {
      protectedOperationState = .retrieving
      needRetrieval = true
    }
    
    if needRetrieval {
      delegate!.retrieveRecursive(forceAnyways: false) { object, error in
        
        // Move forward state if success, backwards if failed
        // TODO: Need a mutex lock?
        if object != nil, error == nil {
          self.protectedOperationState = .objectSynced
        } else {
          self.protectedOperationState = .notAvailable
        }
        callback?(object, error)
      }
      
      return true
    } else {
      // callback?(delegate!, nil)
      return false
    }
  }
}
