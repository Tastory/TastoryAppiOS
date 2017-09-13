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
  
  
  func retrieve(forceAnyways: Bool = false, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // See if this is already in memory, if so no need to do anything
    if isDataAvailable && !forceAnyways {  // TODO: Does isDataAvailabe need critical mutex protection?
      DispatchQueue.global(qos: .userInitiated).async { callback?(nil) }
      return
      
    } else if forceAnyways {
      fetchInBackground() { serverObject, serverError in
        
        // Error handle?
        if let error = serverError {
          CCLog.warning("fetchIfNeededInBackground failed with error: \(error.localizedDescription)")
          if let delegate = self.foodieObject.delegate {
            CCLog.warning("Failure on \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier())")
          }
        }
        // Return if got what's wanted
        callback?(serverError)
      }
      return
    }
    
    // See if this is in local cache
    fetchFromLocalDatastoreInBackground { localObject, localError in
      
      guard let err = localError else {
        // This is actually success case here! localError is nil!
        callback?(nil)
        return
      }

      let nsError = err as NSError
      if nsError.domain == PFParseErrorDomain && nsError.code == PFErrorCode.errorCacheMiss.rawValue {
        CCLog.debug("fetchFromLocalDatastore Parse cache miss")
      } else {
        CCLog.assert("fetchFromLocalDatastore failed with error: \(err.localizedDescription)")
        if let delegate = self.foodieObject.delegate {
          CCLog.warning("Failure on \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier())")
        }
        return
      }

      // If not in Local Datastore, retrieved from Server
      self.fetchInBackground { serverObject, serverError in
        
        // Error handle?
        if let error = serverError {
          CCLog.warning("fetchIfNeededInBackground failed with error: \(error.localizedDescription)")
          if let delegate = self.foodieObject.delegate {
            CCLog.warning("Failure on \(delegate.foodieObjectType()), Session ID: \(self.getUniqueIdentifier())")
          }
        }
        // Return if got what's wanted
        callback?(serverError)
      }
    }
  }
  
  
  // Function to save this and all child Parse objects to local.
  func saveToLocal(withName name: String? = nil, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    CCLog.debug("FoodiePFObject.saveToLocal with name '\(name ?? "")', session ID \(self.getUniqueIdentifier())")
    
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    if let name = name {
      pinInBackground(withName: name, block: callback)
    } else {
      pinInBackground(block: callback)
    }
  }
  
  
  // Function to save this and all child Parse objects to server
  func saveToServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    CCLog.debug("FoodiePFObject.saveToServer")
    
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    saveInBackground(block: callback)
  }
  
  
  // Function to delete this and all child Parse objects from local
  func deleteFromLocal(withName name: String? = nil, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    CCLog.debug("FoodiePFObject.deleteFromLocal with name '\(name ?? "")', session ID \(self.getUniqueIdentifier())")
    
    if let name = name {
      unpinInBackground(withName: name, block: callback)
    } else {
      unpinInBackground(block: callback)
    }
  }
  
  
  // Function to delete this and all child Parse objects from server
  func deleteFromLocalNServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    CCLog.debug("FoodiePFObject.deleteFromLocalNServer")
    
    // Delete should also unpin. Might want to double check this
    deleteInBackground(block: callback)
  }
  
  
  func getUniqueIdentifier() -> String {
    return String(describing: UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()))
  }
}
