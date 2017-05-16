//
//  FoodiePFObject.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-05-15.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import Parse
import Foundation

class FoodiePFObject: PFObject {

  // Function to save this and all child Parse objects to local.
  func saveToLocal(withName name: String? = nil, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    if let name = name {
      pinInBackground(withName: name, block: callback)
    } else {
      pinInBackground(block: callback)
    }
  }
  
  
  // Function to save this and all child Parse objects to server
  func saveToServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    saveInBackground(block: callback)
  }
  
  
  // Function to delete this and all child Parse objects from local
  func deleteFromLocal(withName name: String? = nil, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    if let name = name {
      unpinInBackground(withName: name, block: callback)
    } else {
      unpinInBackground(block: callback)
    }
  }
  
  
  // Function to delete this and all child Parse objects from server
  func deleteFromServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    deleteInBackground(block: callback)
  }
  
}
