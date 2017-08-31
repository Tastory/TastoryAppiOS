 //
//  FoodieObject.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-05.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

import Foundation

protocol FoodieObjectDelegate: class {

  func retrieve(forceAnyways: Bool, withBlock callback: FoodieObject.SimpleErrorBlock?)
  
  func retrieveRecursive(forceAnyways: Bool, withBlock callback: FoodieObject.SimpleErrorBlock?)
  
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     withName name: String?,
                     withBlock callback: FoodieObject.BooleanErrorBlock?)
  
  func saveToLocal(withName name: String?, withBlock callback: FoodieObject.BooleanErrorBlock?)
  
  func saveToServer(withBlock callback: FoodieObject.BooleanErrorBlock?)
  
  func deleteRecursive(withName name: String?,
                       withBlock callback: FoodieObject.BooleanErrorBlock?)
  
  func deleteFromLocal(withName name: String?, withBlock callback: FoodieObject.BooleanErrorBlock?)
  
  func deleteFromServer(withBlock callback: FoodieObject.BooleanErrorBlock?)
  
  func verbose()
  
  func getUniqueIdentifier() -> String
  
  func foodieObjectType() -> String
}


protocol FoodieObjectWaitOnRetrieveDelegate: class {
  
  func retrieved(for object: FoodieObjectDelegate)
}


class FoodieObject {
  
  // MARK: - Types & Enumerations
  typealias BooleanErrorBlock = (Bool, Error?) -> Void
  typealias RetrievedObjectBlock = (Any?, Error?) -> Void
  typealias SimpleErrorBlock = (Error?) -> Void
  
  
  enum OperationStates: String {
    case notAvailable       = "notAvailable"
    case pendingRetrieval   = "pendingRetrieval"
    case retrieving         = "retrieving"
    
    case objectSynced       = "objectSynced"
    case objectModified     = "objectModified"
    case savingToLocal      = "savingToLocal"
    case savedToLocal       = "savedToLocal"
    case savingToServer     = "savingToServer"
    case savedToServer      = "savedToServer"
    case saveError          = "saveError"
    
    case pendingDelete      = "pendingDelete"
    case deletingFromLocal  = "deletingFromLocal"
    case deletedFromLocal   = "deletedFromLocal"
    case deletingFromServer = "deletingFromServer"
    case deletedFromServer  = "deletedFromServer"
    case deleteError        = "deleteError"
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
    
