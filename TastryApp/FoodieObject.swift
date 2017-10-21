 //
//  FoodieObject.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-04-05.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Foundation

 
protocol FoodieObjectDelegate: class {

  /********************************************************************************************************************
   *
   *  Make sure no function directly calls 'callback?()' !!!
   *  The recursive callers always expects the callback to be called async from an equal or lower priority thread.
   *  If the first child returns a callback immediately, it's possible for outstanding to prematurely hit == 0, 
   *  This triggers pre-mature, and also duplicate, parent callbacks.
   *
   ********************************************************************************************************************/
  
  var isRetrieved: Bool { get }
  
  static func deleteAll(from localType: FoodieObject.LocalType,
                        withBlock callback: SimpleErrorBlock?)
  
  static func cancelAll()
  
  func retrieve(from localType: FoodieObject.LocalType,
                forceAnyways: Bool,
                withBlock callback: SimpleErrorBlock?)
  
  func retrieveFromLocalThenServer(forceAnyways: Bool,
                                   type: FoodieObject.LocalType,
                                   withReady readyBlock: SimpleBlock?,
                                   withCompletion callback: SimpleErrorBlock?)
  
  func retrieveRecursive(from location: FoodieObject.StorageLocation,
                         type localType: FoodieObject.LocalType,
                         forceAnyways: Bool,
                         withReady readyBlock: SimpleBlock?,
                         withCompletion callback: SimpleErrorBlock?)
  
  func save(to localType: FoodieObject.LocalType,
            withBlock callback: SimpleErrorBlock?)
  
  func saveToLocalNServer(type localType: FoodieObject.LocalType,
                          withBlock callback: SimpleErrorBlock?)
  
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     withBlock callback: SimpleErrorBlock?)
  
  
  func delete(from localType: FoodieObject.LocalType,
              withBlock callback: SimpleErrorBlock?)
  
  func deleteFromLocalNServer(withBlock callback: SimpleErrorBlock?)  // Always whacks all
  
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       withBlock callback: SimpleErrorBlock?)
  
  func cancelRetrieveFromServerRecursive()
  
  func cancelSaveToServerRecursive()
  
  func getUniqueIdentifier() -> String
  
  func foodieObjectType() -> String
}


 
class FoodieObject {
  
  // MARK: - Types & Enumerations
  
  enum RetrieveStates: String {
    case notAvailable       = "notAvailable"
    case pendingRetrieval   = "pendingRetrieval"
    case retrieving         = "retrieving"
    case objectSynced       = "objectSynced"
  }
  
  
  enum LocalType: String {
    case cache = "FoodieCache"
    case draft = "FoodieDraft"
  }
  
  
  enum StorageLocation: String {
    case local
    case both
  }
  
  
  
  // Mark: - Constants
  struct Constants {
    static let RecursiveOpQoS = DispatchQoS.QoSClass.userInitiated
  }
  
  
  
