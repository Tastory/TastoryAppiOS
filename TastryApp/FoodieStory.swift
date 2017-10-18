//
//  FoodieStory.swift
//  Tastry
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 Tastry. All rights reserved.
//


import Parse

class FoodieStory: FoodiePFObject, FoodieObjectDelegate {
  
  // MARK: - Parse PFObject keys
  // If new objects or external types are added here, check if save and delete algorithms needs updating
  @NSManaged var moments: Array<FoodieMoment>? // A FoodieMoment Photo or Video
  @NSManaged var pendingDeleteMomentList: Array<FoodieMoment>?
  @NSManaged var thumbnailFileName: String? // URL for the thumbnail media. Needs to go with the thumbnail object.
  @NSManaged var type: Int // Really enum for the thumbnail type. Allow videos in the future?
  @NSManaged var aspectRatio: Double
  @NSManaged var width: Int
  @NSManaged var markups: Array<FoodieMarkup>? // Array of PFObjects as FoodieMarkup for the thumbnail
  
  @NSManaged var title: String? // Title for the Story
  @NSManaged var venue: FoodieVenue? // Pointer to the Restaurant object
  @NSManaged var author: FoodieUser?  // Pointer? To the Authoring User
  @NSManaged var storyURL: String? // URL to the Story article
  @NSManaged var tags: Array<String>? // Array of Strings, unstructured

  @NSManaged var storyRating: Double // TODO: Placeholder for later rev
  @NSManaged var views: Int
  @NSManaged var clickthroughs: Int
  
  // Date created vs Date updated is given for free
  
  
  
  // MARK: - Types & Enums
  enum OperationType: String {
    case retrieveStory
    case saveStory
    case deleteStory
    case retrieveDigest
    case saveDigest
  }
  
  
  // Story Async Operation Child Class
  class StoryAsyncOperation: AsyncOperation {
    
    var operationType: OperationType
    var story: FoodieStory
    var location: FoodieObject.StorageLocation
    var localType: FoodieObject.LocalType
    var forceAnyways: Bool
    //var error: Error?
    var callback: ((Error?) -> Void)?
    
    init(on operationType: OperationType,
         for story: FoodieStory,
         to location: FoodieObject.StorageLocation,
         type localType: FoodieObject.LocalType,
         forceAnyways: Bool = false,
         withBlock callback: ((Error?) -> Void)?) {
      
      self.operationType = operationType
      self.story = story
      self.location = location
      self.localType = localType
      self.forceAnyways = forceAnyways
      self.callback = callback
      super.init()
    }
    
    override func main() {
      CCLog.debug ("Story Async \(operationType) Operation for \(story.getUniqueIdentifier()) Started")
      
      switch operationType {
      case .retrieveStory:
        story.retrieveOpRecursive(from: location, type: localType, forceAnyways: forceAnyways) { error in
          self.callback?(error)
          self.finished()
        }
        
      case .saveStory:
        story.saveOpRecursive(to: location, type: localType) { error in
          self.callback?(error)
          self.finished()
        }
        
      case .deleteStory:
        story.deleteOpRecursive(from: location, type: localType) { error in
          self.callback?(error)
          self.finished()
        }
        
      case .retrieveDigest:
        story.retrieveOpDigest(from: location, type: localType, forceAnyways: forceAnyways) { error in
          self.callback?(error)
          self.finished()
        }
      
      case .saveDigest:
        story.saveOpDigest(to: location, type: localType) { error in
          self.callback?(error)
          self.finished()
        }
      }
    }
  }
  
  
  
  // MARK: Error Types
  enum ErrorCode: LocalizedError {
    
    case retrieveDigestStoryNilThumbnail
    case retrieveDigestStoryNilVenue
    case retrieveDigestThumbnailNilImage
    case contentRetrieveMomentArrayNil
    case contentRetrieveObjectNilNotMoment
    