    case retrievePinnedObjectError
    
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
      case .retrievePinnedObjectError:
        return NSLocalizedString("Failed to retrieve journal", comment: "Error description for an exception error code")
      }
    }
  
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      DebugPrint.error(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Public Instance Variables
  weak var delegate: FoodieObjectDelegate?
  weak var waitOnRetrieveDelegate: FoodieObjectWaitOnRetrieveDelegate?
  var operationState: OperationStates { return protectedOperationState }
  var operationError: Error? { return protectedOperationError }
  

  // MARK: - Private Instance Variables
  fileprivate var operationStateMutex = SwiftMutex.create()
  fileprivate var protectedOperationState: OperationStates = .notAvailable  // If this is not explicitly initiated, would be because it's from Parse, hence notAvailable.
  fileprivate var protectedOperationError: Error?  // Need specific Error object class?
  fileprivate var outstandingChildOperationsMutex = SwiftMutex.create()
  fileprivate var outstandingChildOperations = 0
  fileprivate var criticalMutex = SwiftMutex.create()
  
  
  // MARK: - Public Static Functions
  static func initialize() {
    FoodiePFObject.configure()
  }
  
  // MARK: - Public Instance Functions
  
  init(withState operationState: OperationStates) {
    protectedOperationState = operationState
    protectedOperationError = nil
  }
  
  // mark object for delete
  /*func markPendingDelete() {
      protectedOperationState = .pendingDelete
  }*/
  
  // Reset outstandingChildOperations
  func resetOutstandingChildOperations() { outstandingChildOperations = 0 }
  
  
  // Function to mark memory modified
  func markModified() {
    SwiftMutex.lock(&operationStateMutex)  // TODO-Performance: To be removed? Otherwise make sure this never gets executed in Main Thread?
    // TODO: State transition sanity checks?
    protectedOperationState = .objectModified
    SwiftMutex.unlock(&operationStateMutex)
  }
  
  
  // Function to mark pending retrieval
  func markPendingRetrieval() {
    
    SwiftMutex.lock(&operationStateMutex)  // TODO-Performance: To be removed? Otherwise make sure this never gets executed in Main Thread?
    
    switch protectedOperationState {
    case .notAvailable:
      protectedOperationState = .pendingRetrieval
      
    case .objectSynced, .pendingRetrieval, .retrieving:
      // Expected states to do nothing on
      break
      
    default:
      DebugPrint.verbose("FoodieObject.markPendingRetrieval() attempted from operationState = \(protectedOperationState.rawValue)")
      //DebugPrint.assert("FoodieObject.markPendingRetrieval. Invalid state transition")
    }
    
    SwiftMutex.unlock(&operationStateMutex)
  }

  
  // Function when all child retrieves have completed
  func retrievesCompletedFromAllChildren(withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // If children all came back and there is error, unwind state and call callback
    if protectedOperationError != nil {
      callback?(operationError)
    }
      
    // If children all came back and no error, just call the callback
    else {
      callback?(nil)
    }
  }
  
  
  // Function to call a child's retrieveRecursive()
  func retrieveChild(_ child: FoodieObjectDelegate, forceAnyways: Bool = false, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    SwiftMutex.lock(&self.outstandingChildOperationsMutex)
    outstandingChildOperations += 1
    SwiftMutex.unlock(&self.outstandingChildOperationsMutex)
    
    child.retrieveRecursive(forceAnyways: forceAnyways) { (error) in
      
      if let childError = error {
        self.protectedOperationError = childError
      }
      
      // This needs to be critical section or race condition between many childrens' completion can occur
      var childOperationsPending = true
      SwiftMutex.lock(&self.outstandingChildOperationsMutex)
      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 { childOperationsPending = false }
      SwiftMutex.unlock(&self.outstandingChildOperationsMutex)
      
      if !childOperationsPending {
        self.retrievesCompletedFromAllChildren(withBlock: callback)
      }
    }
  }
  
  
  // Function for state transition when all saves have completed
  func saveCompleteStateTransition(to location: StorageLocation) {
    
//    // State Transition for Save Error
//    if protectedOperationError != nil {
//      
//      if (location == .local) && (operationState == .savingToLocal) {
//        // Dial back the state
//        protectedOperationState = .objectModified
//        
//      } else if (location == .server) && (operationState == .savingToServer) {
//        // Dial back the state
//        protectedOperationState = .savedToLocal
//        
//      } else {
//        // Unexpected state combination
//        DebugPrint.assert("Unexpected state combination for Error. Location: \(location), State: \(operationState)")
//      }
//    }
//      
//    // State Transition for Success
//    else {
//      if (location == .local) && (operationState == .savingToLocal) {
//        // Dial back the state
//        protectedOperationState = .savedToLocal
//        
//      } else if (location == .server) && (operationState == .savingToServer) {
//        // Dial back the state
//        protectedOperationState = .objectSynced
//        
//      } else {
//        // Unexpected state combination
//        DebugPrint.assert("Unexpected state combination for Error. Location: \(location), State: \(operationState)")
//      }
//    }
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
      saveObject(to: location, withName: name) { /*[unowned self]*/ (success, error) in
        if !success {
          if let hasError = error {
            self.protectedOperationError = hasError
          } else {
            // TODO investigate if it is possible to have success = false and no error 
            // I have seen it happened once
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
//  func isSaveCompleted(to location: StorageLocation) -> Bool {
//    
//    if ((location == .local) && (operationState == .savingToLocal)) ||
//      ((location == .server) && (operationState == .savingToServer)) {
//      // Save still in progress
//      return false
//    } else if ((location == .local) && (operationState == .savedToLocal)) ||
//      ((location == .server) && (operationState == .savedToServer)) {
//      // Saved!
//    } else if (operationState == .objectSynced) {
//      // Nothing needs to be done to begin with
//    } else if ((location == .local) && (operationState == .objectModified)) ||
//      ((location == .server) && (operationState == .savedToLocal)) {
//      // There must have been an unwind in state due to error
//    } else {
//      // Unexpected state transition. Barf
//      DebugPrint.fatal("Unable to proceed due to unexpected state transition. Location: \(location), State: \(operationState)")
//    }
//    return true
//  }
  
  
  // Function for state transition at the beginning of saveRecursive
  func saveStateTransition(to location: StorageLocation) -> (success: Bool?, error: LocalizedError?) {

    return (nil, nil)  // saveStateTransition is going to be removed anyways
//    // Is save even allowed? Return false here if illegal state transition. Otherwise do state transition
//    switch operationState {
//    case .savingToLocal, .savingToServer:
//      // Save already occuring, another save not allowed
//      return (false, ErrorCode(.saveStateTransitionSaveAlreadyInProgress))
//    default:
//      break
//    }
//    
//    // Location dependent state transitions
//    switch location {
//    case .local:
//      switch operationState {
//      case .objectSynced:
//        // No child object needs saving. Callback success in background
//        return (true, nil)
//      case .objectModified:
//        protectedOperationState = .savingToLocal
//      default:
//        DebugPrint.assert("Illegal State Transition. Save to Local attempt not from .objectModified state. Current State = \(operationState)")
//        return (false, ErrorCode(.saveStateTransitionIllegalStateTransition))
//      }
//      
//    case .server:
//      switch operationState {
//      case .objectSynced:
//        // No child object needs saving. Callback success in background
//        return (true, nil)
//      case .savedToLocal:
//        protectedOperationState = .savingToServer
//      default:
//        DebugPrint.assert("Illegal State Transition. Save to Sever attempt not from .savedToLocal state. Current State = \(operationState)")
//        return (false, ErrorCode(.saveStateTransitionIllegalStateTransition))
//      }
//    default:
//    break
//    }
//    
//    return (nil, nil)
  }
  
  
  // Function to call a child's saveRecursive
  func saveChild(_ child: FoodieObjectDelegate,
                 to location: StorageLocation,
                 withName name: String? = nil,
                 withBlock callback: BooleanErrorBlock?) {
    
    DebugPrint.verbose("\(delegate!.foodieObjectType())(\(delegate!.getUniqueIdentifier())).Object.saveChild of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) to Location: \(location)")
    
    SwiftMutex.lock(&self.outstandingChildOperationsMutex)
    outstandingChildOperations += 1
    SwiftMutex.unlock(&self.outstandingChildOperationsMutex)
    
    // Save Recursive for each moment. Call saveCompletionFromChild when done and without errors
    child.saveRecursive(to: location, withName: name) { /*[unowned self]*/ (success, error) in
      if !success {
        if let hasError = error {
          self.protectedOperationError = hasError
        } else {
          DebugPrint.assert("saveChild failed but block contained no Error")
        }
      }
      
      // This needs to be critical section or race condition between many childrens' completion can occur
      var childOperationsPending = true
      SwiftMutex.lock(&self.outstandingChildOperationsMutex)
      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 { childOperationsPending = false }
      SwiftMutex.unlock(&self.outstandingChildOperationsMutex)
      
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
  
  
  // Function to delete this object
  func deleteObject(from location: StorageLocation, withName name: String? = nil, withBlock callback: BooleanErrorBlock?) {
    DebugPrint.verbose("\(delegate!.foodieObjectType())(\(delegate!.getUniqueIdentifier())).Object.deleteObject")
    
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
  
  
  func deleteObjectLocalNServer(withName name: String? = nil, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    // delete from local first
    deleteObject(from: .local, withName: name) { (success, error) in
      if(success) {
        self.deleteObject(from: .server, withName: name, withBlock: callback)
      } else {
        // error when deleting journal from local
        callback?(success, error)
      }
    }
  }
  
  
  func deleteChild(_ child: FoodieObjectDelegate,
                   withBlock callback: FoodieObject.BooleanErrorBlock?) {

    // Lock here is in case that if the first operation competes and calls back before even the 2nd op's deleteChild goes out
    SwiftMutex.lock(&self.criticalMutex)
    self.outstandingChildOperations += 1
    SwiftMutex.unlock(&self.criticalMutex)
    
    child.deleteRecursive(withName: nil, withBlock: {(success, error) -> Void in
      
      if !success {
        if let hasError = error {
          self.protectedOperationError = hasError
        } else {
          DebugPrint.assert("deleteChild failed but block contained no Error")
        }
      }
      
      var childOperationsPending = true
      SwiftMutex.lock(&self.criticalMutex)
      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 {
        childOperationsPending = false
      }
      SwiftMutex.unlock(&self.criticalMutex)
      
      if !childOperationsPending {
        callback?(self.protectedOperationError == nil, self.protectedOperationError)
      }
    })
  }
  
  
  // Function to retrieve if the Download status calls for
  func retrieveIfPending(withBlock callback: FoodieObject.SimpleErrorBlock?) -> Bool {
    
    var needRetrieval = false
    
    SwiftMutex.lock(&operationStateMutex)
    
    if operationState == .pendingRetrieval {
      protectedOperationState = .retrieving
      needRetrieval = true
      SwiftMutex.unlock(&operationStateMutex)
      
    } else {
      SwiftMutex.unlock(&operationStateMutex)
      return false  // Nothing pending, just return false
    }
    
    if needRetrieval {
      guard let delegateObj = delegate else {
        DebugPrint.fatal("delegate not expected to be nil in retrieveIfPending()")
      }
      delegateObj.retrieveRecursive(forceAnyways: false) { error in
        
        // Move forward state if success, backwards if failed
        SwiftMutex.lock(&self.operationStateMutex)
        
        if error == nil {
          self.protectedOperationState = .objectSynced
        } else {
          self.protectedOperationState = .notAvailable
        }
        SwiftMutex.unlock(&self.operationStateMutex)
        
        callback?(error)
        self.waitOnRetrieveDelegate?.retrieved(for: delegateObj)
        self.waitOnRetrieveDelegate = nil
      }
      return true  // Pending retrieval issued as retrieval, return true
    }
  }
  
  
  // Funciton to check if Content Retrieved is set to True. Register delegate object if False
  func checkRetrieved(ifFalseSetDelegate delegate: FoodieObjectWaitOnRetrieveDelegate) -> Bool {
    
    var retrieved = false
    SwiftMutex.lock(&operationStateMutex)
    
    switch operationState {
    case .pendingRetrieval, .retrieving:
      waitOnRetrieveDelegate = delegate
      retrieved = false
    case .notAvailable, .objectSynced:
      retrieved = true
    default:
      DebugPrint.error("FoodieObject.checkRetrieved() state unexpected")
    }
    
    SwiftMutex.unlock(&operationStateMutex)
    return retrieved
  }
  
}
