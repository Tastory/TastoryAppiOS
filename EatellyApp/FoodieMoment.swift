//
//  FoodieMoment.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-03-31.
//  Copyright © 2017 Eatelly. All rights reserved.
//


import Parse

class FoodieMoment: FoodiePFObject, FoodieObjectDelegate {
  
  // MARK: - Parse PFObject keys
  // If new objects or external types are added here, check if save and delete algorithms needs updating
  @NSManaged var mediaFileName: String?  // File name for the media photo or video. Needs to go with the media object
  @NSManaged var mediaType: String?  // Really an enum saying whether it's a Photo or Video
  @NSManaged var aspectRatio: Double  // In decimal, width / height, like 16:9 = 16/9 = 1.777...
  @NSManaged var width: Int  // height = width / aspectRatio
  @NSManaged var thumbnailFileName: String?  // Thumbnail for the moment
  
  // Markups
  @NSManaged var markups: Array<FoodieMarkup>?  // Array of PFObjects as FoodieMarkup
  @NSManaged var eatags: Array<String>?  // Array of Strings, unstructured
  @NSManaged var tags: Array<String>?  // Array of Strings, unstructured
  
  // Location & Others
  @NSManaged var location: PFGeoPoint?  // Location where the media was originally captured
  @NSManaged var playSound: Bool
  
  // Query Pointers?
  @NSManaged var author: FoodieUser?  // Pointer to the user that authored this Moment
  @NSManaged var venue: FoodieVenue?  // Pointer to the FoodieVenue object
  @NSManaged var categories: Array<Int>?  // Array of internal restaurant categoryIDs (all cateogires that applies, sub or primary)
  
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
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Public Instance Variables
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
  
  
  // MARK: - Private Instance Variables
  fileprivate var hasRetrieved = false  // this flag indicate if this moment has been retrieved from Parse ?
  
  
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
  
  
  // Function to add Markups
  func add(markup: FoodieMarkup,
           to position: Int? = nil) {
    
    if position != nil {
      CCLog.assert("FoodieJournal.add(to position:) not yet implemented. Adding to 'end' position")
    }
    
    if self.markups != nil {
      self.markups!.append(markup)
    } else {
      self.markups = [markup]
    }
  }
  
  func set(location: CLLocation?) {
    if let location = location {
      self.location = PFGeoPoint(latitude: location.coordinate.latitude,
                                 longitude: location.coordinate.longitude)
    } else {
      self.location = nil
    }
  }
  
  
  // MARK: - Foodie Object Delegate Conformance

  // Retrieves just the moment itself
  override func retrieve(forceAnyways: Bool = false, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    super.retrieve(forceAnyways: forceAnyways) { error in
      if self.mediaObj == nil, let fileName = self.mediaFileName,
        let typeString = self.mediaType, let type = FoodieMediaType(rawValue: typeString) {
        self.mediaObj = FoodieMedia(withState: .notAvailable, fileName: fileName, type: type)
      }
      
      if self.thumbnailObj == nil, let fileName = self.thumbnailFileName {
        self.thumbnailObj = FoodieMedia(withState: .notAvailable, fileName: fileName, type: .photo)
      }
      callback?(error)  // Callback regardless
    }
  }

  static func queryFromPin(withName name: String, withBlock: (([AnyObject]?, Error?) -> Void)?) {
    let query = PFQuery(className: FoodieMoment.parseClassName())
    query.fromPin(withName: name)
      query.findObjectsInBackground() { (moments, error)in
        withBlock?(moments, error)
      }
  }

  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(forceAnyways: Bool = false, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Retrieve self first, then retrieve children afterwards
    retrieve(forceAnyways: forceAnyways) { (error) in
      
      if let momentError = error {
        CCLog.assert("Moment.retrieve() resulted in error: \(momentError.localizedDescription)")
        callback?(error)
        return
      }

      guard let media = self.mediaObj else {
        CCLog.assert("Unexpected Moment.retrieve() resulted in moment.mediaObj = nil")
        callback?(error)
        return
      }
      
      self.foodieObject.resetOutstandingChildOperations()
      
      // Got through all sanity check, calling children's retrieveRecursive
      self.foodieObject.retrieveChild(media, withBlock: callback)
      
      if let hasMarkups = self.markups {
        for markup in hasMarkups {
          self.foodieObject.retrieveChild(markup, withBlock: callback)
        }
      }
    }
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     withName name: String?,
                     withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
//    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
//    
//    if let earlySuccess = earlyReturnStatus.success {
//      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
//      return
//    }
    
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
      foodieObject.saveChild(thumbnail, to: location, withName: name, withBlock: callback)
      childOperationPending = true
    }
    
    if !childOperationPending {
      DispatchQueue.global(qos: .userInitiated).async { /*[unowned self] in */
        self.foodieObject.savesCompletedFromAllChildren(to: location, withName: name, withBlock: callback)
      }
    }
  }
  
  
  
  // Trigger recursive saves against all child objects.
  func deleteRecursive(withName name: String?,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    // retrieve moment first
    self.retrieve() { error in
      
      // TOOD: Victor, what happens if retrieve fails?
      
      // Delete self from both local and server first
      self.foodieObject.deleteObjectLocalNServer(withName: name) { (success, error) in
        
        if(success) {
          self.foodieObject.resetOutstandingChildOperations()
          
          // check for media and thumbnails to be deleted from this object
          if let media = self.mediaObj {
            self.foodieObject.deleteChild(media, withName: name, withBlock: callback)
          }
              
          if let thumbnail = self.thumbnailObj {
            self.foodieObject.deleteChild(thumbnail, withName: name, withBlock: callback)
          }
          
          if let markups = self.markups {
            for markup in markups {
              self.foodieObject.deleteChild(markup, withName: name, withBlock: callback)
            }
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
//    CCLog.verbose("FoodieMoment ID: \(getUniqueIdentifier())")
//    CCLog.verbose("  Media Filename: \(mediaFileName)")
//    CCLog.verbose("  Media Type: \(mediaType)")
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
