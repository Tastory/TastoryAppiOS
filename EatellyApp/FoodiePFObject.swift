//
//  FoodiePFObject.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-05-15.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import Parse
import Foundation


// Abstract Class for Foodie Objects based on PFObject
class FoodiePFObject: PFObject {

  // MARK: - Public Instance Variable
  var foodieObject: FoodieObject!
  
  
  // MARK: - Public Static Variable
  static func configure() {
    Parse.enableLocalDatastore()
    
    let configuration = ParseClientConfiguration {
      $0.applicationId = "kU2qQku1Qs5O46bScrRqsNmPL3f1NNQV7vnHYD7h"
      $0.clientKey = "JDcmBhFZ5Uiioy2tE6WKfw717CeAA1PzMWknrCQU"
      $0.server = "https://parseapi.back4app.com"
      $0.isLocalDatastoreEnabled = true
    }
    Parse.initialize(with: configuration)
    
    // For Parse Subclassing
    // FoodieObject is an Abstract! Don't Register!!
    FoodieUser.registerSubclass()
    FoodieJournal.registerSubclass()
    FoodieVenue.registerSubclass()
    FoodieCategory.registerSubclass()
    FoodieMoment.registerSubclass()
    FoodieMarkup.registerSubclass()
    FoodieHistory.registerSubclass()
  }
  
  
  // MARK: - Public Instance Functions
  override init() {
    super.init()
    CCLog.debug("FoodiePFObject.init() called with no initial state specified. Defaulting to .notAvailable")
    foodieObject = FoodieObject(withState: .notAvailable)
  }
  
  
  init(withState operationState: FoodieObject.OperationStates) {
    super.init()
    foodieObject = FoodieObject(withState: operationState)
  }
  
  
  func retrieveFromLocal(forceAnyways: Bool,
                         withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // See if this is already in memory, if so no need to do anything
    if isDataAvailable && !forceAnyways {  // TODO: Does isDataAvailabe need critical mutex protection?
      CCLog.debug("\(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()). Data Available and not Forcing Anyways. Calling back with nil")
      DispatchQueue.global(qos: .userInitiated).async { callback?(nil) }  // Calling back in a different thread, because sometimes we might still be in main thread all the way from the caller
      return
    }

    // See if this is in local cache
    CCLog.debug("Fetching \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) from Local Datastore In Background")
    fetchFromLocalDatastoreInBackground { localObject, localError in
      guard let error = localError else {
        callback?(nil)  // This is actually success case here! localError is nil!
        return
      }
      
      let nsError = error as NSError
      if nsError.domain == PFParseErrorDomain && nsError.code == PFErrorCode.errorCacheMiss.rawValue {
        CCLog.debug("Fetch \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()) from Local Datastore Cache cache miss")
      } else {
        CCLog.warning("fetchFromLocalDatastore failed on \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()), with error: \(error.localizedDescription)")
      }
      
      callback?(localError)
    }
  }
  
  
  func retrieveFromLocalThenServer(forceAnyways: Bool,
                                   withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // See if this is already in memory, if so no need to do anything
    if isDataAvailable && !forceAnyways {  // TODO: Does isDataAvailabe need critical mutex protection?
      CCLog.debug("\(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()). Data Available and not Forcing Anyways. Calling back with nil")
      DispatchQueue.global(qos: .userInitiated).async { callback?(nil) }  // Calling back in a different thread, because sometimes we might still be in main thread all the way from the caller
      return
    }
    
    // If force anyways, try to fetch
    else if forceAnyways {
      CCLog.debug("Forced to fetch \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) In Background")
      fetchInBackground() { object, error in
        if let error = error {
          CCLog.warning("fetchInBackground failed on \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()), with error: \(error.localizedDescription)")
        }
        // Return if got what's wanted
        callback?(error)
      }
      return
    }
    
    // See if this is in local cache
    CCLog.debug("Fetch \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) from Local Datastore In Background")
    fetchFromLocalDatastoreInBackground { localObject, localError in
      guard let error = localError else {
        callback?(nil)  // This is actually success case here! localError is nil!
        return
      }

      let nsError = error as NSError
      if nsError.domain == PFParseErrorDomain && nsError.code == PFErrorCode.errorCacheMiss.rawValue {
        CCLog.debug("Fetch \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()) from Local Datastore Cache miss")
      } else {
        CCLog.warning("fetchFromLocalDatastore failed on \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()), with error: \(error.localizedDescription)")
      }

      // If not in Local Datastore, retrieved from Server
      CCLog.debug("Fetch \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()) In Background")
      self.fetchInBackground { serverObject, serverError in
        if let error = serverError {
          CCLog.warning("fetchInBackground failed on \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()), with error: \(error.localizedDescription)")
        }
        // Return if got what's wanted
        callback?(serverError)
      }
    }
  }
  
  
  private func booleanToSimpleErrorCallback (_ success: Bool, _ error: Error?, _ callback: FoodieObject.SimpleErrorBlock?) {
    #if DEBUG  // Do this sanity check low and never need to worry about it again
      if (success && error != nil) || (!success && error == nil) {
        CCLog.fatal("Parse layer come back with Success and Error mismatch")
      }
    #endif
    callback?(error)
  }
  
  
  func saveToLocal(withName name: String?,
                   withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    CCLog.debug("Pin \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) to Local with Name \(name ?? "nil")")
    
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    if let name = name {
      pinInBackground(withName: name) { success, error in self.booleanToSimpleErrorCallback(success, error, callback) }
    } else {
      pinInBackground { success, error in self.booleanToSimpleErrorCallback(success, error, callback) }
    }
  }
  
  
  func saveToLocalNServer(withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    CCLog.debug("Save \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) in Background")
    
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    saveInBackground { success, error in self.booleanToSimpleErrorCallback(success, error, callback) }
  }
  
  
  func deleteFromLocal(withName name: String?,
                       withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    CCLog.debug("Delete \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) from Local with Name \(name ?? "nil")")
    
    if let name = name {
      unpinInBackground(withName: name) { success, error in self.booleanToSimpleErrorCallback(success, error, callback) }
    } else {
      unpinInBackground { success, error in self.booleanToSimpleErrorCallback(success, error, callback) }
    }
  }
  
  
  func deleteFromLocalNServer(withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    CCLog.debug("Delete \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) in Background")
    
    // Delete should also unpin. Might want to double check this
    deleteInBackground { success, error in self.booleanToSimpleErrorCallback(success, error, callback) }
  }
  
  
  func getUniqueIdentifier() -> String {
    return String(describing: UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()))
  }
}