  // MARK: - Error Types
  
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
        return NSLocalizedString("Failed to retrieve story", comment: "Error description for an exception error code")
      }
    }
  
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  
  // MARK: - Public Instance Variables
  
  weak var delegate: FoodieObjectDelegate?
  

  
  // MARK: - Private Instance Variables
  
  fileprivate(set) var operationError: Error? = nil
  fileprivate var retrieveStateMutex = SwiftMutex.create()
  fileprivate(set) var retrieveState: RetrieveStates = .notAvailable
  var outstandingChildOperationsMutex = SwiftMutex.create()
  fileprivate var outstandingChildOperations = 0
  var outstandingChildReadiesMutex = SwiftMutex.create()
  fileprivate var outstandingChildReadies = 0
  fileprivate var outstandingChildRequestsAllSent = false
  
  
  // MARK: - Public Static Functions
  
  static func deleteAll(from localType: LocalType, withBlock callback: SimpleErrorBlock?) {
    FoodiePFObject.deleteAll(from: localType) { error in
      FoodieFileObject.deleteAll(from: localType, withBlock: callback)
    }
  }
  
  
  
  // MARK: - Public Instance Functions
  
  // Reset outstandingChildOperations
  func resetChildOperationVariables() {
    operationError = nil
    outstandingChildOperations = 0
    outstandingChildReadies = 0
    outstandingChildRequestsAllSent = false
  }
  
  
  // Function to mark pending retrieval
  func markPendingRetrieval() {
    
    SwiftMutex.lock(&retrieveStateMutex)  // TODO-Performance: To be removed? Otherwise make sure this never gets executed in Main Thread?
    
    switch retrieveState {
    case .notAvailable:
      retrieveState = .pendingRetrieval
      
    case .objectSynced, .pendingRetrieval, .retrieving:
      // Expected states to do nothing on
      break
    }
    
    SwiftMutex.unlock(&retrieveStateMutex)
  }
  
  
  func retrieveChild(_ child: FoodieObjectDelegate, from location: StorageLocation, type localType: LocalType, forceAnyways: Bool, withReady readyBlock: SimpleBlock? = nil, withCompletion callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    
    outstandingChildReadies += 1
    outstandingChildOperations += 1
    //CCLog.debug("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) retrieve child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) from Location: \(location), LocalType: \(localType), Readies: \(self.outstandingChildReadies), Outstanding: \(self.outstandingChildOperations)")
    
    child.retrieveRecursive(from: location, type: localType, forceAnyways: forceAnyways, withReady: {
      
      // This needs to be critical section or race condition between many childrens' completion can occur
      var childReadiesPending = true
      SwiftMutex.lock(&self.outstandingChildReadiesMutex)
      self.outstandingChildReadies -= 1
      let afterReadies = self.outstandingChildReadies
      if self.outstandingChildReadies == 0 { childReadiesPending = false }
      SwiftMutex.unlock(&self.outstandingChildReadiesMutex)
      
      CCLog.debug("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) readied child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) from Location: \(location), LocalType: \(localType), Readies: \(afterReadies)")
      
      if !childReadiesPending {
        readyBlock?()
      }
      
    }, withCompletion: { error in
      if let error = error {
        CCLog.warning("retrieveChild on \(child.foodieObjectType())(\(child.getUniqueIdentifier())) failed with Error \(error.localizedDescription)")
        self.operationError = error
      }
      
      // This needs to be critical section or race condition between many childrens' completion can occur
      var childOperationsPending = true
      SwiftMutex.lock(&self.outstandingChildOperationsMutex)
      self.outstandingChildOperations -= 1
      let afterOutstanding = self.outstandingChildOperations
      if self.outstandingChildOperations == 0 { childOperationsPending = false }
      SwiftMutex.unlock(&self.outstandingChildOperationsMutex)
      
      CCLog.debug("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) retrieved child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) from Location: \(location), LocalType: \(localType), Outstanding: \(afterOutstanding)")
      
      if !childOperationsPending {
        callback?(self.operationError)
      }
    })
  }
  
  
  func retrieveObject(from location: StorageLocation, type localType: LocalType, forceAnyways: Bool, withBlock callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    
    switch location {
    case .local:
      delegate.retrieve(from: localType, forceAnyways: forceAnyways, withBlock: callback)
    case .both:
      delegate.retrieveFromLocalThenServer(forceAnyways: forceAnyways, type: localType, withReady: nil, withCompletion: callback)
    }
  }
  
  
  // Function when all child saves have completed
  func savesCompletedFromAllChildren(to location: StorageLocation, type localType: LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    
    // If children all came back and there is error, unwind state and call callback
    if operationError != nil {
      DispatchQueue.global(qos: Constants.RecursiveOpQoS).async {  // Guarentee that callback comes back async from another thread
        callback?(self.operationError)
      }
    }
      
    // If children all came back and no error, Save yourself!
    else {
      saveObject(to: location, type: localType) { error in
        if let error = error {
          CCLog.warning("Saving Object \(delegate.foodieObjectType()) \(delegate.getUniqueIdentifier()) to \(location), \(localType) Failed - \(error.localizedDescription)")
          self.operationError = error
        }
        callback?(self.operationError)
      }
    }
  }
  
  
  // Function to call a child's saveRecursive
  func saveChild(_ child: FoodieObjectDelegate, to location: StorageLocation, type localType: LocalType, withBlock callback: SimpleErrorBlock?) {
//    guard let delegate = delegate else {
//      CCLog.fatal("delegate = nil. Unable to proceed.")
//    }
    //CCLog.debug("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) Saving Child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) to Location: \(location), LocalType: \(localType)")
    
    outstandingChildOperations += 1
    
    // Save Recursive for each children. Call saveCompletionFromChild when done and without errors
    child.saveRecursive(to: location, type: localType) { error in
      if let error = error {
        CCLog.warning("saveChild on \(child.foodieObjectType())(\(child.getUniqueIdentifier())) failed with Error \(error.localizedDescription)")
        self.operationError = error
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
//    guard let delegate = delegate else {
//      CCLog.fatal("delegate = nil. Unable to proceed.")
//    }
    //CCLog.debug("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) Delete Child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) to Location: \(location), LocalType: \(localType)")
    
    // Lock here is in case that if the first operation competes and calls back before even the 2nd op's deleteChild goes out
    self.outstandingChildOperations += 1
    
    // Delete Recursive for each children
    child.deleteRecursive(from: location, type: localType) { error in
      if let error = error {
        CCLog.warning("deleteChild on \(child.foodieObjectType())(\(child.getUniqueIdentifier())) failed with Error \(error.localizedDescription)")
        self.operationError = error
      }

      // This needs to be critical section or race condition between many childrens' completion can occur
      var childOperationsPending = true
      SwiftMutex.lock(&self.outstandingChildOperationsMutex)
      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 { childOperationsPending = false }
      SwiftMutex.unlock(&self.outstandingChildOperationsMutex)
      
      if !childOperationsPending {
        callback?(self.operationError)
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
}
