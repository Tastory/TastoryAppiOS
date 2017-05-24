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
  
//  // Function for syncing Key Value Observing File Name Parse property to associated Foodie Media Object
//  func setKvoMedia(fileNameKey: String, mediaTypeKey: String?, newFileName: String?, mediaObj: FoodieMedia?) -> FoodieMedia? {
//    
//    var returnMedia: FoodieMedia?
//    let oldFileName = self[fileNameKey] as? String
//    self[fileNameKey] = newFileName
//    
//    if newFileName == nil && oldFileName != nil {
//      // mediaFileName got cleared. Remove FoodieMedia instance and clear mediaType also
//      if let typeKey = mediaTypeKey {
//        self[typeKey] = nil
//      }
//      returnMedia = nil
//    }
//      
//    else if oldFileName == nil {
//      // mediaFileName just got set. Create FoodieMedia instance if not already done so and set the fileName
//      if mediaObj == nil {
//        returnMedia = FoodieMedia()
//      } else {
//        returnMedia = mediaObj
//      }
//      returnMedia!.mediaFileName = newFileName
//    }
//      
//    else if newFileName != oldFileName {
//      // mediaFileName got modified. Modifiy the fileName in the FoodieMedia instance
//      guard mediaObj != nil else {
//        DebugPrint.fatal("Media Object nil unexpected")
//      }
//      returnMedia = mediaObj
//      returnMedia!.mediaFileName = newFileName
//    }
//    
//    return returnMedia
//  }
//  
//  
//  // Function for syncing Key Value Observing Media Type Parse property to associated Foodie Media Object
//  func setKvoMedia(mediaTypeKey: String, newMediaType: String?, mediaObj: FoodieMedia?) -> FoodieMedia? {
//    
//    var returnMedia: FoodieMedia?
//    let oldMediaType = self[mediaTypeKey] as? String
//    self[mediaTypeKey] = newMediaType
//    
//    if newMediaType == nil && oldMediaType != nil {
//      // mediaType got cleared. Clear mediaType if media object still exists
//      if mediaObj != nil {
//        mediaObj!.mediaType = nil
//      }
//      returnMedia = mediaObj
//    }
//    
//    else if oldMediaType == nil {
//      // mediaType just got set. Create FoodieMedia instance if not already done so and set the mediaType
//      if mediaObj == nil {
//        returnMedia = FoodieMedia()
//      } else {
//        returnMedia = mediaObj
//      }
//      
//      if let newMediaTypeEnum = FoodieMediaType(rawValue: newMediaType!) {
//        returnMedia!.mediaType = newMediaTypeEnum
//      } else {
//        returnMedia!.mediaType = .unknown
//      }
//    }
//    
//    else if newMediaType != oldMediaType {
//      // mediaFileName got modified. Modifiy the fileName in the FoodieMedia instance
//      guard mediaObj != nil else {
//        DebugPrint.fatal("Media Object nil unexpected")
//      }
//      returnMedia = mediaObj
//
//      if let newMediaTypeEnum = FoodieMediaType(rawValue: newMediaType!) {
//        returnMedia!.mediaType = newMediaTypeEnum
//      } else {
//        returnMedia!.mediaType = .unknown
//      }
//    }
//    
//    return returnMedia
//  }
  
  
  // Function to save this and all child Parse objects to local.
  func saveToLocal(withName name: String? = nil, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DebugPrint.verbose("")
    
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    if let name = name {
      pinInBackground(withName: name, block: callback)
    } else {
      pinInBackground(block: callback)
    }
  }
  
  
  // Function to save this and all child Parse objects to server
  func saveToServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DebugPrint.verbose("")
    
    // TODO: Maybe wanna track for Parse that only 1 Save on the top is necessary
    saveInBackground(block: callback)
  }
  
  
  // Function to delete this and all child Parse objects from local
  func deleteFromLocal(withName name: String? = nil, withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DebugPrint.verbose("")
    
    if let name = name {
      unpinInBackground(withName: name, block: callback)
    } else {
      unpinInBackground(block: callback)
    }
  }
  
  
  // Function to delete this and all child Parse objects from server
  func deleteFromServer(withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DebugPrint.verbose("")
    
    deleteInBackground(block: callback)
  }
  
}