    var errorDescription: String? {
      switch self {
      case .retrieveDigestStoryNilThumbnail:
        return NSLocalizedString("retrieveDigest() Story retrieved with thumbnailFileName = nil", comment: "Error description for an exception error code")
      case .retrieveDigestStoryNilVenue:
        return NSLocalizedString("retrieveDigest() Story retrieved with venue = nil", comment: "Error description for an exception error code")
      case .retrieveDigestThumbnailNilImage:
        return NSLocalizedString("retrieveDigest() Thumbnail retrieved with imageMemoryBuffer = nil", comment: "Error description for an exception error code")
      case .contentRetrieveMomentArrayNil:
        return NSLocalizedString("story.contentRetrieve momentArray = nil unexpected", comment: "Error description for an exception error code")
      case .contentRetrieveObjectNilNotMoment:
        return NSLocalizedString("story.contentRetrieve moment.retrieveIfPending returned nil or non-FoodieMoment object", comment: "Error description for an exception error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  
  // MARK: - Public Constants
  struct Constants {
    static let MomentsToBufferAtATime = 2
  }
  
  
  
  // MARK: - Public Read-Only Static Variables
  fileprivate(set) static var currentStory: FoodieStory?
  
  
  
  // MARK: - Public Instance Variables
  var thumbnail: FoodieMedia?
  

  
  // MARK: - Private Instance Variables
  fileprivate var asyncOperationQueue = OperationQueue()
  private var digestReadyCallback: (() -> Void)?
  private var digestReadyMutex = SwiftMutex.create()
  
  
  // MARK: - Public Static Functions
  static func newCurrent() -> FoodieStory {
    if currentStory != nil {
      CCLog.assert("Attempted to create a new currentStory but currentStory != nil")
    }
    
    currentStory = FoodieStory()
    CCLog.debug("New Current Story created. Session FoodieObject ID = \(currentStory!.getUniqueIdentifier())")

    guard let current = currentStory else {
      CCLog.fatal("Just created a new FoodieStory but currentStory still nil")
    }
    return current
  }
  
  
  static func removeCurrent() {
    if currentStory == nil { CCLog.assert("CurrentStory is already nil") }
    CCLog.debug("Current Story Nil'd")
    currentStory = nil
  }
  
  
  static func setCurrentStory(to story: FoodieStory) {
    currentStory = story
    CCLog.debug("Current Story set. Session FoodieObject ID = \(story.getUniqueIdentifier())")
  }
  
  
  
  // MARK: - Private Instance Functions
  
  fileprivate func retrieve(from location: FoodieObject.StorageLocation,
                            type localType: FoodieObject.LocalType,
                            forceAnyways: Bool,
                            withBlock callback: SimpleErrorBlock?) {
    
    foodieObject.retrieveObject(from: location, type: localType, forceAnyways: forceAnyways) { error in
      
      if self.thumbnail == nil, let fileName = self.thumbnailFileName {
        self.thumbnail = FoodieMedia(for: fileName, localType: localType, mediaType: .photo)  // TODO: This will cause double thumbnail. Already a copy in the Moment
      }
      callback?(error)  // Callback regardless
    }
  }
  
  
  fileprivate func retrieveOpDigest(from location: FoodieObject.StorageLocation,
                                type localType: FoodieObject.LocalType,
                                forceAnyways: Bool = false,
                                withBlock callback: SimpleErrorBlock?) {
    
    // Retrieve self first, then retrieve children afterwards
    retrieve(from: location, type: localType, forceAnyways: forceAnyways) { error in
      
      if let error = error {
        CCLog.assert("Story.retrieve() resulted in error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      guard let thumbnail = self.thumbnail else {
        CCLog.assert("Story retrieved but thumbnail = nil")
        callback?(error)
        return
      }
      
      guard let venue = self.venue else {
        CCLog.assert("Story retrieved but venue = nil")
        callback?(error)
        return
      }
      
      self.foodieObject.resetChildOperationVariables()
      
      // Got through all sanity check, calling children's retrieveRecursive
      self.foodieObject.retrieveChild(thumbnail, from: location, type: localType, forceAnyways: forceAnyways, withReady: self.executeReady, withCompletion: callback)
      
      self.foodieObject.retrieveChild(venue, from: location, type: localType, forceAnyways: forceAnyways, withReady: self.executeReady, withCompletion: callback)
      
      if let markups = self.markups {
        for markup in markups {
          self.foodieObject.retrieveChild(markup, from: location, type: localType, forceAnyways: forceAnyways, withReady: self.executeReady, withCompletion: callback)
        }
      }
      
      // Do we need to retrieve User?
    }
  }
  
  
  fileprivate func saveOpDigest(to location: FoodieObject.StorageLocation,
                            type localType: FoodieObject.LocalType,
                            withBlock callback: SimpleErrorBlock?) {
    
    // We should always make sure we fill in the author for a Story
    guard let currentUser = FoodieUser.current else {
      CCLog.fatal("No Current User when trying to do saveOpRecursive on a Story")
    }
    author = currentUser
    
    self.foodieObject.resetChildOperationVariables()
    var childOperationPending = false
    
    // Need to make sure all children recursive saved before proceeding
    
    // We will assume that the Moment will get saved properly, avoiding a double save on the Thumbnail
    // We are not gonna save the User here either
    
    if let markups = markups {
      for markup in markups {
        foodieObject.saveChild(markup, to: location, type: localType, withBlock: callback)
        childOperationPending = true
      }
    }
    
    if let venue = venue {
      foodieObject.saveChild(venue, to: location, type: localType, withBlock: callback)
      childOperationPending = true
    }
    
    if !childOperationPending {
      self.foodieObject.savesCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
    }
  }
  
  
  fileprivate func retrieveOpRecursive(from location: FoodieObject.StorageLocation,
                                   type localType: FoodieObject.LocalType,
                                   forceAnyways: Bool = false,
                                   withBlock callback: SimpleErrorBlock?) {
    
    // Retrieve self first, then retrieve children afterwards
    retrieve(from: location, type: localType, forceAnyways: forceAnyways) { error in
      
      if let error = error {
        CCLog.assert("Story.retrieve() resulted in error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      guard let thumbnail = self.thumbnail else {
        CCLog.assert("Unexpected Story.retrieve() resulted in self.thumbnail = nil")
        callback?(error)
        return
      }
      
      self.foodieObject.resetChildOperationVariables()
      
      // Got through all sanity check, calling children's retrieveRecursive
      self.foodieObject.retrieveChild(thumbnail, from: location, type: localType, forceAnyways: forceAnyways, withCompletion: callback)
      
      if let moments = self.moments {
        for moment in moments {
          self.foodieObject.retrieveChild(moment, from: location, type: localType, forceAnyways: forceAnyways, withCompletion: callback)
        }
      }
      
      if let markups = self.markups {
        for markup in markups {
          self.foodieObject.retrieveChild(markup, from: location, type: localType, forceAnyways: forceAnyways, withCompletion: callback)
        }
      }
      
      // Do we need to retrieve User?
      
      if let venue = self.venue {
        self.foodieObject.retrieveChild(venue, from: location, type: localType, forceAnyways: forceAnyways, withCompletion: callback)
      }
    }
  }
  
  
  fileprivate func saveOpRecursive(to location: FoodieObject.StorageLocation,
                               type localType: FoodieObject.LocalType,
                               withBlock callback: SimpleErrorBlock?) {
    
    // We should always make sure we fill in the author for a Story
    guard let currentUser = FoodieUser.current else {
      CCLog.fatal("No Current User when trying to do saveOpRecursive on a Story")
    }
    author = currentUser
    
    self.foodieObject.resetChildOperationVariables()
    var childOperationPending = false
    
    // Need to make sure all children recursive saved before proceeding
    // We will assume that the Moment will get saved properly, avoiding a double save on the Thumbnail
    
    if let moments = moments {
      for moment in moments {
        foodieObject.saveChild(moment, to: location, type: localType, withBlock: callback)
        childOperationPending = true
      }
    }
    
    if let markups = markups {
      for markup in markups {
        foodieObject.saveChild(markup, to: location, type: localType, withBlock: callback)
        childOperationPending = true
      }
    }
    
    if let venue = venue {
      foodieObject.saveChild(venue, to: location, type: localType, withBlock: callback)
      childOperationPending = true
    }
    
    if !childOperationPending {
      self.foodieObject.savesCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
    }
  }
  
  
  fileprivate func deleteOpRecursive(from location: FoodieObject.StorageLocation,
                                     type localType: FoodieObject.LocalType,
                                     withBlock callback: SimpleErrorBlock?) {
    
    // Retrieve the Story (only) to guarentee access to the childrens
    retrieve(from: location, type: localType, forceAnyways: false) { error in
      
      if let error = error {
        CCLog.assert("Story.retrieve() resulted in error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      self.author = nil
      
      // Delete self first before deleting children
      self.foodieObject.deleteObject(from: location, type: localType) { error in
        
        if let error = error {
          CCLog.warning("Deleting self resulted in error: \(error.localizedDescription)")
          
          // Do best effort delete of all children
          if let moments = self.moments {
            for moment in moments {
              self.foodieObject.deleteChild(moment, from: location, type: localType, withBlock: nil)
            }
          }
          
          if let markups = self.markups {
            for markup in markups {
              self.foodieObject.deleteChild(markup, from: location, type: localType, withBlock: nil)
            }
          }
          
          if let venue = self.venue {
            self.foodieObject.deleteChild(venue, from: .local, type: localType, withBlock: nil)  // Don't ever delete venues from the server
          }
          
          // Don't delete Users nor Thumbnail!!!
          
          // Just callback with the error
          callback?(error)
          return
        }
        
        self.foodieObject.resetChildOperationVariables()
        var childOperationPending = false
        
        if let moments = self.moments {
          for moment in moments {
            self.foodieObject.deleteChild(moment, from: location, type: localType, withBlock: callback)
            childOperationPending = true
          }
        }
        
        if let markups = self.markups {
          for markup in markups {
            self.foodieObject.deleteChild(markup, from: location, type: localType, withBlock: callback)
            childOperationPending = true
          }
        }
        
        if let venue = self.venue {
          self.foodieObject.deleteChild(venue, from: .local, type: localType, withBlock: callback)  // Don't ever delete venues from the server
        }
        
        if !childOperationPending {
          CCLog.assert("No child deletes pending. Is this okay?")
          callback?(error)
        }
      }
    }
  }

  
  
  
  // MARK: - Public Instance Functions
  
  // This is the Initilizer Parse will call upon Query or Retrieves
  override init() {
    super.init()
    foodieObject.delegate = self
    asyncOperationQueue.maxConcurrentOperationCount = 1
  }
  
  
  // Function to add Moment to Story. If no position specified, add to end of array
  func add(moment: FoodieMoment,
           to position: Int? = nil) {
    
    if position != nil {
      CCLog.assert("FoodieStory.add(to position:) not yet implemented. Adding to 'end' position")
    }
    
    // Temporary Code?
    if self.moments != nil {
      self.moments!.append(moment)
    } else {
      self.moments = [moment]
    }
  }

  
  // Function to get index of specified Moment in Moment Array
  func getIndexOf(_ moment: FoodieMoment) -> Int {

    guard let momentArray = moments else {
      CCLog.fatal("story.getIndexOf() has moments = nil. Invalid")
    }
    
    var index = 0
    while index < momentArray.count {
      if momentArray[index] === moment {
        return index
      }
      index += 1
    }
    
    CCLog.assert("story.getIndexOf() cannot find Moment from Moment Array")
    return momentArray.count  // This is error case
  }
  
  
  // Might execute block both synchronously or asynchronously
  func executeForDigest(ifNotReady notReadyBlock: SimpleBlock?, whenReady readyBlock: @escaping SimpleBlock) {
    var isReady = false
    
    // What's going on here is we are preventing a race condition between
    // 1. The checking for retrieval here, which takes time. Can race with a potential completion process for a background retrieval
    // 2. The calling of the notReadyBlock to make sure it's going to be before the readyBlock potentially by a background retrieval completion
    
    digestReadyMutex.lock()
    isReady = isDigestRetrieved
    
    if !isReady {
      notReadyBlock?()
      digestReadyCallback = readyBlock
    } else {
      digestReadyCallback = nil
    }
    digestReadyMutex.unlock()
    
//    if isReady {
//      readyBlock()
//    }
  }
  
  
  func executeReady() {
    var blockToExecute: SimpleBlock?
    
    digestReadyMutex.lock()
    blockToExecute = digestReadyCallback
    digestReadyCallback = nil
    digestReadyMutex.unlock()
    
    blockToExecute?()
  }
  
  
  // MARK: - Foodie Digest Conceptual Sub-Object
  
  var isDigestRetrieved: Bool {
    guard super.isRetrieved else {
      return false  // Don't go further if even the parent isn't retrieved
    }
    
    guard let thumbnail = thumbnail, let venue = venue else {
      // If anything is nil, just re-retrieve? CCLog.assert("Thumbnail, Markups and Venue should all be not nil")
      return false
    }
    
    var markupsAreRetrieved = true
    if let markups = markups {
      for markup in markups {
        markupsAreRetrieved = markupsAreRetrieved && markup.isRetrieved
      }
    }
    
    return thumbnail.isRetrieved && venue.isRetrieved && markupsAreRetrieved
  }
  
  
  // Function to retrieve the Digest (Story minus the Moments)
  func retrieveDigest(from location: FoodieObject.StorageLocation,
                      type localType: FoodieObject.LocalType,
                      forceAnyways: Bool = false,
                      withBlock callback: SimpleErrorBlock?) {
    
    CCLog.verbose("Retrieve Digest of Story \(getUniqueIdentifier())")

    let retrieveDigestOperation = StoryAsyncOperation(on: .retrieveDigest, for: self, to: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
    asyncOperationQueue.addOperation(retrieveDigestOperation)
  }
  
  
  // Function to save the Digest (Story minus the Moments)
  func saveDigest(to location: FoodieObject.StorageLocation,
                  type localType: FoodieObject.LocalType,
                  withBlock callback: SimpleErrorBlock?) {
    
    CCLog.verbose("Save Digest of Story \(getUniqueIdentifier())")
    
    let saveDigestOperation = StoryAsyncOperation(on: .saveDigest, for: self, to: location, type: localType, withBlock: callback)
    asyncOperationQueue.addOperation(saveDigestOperation)
  }
  
  

  // MARK: - Foodie Object Delegate Conformance
  
  override var isRetrieved: Bool {
    guard isDigestRetrieved else {
      return false  // Don't go further if even the parent isn't retrieved
    }

    guard let moments = moments else {
      CCLog.assert("Moments should not be nil")
      return false
    }
    
    var momentsAreRetrieved = true
    for moment in moments {
      momentsAreRetrieved = momentsAreRetrieved && moment.isRetrieved
    }
    
    return momentsAreRetrieved
  }
  
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(from location: FoodieObject.StorageLocation,
                         type localType: FoodieObject.LocalType,
                         forceAnyways: Bool = false,
                         withReady readyBlock: SimpleBlock? = nil,
                         withCompletion callback: SimpleErrorBlock?) {
    
    guard readyBlock == nil else {
      CCLog.fatal("FoodieStory does not support Ready Responses")
    }
    
    CCLog.verbose("Retrieve Recursive for Story \(getUniqueIdentifier())")
    
    let retrieveOperation = StoryAsyncOperation(on: .retrieveStory, for: self, to: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
    asyncOperationQueue.addOperation(retrieveOperation)
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     withBlock callback: SimpleErrorBlock?) {
    
    CCLog.verbose("Save Recursive for Story \(getUniqueIdentifier())")
    
    let saveOperation = StoryAsyncOperation(on: .saveStory, for: self, to: location, type: localType, withBlock: callback)
    asyncOperationQueue.addOperation(saveOperation)
  }
 
  
  // Trigger recursive delete against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       withBlock callback: SimpleErrorBlock?) {
    
    CCLog.verbose("Delete Recursive for Story \(getUniqueIdentifier())")
    
    let deleteOperation = StoryAsyncOperation(on: .deleteStory, for: self, to: location, type: localType, withBlock: callback)
    asyncOperationQueue.addOperation(deleteOperation)
  }
  
  
  func cancelRetrieveFromServerRecursive() {
    
    CCLog.verbose("Cancel Retreive Recursive for Story \(getUniqueIdentifier())")
    
    digestReadyCallback = nil // Not too sure about this one...
    
    // Retrieve the Story (only) to guarentee access to the childrens
    retrieveFromLocalThenServer(forceAnyways: false, type: .cache) { error in
      if let error = error {
        CCLog.assert("Story.retrieve() resulted in error: \(error.localizedDescription)")
        return
      }
      
      guard let thumbnail = self.thumbnail else {
        CCLog.assert("Unexpected Story.retrieve() resulted in self.thumbnail = nil")
        return
      }

      thumbnail.cancelRetrieveFromServerRecursive()
      
      if let moments = self.moments {
        for moment in moments {
          moment.cancelRetrieveFromServerRecursive()
        }
      }
      
      if let markups = self.markups {
        for markup in markups {
          markup.cancelRetrieveFromServerRecursive()
        }
      }
      
      if let venue = self.venue {
        venue.cancelRetrieveFromServerRecursive()
      }
    }
  }
  
  
  func cancelSaveToServerRecursive() {
    
    CCLog.verbose("Cancel Save Recursive for Story \(getUniqueIdentifier())")
    
    if let moments = moments {
      for moment in moments {
        moment.cancelSaveToServerRecursive()
      }
    }
    
    if let markups = markups {
      for markup in markups {
        markup.cancelSaveToServerRecursive()
      }
    }
    
    if let venue = venue {
      venue.cancelSaveToServerRecursive()
    }
  }
  
  
  func foodieObjectType() -> String {
    return "FoodieStory"
  }
}


// MARK: - Parse Subclass Conformance
extension FoodieStory: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieStory"
  }
}

