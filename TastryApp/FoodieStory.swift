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
    var error: Error?
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
  
  
  
  // MARK: Error Types Definition
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
  var thumbnailObj: FoodieMedia?
  var selfPrefetchContext: FoodiePrefetch.Context?
  var contentPrefetchContext: FoodiePrefetch.Context?

  
  // MARK: - Private Instance Variables
  fileprivate var asyncOperationQueue = OperationQueue()
  fileprivate var contentRetrievalMutex = SwiftMutex.create()
  fileprivate var contentRetrievalInProg = false
  fileprivate var contentRetrievalPending = false
  fileprivate var contentRetrievalPendingCallback: SimpleErrorBlock?
  
  
  
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
      
      if self.thumbnailObj == nil, let fileName = self.thumbnailFileName {
        self.thumbnailObj = FoodieMedia(for: fileName, localType: localType, mediaType: .photo)  // TODO: This will cause double thumbnail. Already a copy in the Moment
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
      
      guard let thumbnail = self.thumbnailObj else {
        CCLog.assert("Story retrieved but thumbnailObj = nil")
        callback?(error)
        return
      }
      
      guard let venue = self.venue else {
        CCLog.assert("Story retrieved but venue = nil")
        callback?(error)
        return
      }
      
      self.foodieObject.resetOutstandingChildOperations()
      
      // Got through all sanity check, calling children's retrieveRecursive
      self.foodieObject.retrieveChild(thumbnail, from: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
      
      self.foodieObject.retrieveChild(venue, from: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
      
      if let markups = self.markups {
        for markup in markups {
          self.foodieObject.retrieveChild(markup, from: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
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
    
    self.foodieObject.resetOutstandingChildOperations()
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
      
      guard let thumbnail = self.thumbnailObj else {
        CCLog.assert("Unexpected Story.retrieve() resulted in self.thumbnailObj = nil")
        callback?(error)
        return
      }
      
      self.foodieObject.resetOutstandingChildOperations()
      
      // Got through all sanity check, calling children's retrieveRecursive
      self.foodieObject.retrieveChild(thumbnail, from: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
      
      if let moments = self.moments {
        for moment in moments {
          self.foodieObject.retrieveChild(moment, from: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
        }
      }
      
      if let markups = self.markups {
        for markup in markups {
          self.foodieObject.retrieveChild(markup, from: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
        }
      }
      
      // Do we need to retrieve User?
      
      if let venue = self.venue {
        self.foodieObject.retrieveChild(venue, from: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
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
    
    self.foodieObject.resetOutstandingChildOperations()
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
        
        self.foodieObject.resetOutstandingChildOperations()
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
  
  
  // Function to move Moment to specified position in Moment array. Return failure if moving past end of array
  // Other Moments in the array might have their position altered accordingly
  // Controller layer should query to confirm how other Moments might have their orders and positions changed
  func move(moment: FoodieMoment,
            to position: Int) {
    
  }
  
  
  // Function to delete specified Moment
  // Other Moments in the array might have their position altered accordingly
  // Controller layer should query to confirm how other Moments might have their orders and positions changed
  func remove(moment: FoodieMoment) {
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
  
  
  
  // MARK: - Children Moments Retrieval Algorithms
  
  // Function to mark Moments and Media to retrieve, and then kick off the retrieval state machine
  func contentRetrievalRequest(fromMoment startNumber: Int, forUpTo numberOfMoments: Int, withBlock callback: SimpleErrorBlock? = nil) {
    
    guard let momentArray = moments else {
      CCLog.assert("contentRetrieveRequest for \(foodieObjectType())(\(getUniqueIdentifier())) has moments = nil.")
      callback?(ErrorCode.contentRetrieveMomentArrayNil)
      return
    }
    
    // Adjust number to retrieve based on how many Moments there are until the end
    var index = startNumber
    var numberToRetrieve = numberOfMoments
    
    if numberOfMoments == 0 {
      numberToRetrieve = momentArray.count
    }
    
    // Mark the Moment and Media to fetch as appropriate
    while index < momentArray.count, numberToRetrieve > 0 {
      
      let moment = momentArray[index]
      moment.foodieObject.markPendingRetrieval()
      
      numberToRetrieve -= 1
      index += 1
    }
    
    // Start the content retrieval state machine if it's not already started
    var executeStateMachine = false
    SwiftMutex.lock(&contentRetrievalMutex)  // TODO-Performance: Move to OperationQueue to eliminate chance of blocking main thread
    
    if contentRetrievalInProg {
      CCLog.verbose("Content Retrieval for \(foodieObjectType())(\(getUniqueIdentifier())) already in progress")
      contentRetrievalPending = true
      contentRetrievalPendingCallback = callback
    } else {
      CCLog.verbose("Content Retrieval for \(foodieObjectType())(\(getUniqueIdentifier())) begins")
      contentRetrievalInProg = true
      executeStateMachine = true
    }
    
    SwiftMutex.unlock(&contentRetrievalMutex)
    
    // Bringing function call out of critical section
    if executeStateMachine {
      contentRetrievalStateMachine(momentIndex: 0, withError: nil, withBlock: callback)
    }
  }
  
    
  // The brain of the content retrieval process
  func contentRetrievalStateMachine(momentIndex: Int, withError firstError: Error?, withBlock callback: SimpleErrorBlock? = nil) {
    
    guard let momentArray = moments else {
      CCLog.assert("contentRetrieveStateMachine for \(foodieObjectType())(\(getUniqueIdentifier())) has moments = nil")
      callback?(ErrorCode.contentRetrieveMomentArrayNil)
      return
    }
    
    var index = momentIndex
    
    // Look for the next moment that is marked for retrieval
    while index < momentArray.count {
      let moment = momentArray[index]
      
      // Retrieve the Moment first. One step at a time...
      if moment.foodieObject.retrieveIfPending(withBlock: { error in
        
        var currentError = firstError
        
        if let err = error {
          // TODO: How do we signal a background task error? Get whatever top of the presenting stack and push an error dialoge box on it?
          CCLog.warning("\(self.foodieObjectType())(\(self.getUniqueIdentifier)) retrieve content of Type \(moment.foodieObjectType())(\(moment.getUniqueIdentifier())) resulted in Error = \(err.localizedDescription)")
          if currentError == nil { currentError = err }
          self.contentRetrievalStateMachine(momentIndex: momentIndex+1, withError: currentError, withBlock: callback)
          return
        }

        self.contentRetrievalStateMachine(momentIndex: momentIndex+1, withError: currentError, withBlock: callback)
      }) { return }
      
      // See if the next moment needs retrieval if the previous one doesn't
      index += 1
    }
    
    // Do callback if there is one since we went through the entire momentArray
    if firstError == nil {
      callback?(nil)
    } else {
      callback?(firstError)
    }

    // If there was a pending retrieval operation, go for another round
    var executeStateMachine = false
    SwiftMutex.lock(&contentRetrievalMutex)  // TODO-Performance: Move to OperationQueue to eliminate chance of blocking main thread
    
    if contentRetrievalPending {
      CCLog.verbose("Content Retrieval for \(foodieObjectType())(\(getUniqueIdentifier())) was pending. Initiate another round of Content Retrieval")
      contentRetrievalPending = false
      executeStateMachine = true
    } else {
      CCLog.verbose("Content Retrieval for \(foodieObjectType())(\(getUniqueIdentifier())) completes!")
      contentRetrievalInProg = false
    }
    
    SwiftMutex.unlock(&contentRetrievalMutex)
    
    // Bringing function call out of critical section
    if executeStateMachine {
      contentRetrievalStateMachine(momentIndex: 0, withError: nil, withBlock: contentRetrievalPendingCallback)
    }
  }
  
  
  
  // MARK: - Foodie Digest Conceptual Sub-Object
  
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
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(from location: FoodieObject.StorageLocation,
                         type localType: FoodieObject.LocalType,
                         forceAnyways: Bool = false,
                         withBlock callback: SimpleErrorBlock?) {
    
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
    
    // Retrieve the Story (only) to guarentee access to the childrens
    retrieveFromLocalThenServer(forceAnyways: false, type: .cache) { error in
      if let error = error {
        CCLog.assert("Story.retrieve() resulted in error: \(error.localizedDescription)")
        return
      }
      
      guard let thumbnail = self.thumbnailObj else {
        CCLog.assert("Unexpected Story.retrieve() resulted in self.thumbnailObj = nil")
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


extension FoodieStory: FoodiePrefetchDelegate {
  
  func removePrefetchContexts() {
    selfPrefetchContext = nil
    contentPrefetchContext = nil
  }
  
  func doPrefetch(on objectToFetch: AnyObject, for context: FoodiePrefetch.Context, withBlock callback: FoodiePrefetch.PrefetchCompletionBlock? = nil) {
    if let story = objectToFetch as? FoodieStory {
      
      if story.thumbnailObj == nil {
        // No Thumbnail Object, so assume the Story itself needs to be retrieved
        CCLog.verbose("doPrefetch retrieveDigest for \(foodieObjectType())(\(getUniqueIdentifier()))")
        story.retrieveDigest(from: .both, type: .cache) { error in
          if let storyError = error {
            CCLog.assert("On prefetch, retrieveDigest for \(self.foodieObjectType())(\(self.getUniqueIdentifier())) callback with error: \(storyError.localizedDescription)")
          }
          callback?(context)
        }
        
      } else {
        story.contentRetrievalRequest(fromMoment: 0, forUpTo: Constants.MomentsToBufferAtATime) { error in
          if let storyError = error {
            CCLog.assert("On prefetch, contentRetrievalRequest for \(self.foodieObjectType())(\(self.getUniqueIdentifier())) callback with error: \(storyError.localizedDescription)")
          }
          callback?(context)
        }
      }
    }
  }
}
