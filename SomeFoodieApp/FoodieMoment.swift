//
//  FoodieMoment.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-31.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//


import Parse

class FoodieMoment: FoodiePFObject, FoodieObjectDelegate {
  
  // MARK: - Parse PFObject keys
  // If new objects or external types are added here, check if save and delete algorithms needs updating
  @NSManaged var mediaFileName: String?  // File name for the media photo or video. Needs to go with the media object
  @NSManaged var mediaType: String?  // Really an enum saying whether it's a Photo or Video
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
  
  // this flag indicate if this moment has been retrieved from Parse
  fileprivate var hasRetrieved = false
  
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
  var mediaObj: FoodieMedia? {
    didSet {
      mediaFileName = mediaObj!.foodieFileName
      mediaType = mediaObj!.mediaType?.rawValue
    }
  }
  
  var thumbnailObj: FoodieMedia? {
    didSet {
      thumbnailFileName = thumbnailObj!.foodieFileName
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
    mediaObj = foodieMedia
    
    // didSet does not get called in initialization context...
    mediaFileName = foodieMedia.foodieFileName
    mediaType = foodieMedia.mediaType?.rawValue
  }


  // MARK: - Foodie Object Delegate Conformance

  override func retrieve(forceAnyways: Bool = false, withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    super.retrieve(forceAnyways: forceAnyways) { (someObject, error) in
      
      if let moment = someObject as? FoodieMoment {
        
        if moment.mediaObj == nil, let fileName = moment.mediaFileName,
          let typeString = moment.mediaType, let type = FoodieMediaType(rawValue: typeString) {
          moment.mediaObj = FoodieMedia(fileName: fileName, type: type)
        }
        
        if moment.thumbnailObj == nil, let fileName = moment.thumbnailFileName {
          moment.thumbnailObj = FoodieMedia(fileName: fileName, type: .photo)
        }
      }
      callback?(someObject, error)  // Callback regardless
    }
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     withName name: String? = nil,
                     withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    DebugPrint.verbose("FoodieMoment.saveRecursive to Location: \(location)")
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
    
    if let earlySuccess = earlyReturnStatus.success {
      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
      return
    }
    
    var childOperationPending = false
    
    // Need to make sure all children FoodieRecursives saved before proceeding
    if let media = mediaObj {
      foodieObject.saveChild(media, to: location, withName: name, withBlock: callback)
      childOperationPending = true
    }
    
    if let hasMarkups = markups {
      for markup in hasMarkups {
        foodieObject.saveChild(markup, to: location, withName: name, withBlock: callback)
        childOperationPending = true
      }
    }
    
    if let thumbnail = thumbnailObj {
      foodieObject.saveChild(thumbnail, to: location, withBlock: callback)
      childOperationPending = true
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
    
    DebugPrint.verbose("FoodieMoment.deleteRecursive from \(self.objectId) Location: \(location)")
    
    // retrieve moment first
    
    self.retrieve(withBlock: {(success, error) in
      
      
      switch location {
        
      case .local,
           .server:
        // delete from local only
        self.foodieObject.performDelete(from: location, withBlock: { (success, error) in
          callback?(success,error)
        })
      case .both:
        // delete from local first
        self.foodieObject.markPendingDelete()
        self.foodieObject.performDelete(from: .local, withBlock: { (success, error) in
          if(success) {
            self.foodieObject.performDelete(from: .server, withBlock: { (success, error) in
              
              // deleted journal form both local and server
              // check to see if there are moments to append
              var lastDeleteObj:FoodieObjectDelegate = self
              
              // iterate to the last delete object with nextDeleteObject = nil
              while(lastDeleteObj.getNextDeleteObject() != nil) {
                lastDeleteObj = lastDeleteObj.getNextDeleteObject()!
              }
              
              if let hasMedia = self.mediaObj {
                hasMedia.foodieObject.markPendingDelete()
                if(lastDeleteObj.getNextDeleteObject() == nil)
                {
                  lastDeleteObj.setNextDeleteObject(hasMedia)
                }
                lastDeleteObj = hasMedia
              }
              
              if let hasMomentThumb = self.thumbnailObj
              {
                hasMomentThumb.foodieObject.markPendingDelete()
                if(lastDeleteObj.getNextDeleteObject() == nil)
                {
                  lastDeleteObj.setNextDeleteObject(hasMomentThumb)
                }
                lastDeleteObj = hasMomentThumb
              }
              
              if(self.foodieObject.nextDeleteObject != nil) {
                self.foodieObject.nextDeleteObject?.deleteRecursive(from: location, withName: nil, withBlock: callback)
              }
              else {
                // no more stuff to delete call the call back
                callback?(success, error)
              }
            })
          }
        })
      }
    })
  }
  
  func getNextDeleteObject() -> FoodieObjectDelegate? {
    return foodieObject.getNextDeleteObject()
  }
  
  func setNextDeleteObject(_ deleteObj: FoodieObjectDelegate) {
    foodieObject.setNextDeleteObject(deleteObj)
  }

  
  func verbose() {
    DebugPrint.verbose("FoodieMoment ID: \(getUniqueIdentifier())")
    DebugPrint.verbose("  Media Filename: \(mediaFileName)")
    DebugPrint.verbose("  Media Type: \(mediaType)")
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
