//
//  FoodieMoment.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-31.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//


import Parse

protocol FoodieMomentWaitOnContentDelegate {
  func momentContentRetrieved(for moment: FoodieMoment)
}


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
  
  var waitOnContentDelegate: FoodieMomentWaitOnContentDelegate?
  
  
  // MARK: - Private Instance Variable
  fileprivate var contentsRetrieved: Bool = false
  fileprivate var contentRetrievedMutex = pthread_mutex_t()
  
  
  // MARK: - Public Instance Functions
  
  // This is the Initilizer Parse will call upon Query or Retrieves
  override init() {
    super.init(withState: .notAvailable)
    foodieObject.delegate = self
    // mediaObj = FoodieMedia()  // retrieve() will take care of this. Don't set this here.
  }
  
  
  // This is the Initializer we will call internally
  init(withState operationState: FoodieObject.OperationStates, foodieMedia: FoodieMedia) {
    super.init(withState: operationState)
    foodieObject.delegate = self
    mediaObj = foodieMedia
    
    // didSet does not get called in initialization context...
    mediaFileName = foodieMedia.foodieFileName
    mediaType = foodieMedia.mediaType?.rawValue
  }
  
  
  // Funciton to set Content Retreived to True. Exectute delegate function if a delegate object is registered
  func setContentsRetrieved() {
    DebugPrint.verbose("contentsRetrieved set to true from \(contentsRetrieved)")
    
    pthread_mutex_lock(&contentRetrievedMutex)
    if contentsRetrieved == false {
      contentsRetrieved = true
      waitOnContentDelegate?.momentContentRetrieved(for: self)
    }
    pthread_mutex_unlock(&contentRetrievedMutex)
  }
  
  
  // Funciton to check if Content Retrieved is set to True. Register delegate object if False
  func checkContentRetrieved(ifFalseSetDelegate delegate: FoodieMomentWaitOnContentDelegate) -> Bool {
    
    pthread_mutex_lock(&contentRetrievedMutex)
    if contentsRetrieved == false {
      waitOnContentDelegate = delegate
    }
    pthread_mutex_unlock(&contentRetrievedMutex)
    return contentsRetrieved

  }
  
  
  // MARK: - Foodie Object Delegate Conformance

  // Retrieves just the moment itself
  override func retrieve(forceAnyways: Bool = false, withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    super.retrieve(forceAnyways: forceAnyways) { (object, error) in
      
      if let moment = object as? FoodieMoment {
        
        if moment.mediaObj == nil, let fileName = moment.mediaFileName,
          let typeString = moment.mediaType, let type = FoodieMediaType(rawValue: typeString) {
          moment.mediaObj = FoodieMedia(withState: .notAvailable, fileName: fileName, type: type)
        }
        
        if moment.thumbnailObj == nil, let fileName = moment.thumbnailFileName {
          moment.thumbnailObj = FoodieMedia(withState: .notAvailable, fileName: fileName, type: .photo)
        }
      }
      callback?(object, error)  // Callback regardless
    }
  }
  
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(forceAnyways: Bool = false, withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    
    // Retrieve self first, then retrieve children afterwards
    retrieve(forceAnyways: forceAnyways) { (object, error) in
      
      if let momentError = error {
        DebugPrint.assert("Moment.retrieve() resulted in error: \(momentError.localizedDescription)")
        callback?(object, error)
        return
      }
      
      guard let moment = object as? FoodieMoment else {
        DebugPrint.assert("Unexpected Moment.retrieve() resulted in object = nil")
        callback?(object, error)
        return
      }
      
      guard let media = moment.mediaObj else {
        DebugPrint.assert("Unexpected Moment.retrieve() resulted in moment.mediaObj = nil")
        callback?(object, error)
        return
      }
      
      moment.foodieObject.resetOutstandingChildOperations()
      
      // Got through all sanity check, calling children's retrieveRecursive
      moment.foodieObject.retrieveChild(media, withBlock: callback)
      
      if let hasMarkups = moment.markups {
        for markup in hasMarkups {
          moment.foodieObject.retrieveChild(markup, withBlock: callback)
        }
      }
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
    
    foodieObject.resetOutstandingChildOperations()
    
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
      DispatchQueue.global(qos: .userInitiated).async { /*[unowned self] in */
        self.foodieObject.savesCompletedFromAllChildren(to: location, withBlock: callback)
      }
    }
  }
  
  
  
  // Trigger recursive saves against all child objects.
  func deleteRecursive(withName name: String? = nil,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
    DebugPrint.verbose("FoodieMoment.deleteRecursive from \(self.objectId)")
    
    // retrieve moment first
    self.retrieve() { (success, error) in
      
      // TOOD: Victor, what happens if retrieve fails?
      
      // delete from local first
      self.foodieObject.deleteObjectLocalNServer(withName: name) { (success, error) in
        
        if(success) {
          // check for media and thumb nails to be deleted from this object
          if let hasMedia = self.mediaObj {
            self.foodieObject.deleteChild(hasMedia, withBlock: callback)
          }
              
          if let hasMomentThumb = self.thumbnailObj {
            self.foodieObject.deleteChild(hasMomentThumb, withBlock: callback)
          }
          
          // TODO: Victor, what happens if there is neither Moments nor Markup in this Journal? I know it's hypothetical.
          // But it will mean the whole recursive operation hangs because there will never be a callback
          
        } else {
          // error when deleting journal from server
          callback?(success, error)
        }
      }
    }
  }
  
  
  func verbose() {
//    DebugPrint.verbose("FoodieMoment ID: \(getUniqueIdentifier())")
//    DebugPrint.verbose("  Media Filename: \(mediaFileName)")
//    DebugPrint.verbose("  Media Type: \(mediaType)")
  }
  
  
  func foodieObjectType() -> String {
    return "FoodieMoment"
  }
}

 
extension FoodieMoment: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieMomentDemo"
  }
}
