//
//  FoodieMoment.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-31.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//


import Parse

class FoodieMoment: FoodiePFObject {
  
  // MARK: - Parse PFObject keys
  // If new objects or external types are added here, check if save and delete algorithms needs updating
  @NSManaged var foodieFileName: String?  //{  // File name for the media photo or video. Needs to go with the media object.
    
    // Manual implementation of @NSManaged to link the associated FoodieMedia instance with this Parse property
//    get {
//      return self["foodieFileName"] as? String
//    }
//    
//    set {
//      mediaObject = setKvoMedia(fileNameKey: "foodieFileName", mediaTypeKey: "mediaType", newFileName: newValue, mediaObj: mediaObject)
//    }
//  }
  
  @NSManaged var mediaType: String? //{  // Really an enum saying whether it's a Photo or Video
    
    // Manual implementation of @NSManaged to link the associated FoodieMedia instance with this Parse property
//    get {
//      return self["mediaType"] as? String
//    }
//    
//    set {
//      mediaObject = setKvoMedia(mediaTypeKey: "mediaType", newMediaType: newValue, mediaObj: mediaObject)
//    }
//  }
  
  @NSManaged var aspectRatio: Double  // In decimal, width / height, like 16:9 = 16/9 = 1.777...
  @NSManaged var width: Int  // height = width / aspectRatio
  @NSManaged var markups: Array<FoodieMarkup>?  // Array of PFObjects as FoodieMarkup
  @NSManaged var tags: Array<String>?  // Array of Strings, unstructured
  @NSManaged var thumbnailFileName: String?  // Thumbnail for the moment
  
  // Query Pointers
  @NSManaged var author: FoodieUser?  // Pointer to the user that authored this Moment
  @NSManaged var eatery: FoodieEatery?  // Pointer to the FoodieEatery object
  @NSManaged var categories: Array<Int>?  // Array of internal restaurant categoryIDs (all cateogires that applies, sub or primary)
  
  // Optional
  @NSManaged var type: Int  // Really an enum saying whether this describes the dish, interior, or exterior, Optional
  @NSManaged var attribute: String?  // Attribute related to the type. Eg. Dish name, Optional
  
  // Analytics
  @NSManaged var views: Int  // How many times have this Moment been viewed
  @NSManaged var clickthroughs: Int  // How many times have this been clicked through to the next
  
  // Date created vs Date updated is given for free
  
  
  // MARK: - Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case setMediaWithPhotoImageNil
    case setMediaWithPhotoJpegRepresentationFailed
    
    var errorDescription: String? {
      switch self {
      case .setMediaWithPhotoImageNil:
        return NSLocalizedString("setMedia failed, photoImage = nil", comment: "Error description for an exception error code")
      case .setMediaWithPhotoJpegRepresentationFailed:
        return NSLocalizedString("setMedia failed, cannot create JPEG representation", comment: "Error description for an exception error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      DebugPrint.error(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Public Instance Variable
  var mediaObject: FoodieMedia! {
    didSet {
      foodieFileName = mediaObject.foodieFileName
      mediaType = mediaObject.mediaType?.rawValue
    }
  }
  
  var thumbnailObject: FoodieMedia? {
    didSet {
      thumbnailFileName = thumbnailObject!.foodieFileName
    }
  }
  
  var foodieObject = FoodieObject()
  
  
  // MARK: - Public Functions
  override init() {
    super.init()
    foodieObject.delegate = self
  }
  
  init(foodieMedia: FoodieMedia) {
    super.init()
    foodieObject.delegate = self
    mediaObject = foodieMedia
  }
}


// MARK: - Foodie Object Delegate Conformance
extension FoodieMoment: FoodieObjectDelegate {
  
  // Function for processing a completion from a child save
  func saveCompletionFromChild(to location: FoodieObject.StorageLocation,
                               withName name: String?,
                               withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    DebugPrint.verbose("to Location: \(location)")
    
    var keepWaiting = false
    
    // Determine if all children are ready, if not, keep waiting.
    if let media = mediaObject {
      if !media.foodieObject.isSaveCompleted(to: location) { keepWaiting = true }
    }
    
    if let hasMarkups = markups, !keepWaiting {
      for markup in hasMarkups {
        if !markup.foodieObject.isSaveCompleted(to: location) { keepWaiting = true; break }
      }
    }
    
    if !keepWaiting {
      foodieObject.savesCompletedFromAllChildren(to: location, withName: name, withBlock: callback)
    }
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     withName name: String? = nil,
                     withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    DebugPrint.verbose("to Location: \(location)")
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
    
    if let earlySuccess = earlyReturnStatus.success {
      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
      return
    }
    
    var childOperationPending = false
    
    // Need to make sure all children FoodieRecursives saved before proceeding
    if let media = mediaObject {
      foodieObject.saveChild(media, to: location, withName: name, withBlock: callback)
      childOperationPending = true
    }
    
    if let hasMarkups = markups {
      for markup in hasMarkups {
        foodieObject.saveChild(markup, to: location, withName: name, withBlock: callback)
        childOperationPending = true
      }
    }
    
    if !childOperationPending {
      DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
        self.foodieObject.savesCompletedFromAllChildren(to: location, withBlock: callback)
      }
    }
  }
  
  
  // Trigger recursive saves against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       withName name: String? = nil,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
  }
  
  
  func foodieObjectType() -> String {
    return "FoodieMoment"
  }
}

 
extension FoodieMoment: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieMoment"
  }
}
