 //
//  FoodieObject.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-04-05.
//  Copyright © 2017 Tastory. All rights reserved.
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
                         for parentOperation: AsyncOperation?,
                         withReady readyBlock: SimpleBlock?,
                         withCompletion callback: SimpleErrorBlock?) -> AsyncOperation?
  
  func save(to localType: FoodieObject.LocalType,
            withBlock callback: SimpleErrorBlock?)
  
  func saveToLocalNServer(type localType: FoodieObject.LocalType,
                          withBlock callback: SimpleErrorBlock?)
  
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     for parentOperation: AsyncOperation?,
                     withBlock callback: SimpleErrorBlock?)
  
  func saveWhole(to location: FoodieObject.StorageLocation,
                 type localType: FoodieObject.LocalType,
                 for parentOperation: AsyncOperation?,
                 withBlock callback: SimpleErrorBlock?)
  
  func delete(from localType: FoodieObject.LocalType,
              withBlock callback: SimpleErrorBlock?)
  
  func deleteFromLocalNServer(withBlock callback: SimpleErrorBlock?)  // Always whacks all
  
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       for parentOperation: AsyncOperation?,
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

  
  
  // MARK: - Error Types
  
  enum ErrorCode: LocalizedError {
    
    case saveStateTransitionNoState
    case saveStateTransitionSaveAlreadyInProgress
    case saveStateTransitionIllegalStateTransition
    
    case saveErrorOperationForbidden
    
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
     
      case .saveErrorOperationForbidden:
        return NSLocalizedString("Save error due to operation permission denied", comment: "Error description for an error in Parse Save")
        
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
  
  var operationError: Error? = nil
  var outstandingChildOperations = 0
  var outstandingChildReadies = 0
  
  
  
  // MARK: - Public Static Functions
  
  static func deleteAll(from localType: LocalType, withBlock callback: SimpleErrorBlock?) {
    FoodiePFObject.deleteAll(from: localType) { error in
      FoodieFileObject.deleteAll(from: localType, withBlock: callback)
    }
  }
  
  
  
  // MARK: - Public Instance Functions

  // Function when all child delete have completed
  func deleteCompletedFromAllChildren(to location: StorageLocation, type localType: LocalType, withBlock callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }

    // If children all came back and there is error, unwind state and call callback
    if operationError != nil {
      callback?(self.operationError)
    }

      // If children all came back and no error, delete yourself!
    else {
      deleteObject(from: location, type: localType) { error in
        if let error = error {
          CCLog.warning("Saving Object \(delegate.foodieObjectType()) \(delegate.getUniqueIdentifier()) to \(location), \(localType) Failed - \(error.localizedDescription)")
          self.operationError = error
        }
        callback?(self.operationError)
      }
    }
  }

  // Reset outstandingChildOperations
  func resetChildOperationVariables(to count: Int = 0) {
    operationError = nil
    outstandingChildOperations = count
    outstandingChildReadies = count
  }
  
  
  // Function to mark pending retrieval
  
  func retrieveChild(_ child: FoodieObjectDelegate, from location: StorageLocation, type localType: LocalType, forceAnyways: Bool, for operation: AsyncOperation?, withReady readyBlock: SimpleBlock? = nil, withCompletion callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    CCLog.verbose("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) retrieve child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) from Location: \(location), LocalType: \(localType), Readies: \(self.outstandingChildReadies), Outstanding: \(self.outstandingChildOperations)")
    
    _ = child.retrieveRecursive(from: location, type: localType, forceAnyways: forceAnyways, for: operation, withReady: {
      self.outstandingChildReadies -= 1
      if self.outstandingChildReadies == 0 { readyBlock?() }
      CCLog.verbose("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) readied child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) from Location: \(location), LocalType: \(localType), Readies: \(self.outstandingChildReadies)")
      
    }, withCompletion: { error in
      if let error = error {
        CCLog.warning("retrieveChild on \(child.foodieObjectType())(\(child.getUniqueIdentifier())) failed with Error \(error.localizedDescription)")
        self.operationError = error
      }
      
      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 { callback?(self.operationError) }
      else if self.outstandingChildOperations < 0 {
        CCLog.assert("Outstanding Child Operations below 0")
      }
      
      CCLog.verbose("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) retrieved child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) from Location: \(location), LocalType: \(localType), Outstanding: \(self.outstandingChildOperations)")
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
      callback?(self.operationError)
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
  func saveChild(_ child: FoodieObjectDelegate, to location: StorageLocation, type localType: LocalType, for operation: AsyncOperation?, withBlock callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    CCLog.verbose("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) Saving Child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) to Location: \(location), LocalType: \(localType)")
    
    // Save Recursive for each children. Call saveCompletionFromChild when done and without errors
    child.saveRecursive(to: location, type: localType, for: operation) { error in
      if let error = error {
        CCLog.warning("saveChild on \(child.foodieObjectType())(\(child.getUniqueIdentifier())) failed with Error \(error.localizedDescription)")
        self.operationError = error
      }
      
      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 {
        callback?(self.operationError)
      }
      else if self.outstandingChildOperations < 0 {
        CCLog.assert("Outstanding Child Operations below 0")
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
  func deleteChild(_ child: FoodieObjectDelegate, from location: StorageLocation, type localType: LocalType, for operation: AsyncOperation?, withBlock callback: SimpleErrorBlock?) {
    guard let delegate = delegate else {
      CCLog.fatal("delegate = nil. Unable to proceed.")
    }
    CCLog.verbose("\(delegate.foodieObjectType())(\(delegate.getUniqueIdentifier())) Delete Child of Type: \(child.foodieObjectType())(\(child.getUniqueIdentifier())) to Location: \(location), LocalType: \(localType)")
    
    // Delete Recursive for each children
    child.deleteRecursive(from: location, type: localType, for: operation) { error in
      if let error = error {
        CCLog.warning("deleteChild on \(child.foodieObjectType())(\(child.getUniqueIdentifier())) failed with Error \(error.localizedDescription)")
        self.operationError = error
      }

      self.outstandingChildOperations -= 1
      if self.outstandingChildOperations == 0 {
        callback?(self.operationError)
      }
      else if self.outstandingChildOperations < 0 {
        CCLog.assert("Outstanding Child Operations below 0")
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
