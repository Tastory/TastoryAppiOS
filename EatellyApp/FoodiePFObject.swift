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
  
  // MARK: - Public Static Function
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
  
  
  // MARK: - Public Instance Variable
  var foodieObject: FoodieObject!
  
  
  // MARK: - Private Instance Functions
  private func booleanToSimpleErrorCallback (_ success: Bool, _ error: Error?, function: String = #function, file: String = #file, line: Int = #line, _ callback: FoodieObject.SimpleErrorBlock?) {
    #if DEBUG  // Do this sanity check low and never need to worry about it again
      if (success && error != nil) || (!success && error == nil) {
        CCLog.fatal("Parse layer come back with Success and Error mismatch")
      }
    #endif
    
    if !success {
      CCLog.warning("\(function) Failed with Error - \(error!.localizedDescription) on line \(line) of \((file as NSString).lastPathComponent)")
    }
    callback?(error)
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
  
  
  func retrieve(from localType: FoodieObject.LocalType,  // At the Fetch stage, Parse doesn't care any more
                forceAnyways: Bool,
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
  
  
  // At the Fetch stage, Parse doesn't care about Draft vs Cache anymore. But this always saves a copy back into Cache if ultimately retrieved from Server
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
        } else {
          CCLog.debug("Pin \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()) to Name '\(FoodieObject.LocalType.cache.rawValue)'")
          self.pinInBackground(withName: FoodieObject.LocalType.cache.rawValue) { (success, error) in self.booleanToSimpleErrorCallback(success, error, nil) }
        }
        // Return if got what's wanted
        callback?(serverError)
      }
    }
  }
  
  
  func save(to localType: FoodieObject.LocalType,
            withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    CCLog.debug("Pin \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) to Local with Name \(localType.rawValue)")
    pinInBackground(withName: localType.rawValue) { success, error in self.booleanToSimpleErrorCallback(success, error, callback) }
  }
  
  
  func saveToLocalNServer(type localType: FoodieObject.LocalType,
                          withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    CCLog.debug("Pin \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) with Name \(localType.rawValue)")
    pinInBackground(withName: localType.rawValue) { (success, error) in
      
      guard success || error == nil else {
        self.booleanToSimpleErrorCallback(success, error, callback)
        return
      }
      
      CCLog.debug("Save \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()) in background")
      self.saveInBackground { success, error in self.booleanToSimpleErrorCallback(success, error, callback) }
    }
  }
  
  
  func delete(from localType: FoodieObject.LocalType,
              withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    CCLog.debug("Delete \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) from Local with Name \(localType.rawValue)")
    unpinInBackground(withName: localType.rawValue) { success, error in self.booleanToSimpleErrorCallback(success, error, callback) }
  }
  
  
  func deleteFromLocalNServer(withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // TODO: Delete should also unpin across all namespaces
    CCLog.debug("Delete \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) in Background")
    deleteInBackground { success, error in self.booleanToSimpleErrorCallback(success, error, callback) }
  }
  
  
  func getUniqueIdentifier() -> String {
    return String(describing: UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()))
  }
}
