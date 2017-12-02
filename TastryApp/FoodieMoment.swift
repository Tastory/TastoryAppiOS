//
//  FoodieMoment.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-03-31.
//  Copyright © 2017 Tastry. All rights reserved.
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
  
  
  
  // MARK: - Types & Enums
  enum OperationType: String {
    case retrieveMoment
    case retrieveMedia
    case saveMoment
    case deleteMoment
  }
  
  
  // Story Async Operation Child Class
  class MomentAsyncOperation: AsyncOperation {
    
    var operationType: OperationType
    var moment: FoodieMoment
    var location: FoodieObject.StorageLocation
    var localType: FoodieObject.LocalType
    var forceAnyways: Bool
    //var error: Error?
    var callback: ((Error?) -> Void)?
    
    init(on operationType: OperationType,
         for moment: FoodieMoment,
         to location: FoodieObject.StorageLocation,
         type localType: FoodieObject.LocalType,
         forceAnyways: Bool = false,
         withBlock callback: ((Error?) -> Void)?) {
      
      self.operationType = operationType
      self.moment = moment
      self.location = location
      self.localType = localType
      self.forceAnyways = forceAnyways
      self.callback = callback
      super.init()
    }
    
    override func main() {
      CCLog.debug ("Moment Async \(operationType) Operation for \(moment.getUniqueIdentifier()) Started")
      
      switch operationType {
      case .retrieveMoment:
        moment.retrieveOpRecursive(for: self, from: location, type: localType, forceAnyways: forceAnyways) { error in
          // Careful here. Make sure nothing in here can race against anything before this point. In case of a sync callback
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
        
      case .retrieveMedia:
        moment.retrieveOpMedia(for: self, from: location, type: localType, forceAnyways: forceAnyways) { error in
          // Careful here. Make sure nothing in here can race against anything before this point. In case of a sync callback
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
        
      case .saveMoment:
        moment.saveOpRecursive(for: self, to: location, type: localType) { error in
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
        
      case .deleteMoment:
        moment.deleteOpRecursive(for: self, from: location, type: localType) { error in
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
      }
    }
    
    override func cancel() {
      self.stateQueue.async {
        // Cancel regardless
        super.cancel()
        
        CCLog.debug("Cancel for Moment \(self.moment.getUniqueIdentifier()), Executing = \(self.isExecuting)")
        
        if self.isExecuting {
          SwiftMutex.lock(&self.moment.criticalMutex)
          
          // Cancel all child operations
          for operation in self.childOperations {
            operation.cancel()
          }
          
          switch self.operationType {
          case .retrieveMoment:
            self.moment.cancelRetrieveOpRecursive()
          case .retrieveMedia:
            self.moment.cancelRetrieveOpMedia()
          case .saveMoment:
            self.moment.cancelSaveOpRecursive()
          default:
            break
          }
          SwiftMutex.unlock(&self.moment.criticalMutex)
          
        } else if !self.isFinished {
          self.callback?(ErrorCode.operationCancelled)
          //self.finished()  // Calling isFinished when it's not executing causes problems
        }
      }
    }
  }

  
  
  // MARK: - Error Types
  enum ErrorCode: LocalizedError {
    
    case setMediaWithPhotoImageNil
    case setMediaWithPhotoJpegRepresentationFailed
    case operationCancelled
    
    var errorDescription: String? {
      switch self {
      case .setMediaWithPhotoImageNil:
        return NSLocalizedString("setMedia failed, photoImage = nil", comment: "Error description for an exception error code")
      case .setMediaWithPhotoJpegRepresentationFailed:
        return NSLocalizedString("setMedia failed, cannot create JPEG representation", comment: "Error description for an exception error code")
      case .operationCancelled:
        return NSLocalizedString("Moment Operation Cancelled", comment: "Error message for reason why an operation failed")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  
  // MARK: - Public Instance Variables

  var isEditMoment: Bool { return objectId != nil }
  var criticalMutex = SwiftMutex.create()
  
  var media: FoodieMedia? {
    didSet {
      mediaFileName = media!.foodieFileName
      mediaType = media!.mediaType?.rawValue
    }
  }
  
  var thumbnail: FoodieMedia? {
    didSet {
      thumbnailFileName = thumbnail!.foodieFileName
    }
  }
  
  
  
  // MARK: - Private Instance Variables
  
  private var asyncOperationQueue = OperationQueue()
  private var readyCallback: (() -> Void)?
  private var readyMutex = SwiftMutex.create()
  
  
  
  // MARK: - Public Static Functions
  
  static func batchRetrieve(_ moments: [FoodieMoment], completion: AnyErrorBlock?) {
    let query = PFQuery()
    query.whereKey("objectId", containedIn: moments.map({ $0.objectId! }))
    query.includeKey("markups")
    query.findObjectsInBackground(block: completion)
  }
  
  
  
  // MARK: - Private Instance Functions
  
  // Retrieves just the moment itself
  private func retrieve(from location: FoodieObject.StorageLocation,
                        type localType: FoodieObject.LocalType,
                        forceAnyways: Bool,
                        withBlock callback: SimpleErrorBlock?) {
    
    foodieObject.retrieveObject(from: location, type: localType, forceAnyways: forceAnyways) { error in
      
      if self.media == nil, let fileName = self.mediaFileName,
        let typeString = self.mediaType, let type = FoodieMediaType(rawValue: typeString) {
        self.media = FoodieMedia(for: fileName, localType: localType, mediaType: type)
      }
      
      if self.thumbnail == nil, let fileName = self.thumbnailFileName {
        self.thumbnail = FoodieMedia(for: fileName, localType: localType, mediaType: .photo)
      }
      callback?(error)  // Callback regardless
    }
  }
  
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  private func retrieveOpRecursive(for momentOperation: MomentAsyncOperation,
                                       from location: FoodieObject.StorageLocation,
                                       type localType: FoodieObject.LocalType,
                                       forceAnyways: Bool = false,
                                       withBlock callback: SimpleErrorBlock?) {
    
    // Retrieve self first, then retrieve children afterwards
    retrieve(from: location, type: localType, forceAnyways: forceAnyways) { error in
      
      if let error = error {
        CCLog.assert("Moment.retrieve() resulted in error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      guard let media = self.media else {
        CCLog.assert("Unexpected Moment.retrieve() resulted in moment.media = nil")
        callback?(error)
        return
      }
      
      guard let thumbnail = self.thumbnail else {
        CCLog.assert("Unexpected Moment.retrieve() resulted in moment.thumbnail = nil")
        callback?(error)
        return
      }
      
      // Calculate how many outstanding children operations there will be before hand
      // This helps avoiding the need of a lock
      var outstandingChildOperations = 2   // media & thumbnail to start
      
      if let markups = self.markups {
        outstandingChildOperations += markups.count
      }
      
      // Can we just use a mutex lock then?
      SwiftMutex.lock(&self.criticalMutex)
      defer { SwiftMutex.unlock(&self.criticalMutex) }
      
      guard !momentOperation.isCancelled else {
        CCLog.verbose("Moment \(self.getUniqueIdentifier()) operation \(momentOperation.getUniqueIdentifier()) early return due to cancel")
        callback?(ErrorCode.operationCancelled)
        return
      }
      
      self.foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
      self.foodieObject.retrieveChild(media, from: location, type: localType, forceAnyways: forceAnyways, for: momentOperation, withReady: self.executeReady, withCompletion: callback)
      self.foodieObject.retrieveChild(thumbnail, from: location, type: localType, forceAnyways: forceAnyways, for: momentOperation, withReady: self.executeReady, withCompletion: callback)
        
      if let markups = self.markups {
        for markup in markups {
          self.foodieObject.retrieveChild(markup, from: location, type: localType, forceAnyways: forceAnyways, for: momentOperation, withReady: self.executeReady, withCompletion: callback)
        }
      }
    }
  }
  
  
  private func retrieveOpMedia(for momentOperation: MomentAsyncOperation,
                               from location: FoodieObject.StorageLocation,
                               type localType: FoodieObject.LocalType,
                               forceAnyways: Bool = false,
                               withBlock callback: SimpleErrorBlock?) {
    
    // Retrieve self first, then retrieve children afterwards
    retrieve(from: location, type: localType, forceAnyways: forceAnyways) { error in
      
      if let error = error {
        CCLog.assert("Moment.retrieve() resulted in error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      guard let media = self.media else {
        CCLog.assert("Unexpected Moment.retrieve() resulted in moment.media = nil")
        callback?(error)
        return
      }
      
      // Calculate how many outstanding children operations there will be before hand
      // This helps avoiding the need of a lock
      var outstandingChildOperations = 1   // media to start
      
      if let markups = self.markups {
        outstandingChildOperations += markups.count
      }
      
      // Can we just use a mutex lock then?
      SwiftMutex.lock(&self.criticalMutex)
      defer { SwiftMutex.unlock(&self.criticalMutex) }
      
      guard !momentOperation.isCancelled else {
        CCLog.verbose("Moment \(self.getUniqueIdentifier()) operation \(momentOperation.getUniqueIdentifier()) early return due to cancel")
        callback?(ErrorCode.operationCancelled)
        return
      }
      
      self.foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
      self.foodieObject.retrieveChild(media, from: location, type: localType, forceAnyways: forceAnyways, for: momentOperation, withReady: self.executeReady, withCompletion: callback)
      
      if let markups = self.markups {
        FoodieMarkup.fetchAllIfNeeded(inBackground: markups) { (objects, error) in
          
          if let error = error {
            self.foodieObject.operationError = error
          } else {
            self.foodieObject.outstandingChildReadies -= markups.count
            if self.foodieObject.outstandingChildReadies == 0 { self.executeReady() }
          }
          
          self.foodieObject.outstandingChildOperations -= markups.count
          if self.foodieObject.outstandingChildOperations == 0 { callback?(self.foodieObject.operationError) }
          else if self.foodieObject.outstandingChildOperations < 0 {
            CCLog.assert("Outstanding Child Operations below 0")
          }
        }
      }
    }
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  private func saveOpRecursive(for momentOperation: MomentAsyncOperation,
                               to location: FoodieObject.StorageLocation,
                               type localType: FoodieObject.LocalType,
                               withBlock callback: SimpleErrorBlock?) {
    
    // Calculate how many outstanding children operations there will be before hand
    // This helps avoiding the need of a lock
    var outstandingChildOperations = 0
    
    if media != nil { outstandingChildOperations += 1 }
    if thumbnail != nil { outstandingChildOperations += 1 }
    
    if let markups = self.markups {
      outstandingChildOperations += markups.count
    }
    
    // Can we just use a mutex lock then?
    SwiftMutex.lock(&criticalMutex)
    defer { SwiftMutex.unlock(&criticalMutex) }
    
    guard !momentOperation.isCancelled else {
      CCLog.verbose("Moment \(self.getUniqueIdentifier()) operation \(momentOperation.getUniqueIdentifier()) early return due to cancel")
      callback?(ErrorCode.operationCancelled)
      return
    }
    
    // If there's no child op, then just save and return
    guard outstandingChildOperations != 0 else {
      CCLog.assert("No child saves pending. Then why is this even saved?")
      self.foodieObject.savesCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
      return
    }
    
    foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
    
    if let media = media {
      foodieObject.saveChild(media, to: location, type: localType, for: momentOperation, withBlock: callback)
    }
    
    if let thumbnail = thumbnail {
      foodieObject.saveChild(thumbnail, to: location, type: localType, for: momentOperation, withBlock: callback)
    }
    
    if let markups = markups {
      for markup in markups {
        foodieObject.saveChild(markup, to: location, type: localType, for: momentOperation, withBlock: callback)
      }
    }
  }
  
  
  // Trigger recursive saves against all child objects.
  private func deleteOpRecursive(for momentOperation: MomentAsyncOperation,
                                 from location: FoodieObject.StorageLocation,
                                 type localType: FoodieObject.LocalType,
                                 withBlock callback: SimpleErrorBlock?) {
    
    // Retrieve the Moment (only) to guarentee access to the childrens
    retrieve(from: location, type: localType, forceAnyways: false) { error in
      
      if let error = error {
        CCLog.assert("Moment.retrieve() resulted in error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      // Delete self first before deleting children
      self.foodieObject.deleteObject(from: location, type: localType) { error in
        
        if let error = error {
          CCLog.warning("Deleting self resulted in error: \(error.localizedDescription)")
          
          // Do best effort delete of all children
          if let media = self.media {
            self.foodieObject.deleteChild(media, from: location, type: localType, for: nil, withBlock: nil)
          }
          
          if let thumbnail = self.thumbnail {
            self.foodieObject.deleteChild(thumbnail, from: location, type: localType, for: nil, withBlock: nil)
          }
          
          if let markups = self.markups {
            for markup in markups {
              self.foodieObject.deleteChild(markup, from: location, type: localType, for: nil, withBlock: nil)
            }
          }
          
          // Just callback with the error
          callback?(error)
          return
        }
        
        // Calculate how many outstanding children operations there will be before hand
        // This helps avoiding the need of a lock
        var outstandingChildOperations = 0
        
        if self.media != nil { outstandingChildOperations += 1 }
        if self.thumbnail != nil { outstandingChildOperations += 1 }
        
        if let markups = self.markups {
          outstandingChildOperations += markups.count
        }
        
        // Can we just use a mutex lock then?
        SwiftMutex.lock(&self.criticalMutex)
        defer { SwiftMutex.unlock(&self.criticalMutex) }
        
        guard !momentOperation.isCancelled else {
          CCLog.verbose("Moment \(self.getUniqueIdentifier()) operation \(momentOperation.getUniqueIdentifier()) early return due to cancel")
          callback?(ErrorCode.operationCancelled)
          return
        }
          
        // If there's no child op, then just delete and return
        guard outstandingChildOperations != 0 else {
          CCLog.assert("No child deletes pending. Is this okay?")
          callback?(error)
          return
        }
        
        self.foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
        
        // check for media and thumbnails to be deleted from this object
        if let media = self.media {
          self.foodieObject.deleteChild(media, from: location, type: localType, for: momentOperation, withBlock: callback)
        }
          
        if let thumbnail = self.thumbnail {
          self.foodieObject.deleteChild(thumbnail, from: location, type: localType, for: momentOperation, withBlock: callback)
        }
          
        if let markups = self.markups {
          for markup in markups {
            self.foodieObject.deleteChild(markup, from: location, type: localType, for: momentOperation, withBlock: callback)
          }
        }
      }
    }
  }
  
    
  private func cancelRetrieveOpRecursive() {
    CCLog.verbose("Cancel Retrieve Recursive for Moment \(getUniqueIdentifier())")
    
    readyCallback = nil  // Not too sure about this one...
    
    retrieveFromLocalThenServer(forceAnyways: false, type: .cache) { error in
      if let error = error {
        CCLog.assert("Moment.retrieve() resulted in error: \(error.localizedDescription)")
        return
      }
      
      if let media = self.media {
        media.cancelRetrieveFromServerRecursive()
      }
      
      if let markups = self.markups {
        for markup in markups {
          markup.cancelRetrieveFromServerRecursive()
        }
      }
      
      if let thumbnail = self.thumbnail {
        thumbnail.cancelRetrieveFromServerRecursive()
      }
    }
  }
  
  
  private func cancelRetrieveOpMedia() {
    CCLog.verbose("Cancel Retrieve Recursive for Moment \(getUniqueIdentifier())")
    
    readyCallback = nil  // Not too sure about this one...
    
    retrieveFromLocalThenServer(forceAnyways: false, type: .cache) { error in
      if let error = error {
        CCLog.assert("Moment.retrieve() resulted in error: \(error.localizedDescription)")
        return
      }
      
      if let media = self.media {
        media.cancelRetrieveFromServerRecursive()
      }
      
      if let markups = self.markups {
        for markup in markups {
          markup.cancelRetrieveFromServerRecursive()
        }
      }
    }
  }
  
  
  private func cancelSaveOpRecursive() {
    CCLog.verbose("Cancel Save Recursive for Moment \(getUniqueIdentifier())")
    
    if let media = media {
      media.cancelSaveToServerRecursive()
    }
    
    if let markups = markups {
      for markup in markups {
        markup.cancelSaveToServerRecursive()
      }
    }
    
    if let thumbnail = thumbnail {
      thumbnail.cancelSaveToServerRecursive()
    }
  }

  
  
  // MARK: - Public Instance Functions
  
  // This is the Initilizer Parse will call upon Query or Retrieves
  override init() {
    super.init()
    foodieObject.delegate = self
    asyncOperationQueue.qualityOfService = .userInitiated
    asyncOperationQueue.maxConcurrentOperationCount = 1
    // media = FoodieMedia()  // retrieve() will take care of this. Don't set this here.
  }
  
  
  // This is the Initializer we will call internally
  convenience init(foodieMedia: FoodieMedia) {
    self.init()
    thumbnail = foodieMedia.generateThumbnail()
    thumbnailFileName = thumbnail!.foodieFileName
    
    // didSet does not get called in initialization context...
    media = foodieMedia
    mediaFileName = foodieMedia.foodieFileName
    mediaType = foodieMedia.mediaType?.rawValue

    if foodieMedia.width != nil {
      width = foodieMedia.width!
    }

    if(foodieMedia.aspectRatio != nil) {
      aspectRatio = foodieMedia.aspectRatio!
    }
  }
  
  
  // Function to add Markups
  func add(markup: FoodieMarkup,
           to position: Int? = nil) {
    
    if position != nil {
      CCLog.assert("FoodieStory.add(to position:) not yet implemented. Adding to 'end' position")
    }
    
    if self.markups != nil {
      self.markups!.append(markup)
    } else {
      self.markups = [markup]
    }
  }

  // Function to clear all Markups
  func clearMarkups()
  {
    if self.markups != nil {
      self.markups!.removeAll()
    } else {
      self.markups = []
    }
  }
  
  // Function to set Moment Locations
  func set(location: CLLocation?) {
    if let location = location {
      self.location = PFGeoPoint(latitude: location.coordinate.latitude,
                                 longitude: location.coordinate.longitude)
    } else {
      self.location = nil
    }
  }
  
  
  // Might execute block both synchronously or asynchronously
  func execute(ifNotReady notReadyBlock: SimpleBlock?, whenReady readyBlock: @escaping SimpleBlock) {
    var isReady = false
    
    // What's going on here is we are preventing a race condition between
    // 1. The checking for retrieval here, which takes time. Can race with a potential completion process for a background retrieval
    // 2. The calling of the notReadyBlock to make sure it's going to be before the readyBlock potentially by a background retrieval completion
    
    SwiftMutex.lock(&readyMutex)
    isReady = isMediaReady
    
    if !isReady {
      notReadyBlock?()
      readyCallback = readyBlock
    } else {
      readyCallback = nil
    }
    SwiftMutex.unlock(&readyMutex)
    
//    if isReady {
//      readyBlock()
//    }
  }

  
  func executeReady() {
    var blockToExecute: SimpleBlock?
    
    SwiftMutex.lock(&readyMutex)
    blockToExecute = readyCallback
    readyCallback = nil
    SwiftMutex.unlock(&readyMutex)
    
    blockToExecute?()
  }
  
  
  // MARK: - Foodie Object Delegate Conformance
  
  override var isRetrieved: Bool {
    guard super.isRetrieved else {
      return false  // Don't go further if even the parent isn't retrieved
    }
    
    guard let thumbnail = thumbnail, let media = media, let markups = markups else {
      // If anything is nil, just re-retrieve? CCLog.assert("Thumbnail, Markups and Venue should all be not nil")
      return false
    }
    
    var markupsAreRetrieved = true
    for markup in markups {
      markupsAreRetrieved = markupsAreRetrieved && markup.isRetrieved
    }
    
    return thumbnail.isRetrieved && media.isRetrieved && markupsAreRetrieved
  }
  
  
  var isMediaReady: Bool {
    guard super.isRetrieved else {
      return false  // Don't go further if even the parent isn't retrieved
    }
    
    guard let media = media, let markups = markups else {
      // If anything is nil, just re-retrieve? CCLog.assert("Thumbnail, Markups and Venue should all be not nil")
      return false
    }
    
    var markupsAreRetrieved = true
    for markup in markups {
      markupsAreRetrieved = markupsAreRetrieved && markup.isRetrieved
    }
    
    return media.isRetrieved && markupsAreRetrieved
  }
  
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(from location: FoodieObject.StorageLocation,
                         type localType: FoodieObject.LocalType,
                         forceAnyways: Bool = false,
                         for parentOperation: AsyncOperation? = nil,
                         withReady readyBlock: SimpleBlock? = nil,
                         withCompletion callback: SimpleErrorBlock?) {
    
    CCLog.verbose("Retrieve Recursive for Moment \(getUniqueIdentifier())")
    
    let retrieveOperation = MomentAsyncOperation(on: .retrieveMoment, for: self, to: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
    parentOperation?.add(retrieveOperation)  // Add to parent for cancel purposes
    asyncOperationQueue.addOperation(retrieveOperation)
  }
  
  
  func retrieveMedia(from location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     forceAnyways: Bool = false,
                     for parentOperation: AsyncOperation? = nil,
                     withReady readyBlock: SimpleBlock? = nil,
                     withCompletion callback: SimpleErrorBlock?) -> AsyncOperation {
    
    CCLog.verbose("Retrieve Media for Moment \(getUniqueIdentifier())")
    
    let retrieveOperation = MomentAsyncOperation(on: .retrieveMedia, for: self, to: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
    parentOperation?.add(retrieveOperation)
    asyncOperationQueue.addOperation(retrieveOperation)
    return retrieveOperation
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     for parentOperation: AsyncOperation? = nil,
                     withBlock callback: SimpleErrorBlock?)  {
    
    CCLog.verbose("Save Recursive for Moment \(getUniqueIdentifier())")
    
    let saveOperation = MomentAsyncOperation(on: .saveMoment, for: self, to: location, type: localType, withBlock: callback)
    parentOperation?.add(saveOperation)
    asyncOperationQueue.addOperation(saveOperation)
  }
  
  
  // Trigger recursive delete against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       for parentOperation: AsyncOperation? = nil,
                       withBlock callback: SimpleErrorBlock?) {
    
    CCLog.verbose("Delete Recursive for Moment \(getUniqueIdentifier())")
    
    let deleteOperation = MomentAsyncOperation(on: .deleteMoment, for: self, to: location, type: localType, withBlock: callback)
    parentOperation?.add(deleteOperation)
    asyncOperationQueue.addOperation(deleteOperation)
  }
  
  
  func cancelRetrieveFromServerRecursive() {
    CCLog.info("Cancel All Rerieval (All Operations!) for Moment \(getUniqueIdentifier())")
    asyncOperationQueue.cancelAllOperations()
  }
  
  
  func cancelSaveToServerRecursive() {
    CCLog.info("Cancel All Save (All Operations!) for Moment \(getUniqueIdentifier())")
    asyncOperationQueue.cancelAllOperations()
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
