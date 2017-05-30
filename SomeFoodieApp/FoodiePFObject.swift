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
  
  func retrieve(forceAnyways: Bool = false, withBlock callback: @escaping FoodieObject.RetrievedObjectBlock) {
    
    // See if this is already in memory, if so no need to do anything
    if isDataAvailable {
      callback(self, nil)
      return
    }
    
    // See if this is in local cache
    fetchFromLocalDatastoreInBackground { [unowned self] localObject, localError in
      
      if localError == nil {
        callback(localObject, nil)
      } else {
        DebugPrint.error("fetchFromLocalDatastore failed with error: \(localError!.localizedDescription)")
        
        // If not in Local Datastore, retrieved from Server
        self.fetchInBackground { [unowned self] serverObject, serverError in
          
          // Error handle?
          if let error = serverError {
            DebugPrint.error("fetchIfNeededInBackground failed with error: \(error.localizedDescription)")
          }
          // Return if got what's wanted
          callback(serverObject, serverError)
        }
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
