//
//  FoodiePFObject.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-05-15.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import Parse
import Foundation


// Abstract Class for Foodie Objects based on PFObject
class FoodiePFObject: PFObject {

  // MARK: - Public Instance Functions
  
  func retrieve(forceAnyways: Bool = false, withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    
    // See if this is already in memory, if so no need to do anything
    if isDataAvailable && !forceAnyways {  // TODO: Does isDataAvailabe need critical mutex protection?
      callback?(self, nil)
      return
      
    } else if forceAnyways {
      fetchInBackground() { serverObject, serverError in
        
        // Error handle?
        if let error = serverError {
          DebugPrint.error("fetchIfNeededInBackground failed with error: \(error.localizedDescription)")
        }
        // Return if got what's wanted
        callback?(serverObject, serverError)
      }
      return
    }
    
    // See if this is in local cache
    fetchFromLocalDatastoreInBackground { /*[unowned self]*/ localObject, localError in
      
      guard let err = localError else {
        guard let object = localObject else {
          DebugPrint.fatal("fetchFromLocalDatastoreInBackground completed with no error but nil object returned")
        }
        // This is actually success case here! localError is nil!
        callback?(object, nil)
        return
      }

      let nsError = err as NSError
      if nsError.domain == PFParseErrorDomain && nsError.code == PFErrorCode.errorCacheMiss.rawValue {
        DebugPrint.log("fetchFromLocalDatastore Parse cache miss")
      } else {
        DebugPrint.assert("fetchFromLocalDatastore failed with error: \(err.localizedDescription)")
        return
      }

      // If not in Local Datastore, retrieved from Server
      self.fetchInBackground { serverObject, serverError in
        
        // Error handle?
        if let error = serverError {
          DebugPrint.error("fetchIfNeededInBackground failed with error: \(error.localizedDescription)")
        }
        // Return if got what's wanted
        callback?(serverObject, serverError)
      }
    }
  }
  
  
  // Function to save this and all child Parse objects to local.
  func saveToLocal(withName name: String? = nil, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DebugPrint.verbose("FoodiePFObject.saveToLocal")
    
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    if let name = name {
      pinInBackground(withName: name, block: callback)
    } else {
      pinInBackground(block: callback)
    }
  }
  
  
  // Function to save this and all child Parse objects to server
  func saveToServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DebugPrint.verbose("FoodiePFObject.saveToServer")
    
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    saveInBackground(block: callback)
  }
  
  
  // Function to delete this and all child Parse objects from local
  func deleteFromLocal(withName name: String? = nil, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DebugPrint.verbose("FoodiePFObject.deleteFromLocal")
    
    if let name = name {
      unpinInBackground(withName: name, block: callback)
    } else {
      unpinInBackground(block: callback)
    }
  }
  
  
  // Function to delete this and all child Parse objects from server
  func deleteFromServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DebugPrint.verbose("FoodiePFObject.deleteFromServer")
    
    deleteInBackground(block: callback)
  }
  
  
  func getUniqueIdentifier() -> String {
    return String(describing: UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()))
  }
}
