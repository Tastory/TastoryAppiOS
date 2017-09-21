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
  
  // MARK: - Constants
  struct Constants {
    static let ParseRetryCount: Int = 5
    static let ParseRetryDelaySeconds: Double = 0.5
  }
  
  // MARK: - Public Instance Variables
  var foodieObject: FoodieObject!
  
  
  
  // MARK: - Private Static Functions
  private static func booleanToSimpleErrorCallback(_ success: Bool, _ error: Error?, function: String = #function, file: String = #file, line: Int = #line, _ callback: FoodieObject.SimpleErrorBlock?) {
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
  
  
  
  // MARK: - Public Static Functions
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
  
  
  static func deleteAll(from localType: FoodieObject.LocalType, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    unpinAllObjectsInBackground(withName: localType.rawValue) { success, error in
      booleanToSimpleErrorCallback(success, error, callback)
    }
  }
  
  
  
  // MARK: - Public Instance Functions
  
  override init() {
    super.init()
    foodieObject = FoodieObject()
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

    // See if this is in local
    CCLog.debug("Fetching \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) from \(localType) In Background")
    fetchFromLocalDatastoreInBackground { object, error in  // Fetch does not distinguish from where (draft vs cache)
      
      // Error Cases
      if let error = error {
        let nsError = error as NSError
        if nsError.domain == PFParseErrorDomain && nsError.code == PFErrorCode.errorCacheMiss.rawValue {
          CCLog.debug("Fetch \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()) from Local Datastore cache miss")
        } else {
          CCLog.warning("fetchFromLocalDatastore failed on \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()), with error: \(error.localizedDescription)")
        }
        callback?(error)
        return
      }
      
      // No Object or No Data Available
      else if object == nil || self.isDataAvailable == false {
        CCLog.debug("fetchFromLocalDatastore did not return Data Available & Object for \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier())")
        callback?(PFErrorCode.errorCacheMiss as? Error)
        return
      }
      
      // Finally the Good Case
      callback?(nil)
    }
  }
  
  
  // At the Fetch stage, Parse doesn't care about Draft vs Cache anymore. But this always saves a copy back into Cache if ultimately retrieved from Server
  func retrieveFromLocalThenServer(forceAnyways: Bool,
                                   type localType: FoodieObject.LocalType,
                                   withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    let fetchRetry = SwiftRetry()
    
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
      
      fetchRetry.start("Fetch \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier())", withCountOf: Constants.ParseRetryCount) {
        self.fetchInBackground() { object, error in  // This fetch only comes from Server
          if let error = error {
            CCLog.warning("fetchInBackground failed on \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()), with error: \(error.localizedDescription)")
            if fetchRetry.attempt(after: Constants.ParseRetryDelaySeconds, withQoS: .userInitiated) { return }
          }
          // Return if got what's wanted
          callback?(error)
        }
      }
      return
    }
    
    // See if this is in local cache
    CCLog.debug("Fetch \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) from Local Datastore In Background")
    fetchFromLocalDatastoreInBackground { localObject, localError in  // Fetch does not distinguish from where (draft vs cache)
      
      if localError == nil, localObject != nil, self.isDataAvailable == true {
        CCLog.verbose("Fetch \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()) form Local Datastore Error: \(localError?.localizedDescription ?? "Nil"), localObject: \(localObject != nil ? "True" : "False"), DataAvailable: \(self.isDataAvailable ? "True" : "False")")
        callback?(nil)
        return
      }
      
      // Error Cases
      if let error = localError {
        let nsError = error as NSError
        if nsError.domain == PFParseErrorDomain && nsError.code == PFErrorCode.errorCacheMiss.rawValue {
          CCLog.debug("Fetch \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()) from Local Datastore cache miss")
        } else {
          CCLog.warning("fetchFromLocalDatastore failed on \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()), with error: \(error.localizedDescription)")
        }
      }
      
      // No Object or No Data Available
      else if localObject == nil || self.isDataAvailable == false {
        CCLog.debug("fetchFromLocalDatastore did not return Data Available & Object for \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier())")
      }
      
      // If not in Local Datastore, retrieved from Server
      CCLog.debug("Fetch \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()) In Background")
      
      
      fetchRetry.start("Fetch \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier())", withCountOf: Constants.ParseRetryCount) {
        self.fetchIfNeededInBackground { serverObject, serverError in
          if let error = serverError {
            CCLog.warning("fetchInBackground failed on \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()), with error: \(error.localizedDescription)")
            if fetchRetry.attempt(after: Constants.ParseRetryDelaySeconds, withQoS: .userInitiated) { return }
          } else {
            CCLog.debug("Pin \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()) to Name '\(localType)'")
            self.pinInBackground(withName: localType.rawValue) { (success, error) in FoodiePFObject.booleanToSimpleErrorCallback(success, error, nil) }
          }
          // Return if got what's wanted
          callback?(serverError)
        }
      }
    }
  }
  
  
  func save(to localType: FoodieObject.LocalType,
            withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    CCLog.debug("Pin \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) to Local with Name \(localType)")
    pinInBackground(withName: localType.rawValue) { success, error in FoodiePFObject.booleanToSimpleErrorCallback(success, error, callback) }
  }
  
  
  func saveToLocalNServer(type localType: FoodieObject.LocalType,
                          withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    CCLog.debug("Pin \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) with Name \(localType)")
    pinInBackground(withName: localType.rawValue) { (success, error) in
      
      guard success || error == nil else {
        FoodiePFObject.booleanToSimpleErrorCallback(success, error, callback)
        return
      }
      
      CCLog.debug("Save \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier()) in background")
      
      let saveRetry = SwiftRetry()
      saveRetry.start("Save \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier())", withCountOf: Constants.ParseRetryCount) {
        
        self.saveInBackground { success, error in
          if !success || error != nil {
            if saveRetry.attempt(after: Constants.ParseRetryDelaySeconds, withQoS: .userInitiated) { return }
          }
          FoodiePFObject.booleanToSimpleErrorCallback(success, error, callback)
        }
      }
    }
  }
  
  
  func delete(from localType: FoodieObject.LocalType,
              withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    CCLog.debug("Delete \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) from Local with Name \(localType)")
    unpinInBackground(withName: localType.rawValue) { success, error in FoodiePFObject.booleanToSimpleErrorCallback(success, error, callback) }
  }
  
  
  func deleteFromLocalNServer(withBlock callback: FoodieObject.SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // TODO: Delete should also unpin across all namespaces
    CCLog.debug("Delete \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier()) in Background")
    
    let deleteRetry = SwiftRetry()
    deleteRetry.start("Delete \(delegate.foodieObjectType()), Session ID: \(getUniqueIdentifier())", withCountOf: Constants.ParseRetryCount) {
      
      self.deleteInBackground { success, error in
        if !success || error != nil {
          if deleteRetry.attempt(after: Constants.ParseRetryDelaySeconds, withQoS: .userInitiated) { return }
        }
        FoodiePFObject.booleanToSimpleErrorCallback(success, error, callback)
      }
    }
  }
  
  
  func getUniqueIdentifier() -> String {
    return String(describing: UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()))
  }
}
