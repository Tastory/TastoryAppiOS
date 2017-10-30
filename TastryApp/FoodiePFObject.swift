//
//  FoodiePFObject.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-05-15.
//  Copyright © 2017 Tastry. All rights reserved.
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
  
  
  
  // MARK: - Public Static Functions
  static func pfConfigure() {
    Parse.enableLocalDatastore()
    
    let configuration = ParseClientConfiguration {
      $0.applicationId = "805rmSX7npRyRAW3LtLnvLRCQBp2WjkJW5R6JSWl"
      $0.clientKey = "2yOnbmdJkOTIXgBh1vO3NoixdkU79Ar72pr75fsR"
      $0.server = "https://parseapi.back4app.com"
      $0.isLocalDatastoreEnabled = true
    }
    Parse.initialize(with: configuration)
    
    // For Parse Subclassing
    // FoodieObject is an Abstract! Don't Register!!
    FoodieStory.registerSubclass()
    FoodieVenue.registerSubclass()
    FoodieCategory.registerSubclass()
    FoodieMoment.registerSubclass()
    FoodieMarkup.registerSubclass()
  }
  
  
  static func deleteAll(from localType: FoodieObject.LocalType, withBlock callback: SimpleErrorBlock?) {
    unpinAllObjectsInBackground(withName: localType.rawValue) { success, error in
      FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback)
    }
  }
  
  
  static func cancelAll() {
    // Nothing to Cancel for PFObjects. Return
    return
  }
  
  
  // MARK: - Public Instance Functions
  
  override init() {
    super.init()
    foodieObject = FoodieObject()
  }
  
  
  var isRetrieved: Bool { return isDataAvailable }
  
  
  func retrieve(from localType: FoodieObject.LocalType,  // At the Fetch stage, Parse doesn't care any more
                forceAnyways: Bool,
                withBlock callback: SimpleErrorBlock?) {
    
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // See if this is already in memory, if so no need to do anything
    if isDataAvailable && !forceAnyways {  // TODO: Does isDataAvailabe need critical mutex protection?
      CCLog.debug("\(delegate.foodieObjectType())(\(getUniqueIdentifier())) Data Available and not Forcing Anyways. Calling back with nil")
      callback?(nil)
      return
    }

    // See if this is in local
    CCLog.debug("Fetching \(delegate.foodieObjectType())(\(getUniqueIdentifier())) from \(localType) In Background")
    fetchFromLocalDatastoreInBackground { object, error in  // Fetch does not distinguish from where (draft vs cache)
      
      // Error Cases
      if let error = error {
        let nsError = error as NSError
        if nsError.domain == PFParseErrorDomain && nsError.code == PFErrorCode.errorCacheMiss.rawValue {
          CCLog.debug("Fetch \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) from Local Datastore cache miss")
        } else {
          CCLog.warning("fetchFromLocalDatastore failed on \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) with error: \(error.localizedDescription)")
        }
        callback?(error)
        return
      }
      
      // No Object or No Data Available
      else if object == nil || self.isDataAvailable == false {
        CCLog.assert("fetchFromLocalDatastore did not return Data Available & Object for \(delegate.foodieObjectType())(\(self.getUniqueIdentifier()))")
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
                                   withReady readyBlock: SimpleBlock? = nil,
                                   withCompletion callback: SimpleErrorBlock?) {
    
    let fetchRetry = SwiftRetry()
    
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // See if this is already in memory, if so no need to do anything
    if isDataAvailable && !forceAnyways {  // TODO: Does isDataAvailabe need critical mutex protection?
      CCLog.debug("\(delegate.foodieObjectType())(\(getUniqueIdentifier())) Data Available and not Forcing Anyways. Calling back with nil")
      callback?(nil)
      return
    }
    
    // If force anyways, try to fetch
    else if forceAnyways {
      CCLog.debug("Forced to fetch \(delegate.foodieObjectType())(\(getUniqueIdentifier())) In Background")
      
      fetchRetry.start("Fetch \(delegate.foodieObjectType())(\(self.getUniqueIdentifier()))", withCountOf: Constants.ParseRetryCount) { [unowned self] in

        if(self.isDirty) {
          self.revert() 
        }

        self.fetchInBackground() { object, error in  // This fetch only comes from Server
          if let error = error {
            CCLog.warning("fetchInBackground failed on \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) with error: \(error.localizedDescription)")
            if fetchRetry.attempt(after: Constants.ParseRetryDelaySeconds, withQoS: .utility) { return }
          }
          // Return if got what's wanted
          callback?(error)
        }
      }
      return
    }
    
    // See if this is in local cache
    CCLog.debug("Fetch \(delegate.foodieObjectType())(\(getUniqueIdentifier())) from Local Datastore In Background")
    fetchFromLocalDatastoreInBackground { localObject, localError in  // Fetch does not distinguish from where (draft vs cache)
      
      if localError == nil, localObject != nil, self.isDataAvailable == true {
        CCLog.verbose("Fetch \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) form Local Datastore Error: \(localError?.localizedDescription ?? "Nil"), localObject: \(localObject != nil ? "True" : "False"), DataAvailable: \(self.isDataAvailable ? "True" : "False")")
        callback?(nil)
        return
      }
      
      // Error Cases
      if let error = localError {
        let nsError = error as NSError
        if nsError.domain == PFParseErrorDomain && nsError.code == PFErrorCode.errorCacheMiss.rawValue {
          CCLog.debug("Fetch \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) from Local Datastore cache miss")
        } else {
          CCLog.warning("fetchFromLocalDatastore failed on \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) with error: \(error.localizedDescription)")
        }
      }
      
      // No Object or No Data Available
      else if localObject == nil || self.isDataAvailable == false {
        CCLog.debug("fetchFromLocalDatastore did not return Data Available & Object for \(delegate.foodieObjectType())(\(self.getUniqueIdentifier()))")
      }
      
      // If not in Local Datastore, retrieved from Server
      CCLog.debug("Fetch \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) In Background")
      
      
      fetchRetry.start("Fetch \(delegate.foodieObjectType())(\(self.getUniqueIdentifier()))", withCountOf: Constants.ParseRetryCount) { [unowned self] in
        self.fetchIfNeededInBackground { serverObject, serverError in
          if let error = serverError {
            CCLog.warning("fetchInBackground failed on \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())), with error: \(error.localizedDescription)")
            if fetchRetry.attempt(after: Constants.ParseRetryDelaySeconds, withQoS: .utility) { return }
          } else {
            CCLog.debug("Pin \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) to Name '\(localType)'")
            self.pinInBackground(withName: localType.rawValue) { (success, error) in FoodieGlobal.booleanToSimpleErrorCallback(success, error, nil) }
          }
          // Return if got what's wanted
          callback?(serverError)
        }
      }
    }
  }
  
  
  func save(to localType: FoodieObject.LocalType,
            withBlock callback: SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    CCLog.debug("Pin \(delegate.foodieObjectType())(\(getUniqueIdentifier())) to Local with Name \(localType)")
    pinInBackground(withName: localType.rawValue) { success, error in FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback) }
  }
  
  
  func saveToLocalNServer(type localType: FoodieObject.LocalType,
                          withBlock callback: SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    CCLog.debug("Pin \(delegate.foodieObjectType())(\(getUniqueIdentifier())) with Name \(localType)")
    pinInBackground(withName: localType.rawValue) { (success, error) in
      
      guard success || error == nil else {
        FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback)
        return
      }
      
      CCLog.debug("Save \(delegate.foodieObjectType())(\(self.getUniqueIdentifier())) in background")
      
      let saveRetry = SwiftRetry()
      saveRetry.start("Save \(delegate.foodieObjectType())(\(self.getUniqueIdentifier()))", withCountOf: Constants.ParseRetryCount) { [unowned self] in
        
        self.saveInBackground { success, error in
          if !success || error != nil {
            if saveRetry.attempt(after: Constants.ParseRetryDelaySeconds, withQoS: .utility) { return }
          }
          FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback)
        }
      }
    }
  }
  
  
  func delete(from localType: FoodieObject.LocalType,
              withBlock callback: SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }

    if(isDirty) {
      revert()
    }

    CCLog.debug("Delete \(delegate.foodieObjectType())(\(getUniqueIdentifier())) from Local with Name \(localType)")
    unpinInBackground(withName: localType.rawValue) { success, error in FoodieGlobal.booleanToSimpleErrorCallback(success, error, callback) }
  }

  func deleteFromLocalNServer(withBlock callback: SimpleErrorBlock?) {
    guard let delegate = foodieObject.delegate else {
      CCLog.fatal("No Foodie Object Delegate 'aka yourself'. Fatal and cannot proceed")
    }
    
    // TODO: Delete should also unpin across all namespaces
    CCLog.debug("Delete \(delegate.foodieObjectType())(\(getUniqueIdentifier())) in Background")
    
    let deleteRetry = SwiftRetry()
    deleteRetry.start("Delete \(delegate.foodieObjectType())(\(getUniqueIdentifier()))", withCountOf: Constants.ParseRetryCount) { [unowned self] in
      
      self.deleteInBackground { success, error in
        if !success || error != nil {
          if deleteRetry.attempt(after: Constants.ParseRetryDelaySeconds, withQoS: .utility) { return }
        }
        
        // Each call actually goes through a booleanToSimpleErrorCallback(). So will do a CCLog.warning natively. Should just brute force deletes regardless
        FoodieGlobal.booleanToSimpleErrorCallback(success, error) { error in
          self.delete(from: .draft) { error in
            self.delete(from: .cache, withBlock: callback)
          }
        }
      }
    }
  }
  
  
  func setPermission(to permission: FoodiePermission) {
    self.acl = permission as PFACL
  }
  
  
  func getUniqueIdentifier() -> String {
    return String(describing: UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()))
  }
}
