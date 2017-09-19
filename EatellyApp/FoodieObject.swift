 //
//  FoodieObject.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-04-05.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import Foundation

 
protocol FoodieObjectDelegate: class {

  static func deleteAll(from localType: FoodieObject.LocalType,
                        withBlock callback: FoodieObject.SimpleErrorBlock?)
  
  func retrieve(from localType: FoodieObject.LocalType,
                forceAnyways: Bool,
                withBlock callback: FoodieObject.SimpleErrorBlock?)
  
  func retrieveFromLocalThenServer(forceAnyways: Bool,
                                   type: FoodieObject.LocalType,
                                   withBlock callback: FoodieObject.SimpleErrorBlock?)
  
  func retrieveRecursive(from location: FoodieObject.StorageLocation,
                         type localType: FoodieObject.LocalType,
                         forceAnyways: Bool,
                         withBlock callback: FoodieObject.SimpleErrorBlock?)
  
  
  func save(to localType: FoodieObject.LocalType,
            withBlock callback: FoodieObject.SimpleErrorBlock?)
  
  func saveToLocalNServer(type localType: FoodieObject.LocalType,
                          withBlock callback: FoodieObject.SimpleErrorBlock?)
  
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     withBlock callback: FoodieObject.SimpleErrorBlock?)
  
  
  func delete(from localType: FoodieObject.LocalType,
              withBlock callback: FoodieObject.SimpleErrorBlock?)
  
  func deleteFromLocalNServer(withBlock callback: FoodieObject.SimpleErrorBlock?)  // Always whacks all
  
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       withBlock callback: FoodieObject.SimpleErrorBlock?)
  
  
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
  
  
  enum LocalType: String {
    case cache = "FoodieCache"
    case draft = "FoodieDraft"
  }
  
  
  enum StorageLocation: String {
    case local
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
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
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
  
  
  static func deleteAll(from localType: LocalType, withBlock callback: SimpleErrorBlock?) {
    FoodiePFObject.deleteAll(from: localType) { error in
      FoodieS3Object.deleteAll(from: localType, withBlock: callback)
    }
  }
  
  
  // MARK: - Public Instance Functions
  
  init(withState operationState: OperationStates) {
    protectedOperationState = operationState
    protectedOperationError = nil
  }
  
  
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
      CCLog.verbose("FoodieObject.markPendingRetrieval() attempted from operationState = \(protectedOperationState.rawValue)")
      //CCLog.assert("FoodieObject.markPendingRetrieval. Invalid state transition")
    }
    
    SwiftMutex.unlock(&operationStateMutex)
  }

  
  func retrievesCompletedFromAllChildren(withBlock callback: SimpleErrorBlock?) {
    
    // If children all came back and there is error, unwind state and call callback
    if protectedOperationError != nil {
      callback?(operationError)
    }
      
    // If children all came back and no error, just call the callback
    else {
      callback?(nil)
    }
  }
  
  
  func retrieveChild(_ child: FoodieObjectDelegate, from location: StorageLocation, type localType: LocalType, forceAnyways: Bool, withBlock callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    CCLog.verbose("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) Retrieve Child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) to Location: \(location), LocalType: \(localType)")
    
    SwiftMutex.lock(&self.outstandingChildOperationsMutex)
    outstandingChildOperations += 1
    SwiftMutex.unlock(&self.outstandingChildOperationsMutex)
    
    child.retrieveRecursive(from: location, type: localType, forceAnyways: forceAnyways) { error in
      if let error = error {
        CCLog.warning("retrieveChild on \(child.foodieObjectType()) with session ID \(child.getUniqueIdentifier()) failed with Error \(error.localizedDescription)")
        self.protectedOperationError = error
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
  
  
  func retrieveObject(from location: StorageLocation, type localType: LocalType, forceAnyways: Bool, withBlock callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    
    switch location {
    case .local:
      delegate.retrieve(from: localType, forceAnyways: forceAnyways, withBlock: callback)
    case .both:
      delegate.retrieveFromLocalThenServer(forceAnyways: forceAnyways, type: localType, withBlock: callback)
    }
  }
  

  // Function for state transition when all saves have completed
  func saveCompleteStateTransition(to location: StorageLocation) {
    
    // State Transition for Save Error
    if protectedOperationError != nil {
      
      if (location == .local) {
        // Dial back the state
        protectedOperationState = .objectModified
        
      } else if (location == .both) {
        // Dial back the state
        protectedOperationState = .savedToLocal
        
      } else {
        // Unexpected state combination
        CCLog.assert("Unexpected state combination for Error. Location: \(location), State: \(operationState)")
      }
    }
      
    // State Transition for Success
    else {
      if (location == .local) {
        // Dial back the state
        protectedOperationState = .savedToLocal
        
      } else if (location == .both) {
        // Dial back the state
        protectedOperationState = .objectSynced
        
      } else {
        // Unexpected state combination
        CCLog.assert("Unexpected state combination for Error. Location: \(location), State: \(operationState)")
      }
    }
  }
  
  
  // Function when all child saves have completed
  func savesCompletedFromAllChildren(to location: StorageLocation, type localType: LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    
    // If children all came back and there is error, unwind state and call callback
    if protectedOperationError != nil {
      saveCompleteStateTransition(to: location)
      callback?(operationError)
    }
      
    // If children all came back and no error, Save yourself!
    else {
      saveObject(to: location, type: localType) { error in
        if let error = error {
          CCLog.warning("Saving Object \(delegate.foodieObjectType()) \(delegate.getUniqueIdentifier()) to \(location), \(localType) Failed - \(error.localizedDescription)")
          self.protectedOperationError = error
        }
        // State transition accordingly and call callback
        self.saveCompleteStateTransition(to: location)
        callback?(self.protectedOperationError)
      }
    }
  }
  
  
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
//        CCLog.assert("Illegal State Transition. Save to Local attempt not from .objectModified state. Current State = \(operationState)")
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
//        CCLog.assert("Illegal State Transition. Save to Sever attempt not from .savedToLocal state. Current State = \(operationState)")
//        return (false, ErrorCode(.saveStateTransitionIllegalStateTransition))
//      }
//    default:
//    break
//    }
//    
//    return (nil, nil)
  }
  
  
  // Function to call a child's saveRecursive
  func saveChild(_ child: FoodieObjectDelegate, to location: StorageLocation, type localType: LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    CCLog.verbose("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) Saving Child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) to Location: \(location), LocalType: \(localType)")
    
    SwiftMutex.lock(&self.outstandingChildOperationsMutex)
    outstandingChildOperations += 1
    SwiftMutex.unlock(&self.outstandingChildOperationsMutex)
    
    // Save Recursive for each children. Call saveCompletionFromChild when done and without errors
    child.saveRecursive(to: location, type: localType) { error in
      if let error = error {
        CCLog.warning("saveChild on \(child.foodieObjectType()) with session ID \(child.getUniqueIdentifier()) failed with Error \(error.localizedDescription)")
        self.protectedOperationError = error
      }
      
      // This needs to be critical section or race condition between many childrens' completion can occur
      var childOperationsPending = true
      SwiftMutex.lock(&self.outstandingChildOperationsMutex)
      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 { childOperationsPending = false }
      SwiftMutex.unlock(&self.outstandingChildOperationsMutex)
      
      if !childOperationsPending {
        self.savesCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
      }
    }
  }
  
  
  // Function to save this object
  func saveObject(to location: StorageLocation, type localType: LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    switch location {
    case .local:
      delegate.save(to: localType, withBlock: callback)
    case .both:
      delegate.saveToLocalNServer(type: localType, withBlock: callback)
    }
  }
  
  
  // Function to delete child
  func deleteChild(_ child: FoodieObjectDelegate, from location: StorageLocation, type localType: LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    CCLog.verbose("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) Delete Child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) to Location: \(location), LocalType: \(localType)")
    
    // Lock here is in case that if the first operation competes and calls back before even the 2nd op's deleteChild goes out
    SwiftMutex.lock(&self.criticalMutex)
    self.outstandingChildOperations += 1
    SwiftMutex.unlock(&self.criticalMutex)
    
    // Delete Recursive for each children
    child.deleteRecursive(from: location, type: localType) { error in
      if let error = error {
        CCLog.warning("deleteChild on \(child.foodieObjectType()) with session ID \(child.getUniqueIdentifier()) failed with Error \(error.localizedDescription)")
        self.protectedOperationError = error
      }

      // This needs to be critical section or race condition between many childrens' completion can occur
      var childOperationsPending = true
      SwiftMutex.lock(&self.criticalMutex)
      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 { childOperationsPending = false }
      SwiftMutex.unlock(&self.criticalMutex)
      
      if !childOperationsPending {
        callback?(self.protectedOperationError)
      }
    }
  }
  
  
  // Function to delete this object
  func deleteObject(from location: StorageLocation, type localType: LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    
    switch location {
    case .local:
      delegate.delete(from: localType, withBlock: callback)
    case .both:
      delegate.deleteFromLocalNServer(withBlock: callback)
    }
  }
  
  
  // Function to retrieve if the Download status calls for
  func retrieveIfPending(withBlock callback: SimpleErrorBlock?) -> Bool {
    
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
        CCLog.fatal("delegate not expected to be nil in retrieveIfPending()")
      }
      delegateObj.retrieveRecursive(from: .both, type: .cache, forceAnyways: false) { error in
        
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
      CCLog.warning("FoodieObject.checkRetrieved() state unexpected")
    }
    
    SwiftMutex.unlock(&operationStateMutex)
    return retrieved
  }
  
}
