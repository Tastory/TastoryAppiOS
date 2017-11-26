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
  
  @NSManaged var title: String? // Title for the Story
  @NSManaged var venue: FoodieVenue? // Pointer to the Restaurant object
  @NSManaged var author: FoodieUser?  // Pointer? To the Authoring User
  @NSManaged var storyURL: String? // URL to the Story article
  @NSManaged var swipeMessage: String? // Custom message underneath the swipe arrow indicator
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
        story.retrieveOpRecursive(for: self, from: location, type: localType, forceAnyways: forceAnyways) { error in
          // Careful here. Make sure nothing in here can race against anything before this point. In case of a sync callback
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
        
      case .saveStory:
        story.saveOpRecursive(for: self, to: location, type: localType) { error in
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
        
      case .deleteStory:
        story.deleteOpRecursive(for: self, from: location, type: localType) { error in
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
        
      case .retrieveDigest:
        story.retrieveOpDigest(for: self, from: location, type: localType, forceAnyways: forceAnyways) { error in
          self.childOperations.removeAll()
          self.callback?(error)
          self.finished()
        }
      
      case .saveDigest:
        story.saveOpDigest(for: self, to: location, type: localType) { error in
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

        CCLog.debug("Cancel for Story \(self.story.getUniqueIdentifier()), Executing = \(self.isExecuting)")
        
        if self.isExecuting {
          
          SwiftMutex.lock(&self.story.criticalMutex)
        
          // Cancel all child operations
          for operation in self.childOperations {
            operation.cancel()
          }
          
          switch self.operationType {
          case .retrieveDigest, .retrieveStory:
            self.story.cancelRetrieveOpRecursive()
          case .saveDigest, .saveStory:
            self.story.cancelSaveOpRecursive()
          default:
            break
          }

          SwiftMutex.unlock(&self.story.criticalMutex)
        
        } else if !self.isFinished {
          self.callback?(ErrorCode.operationCancelled)
          //self.finished()  // Calling isFinished when it's not executing causes problems
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
    case operationCancelled
    
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
      case .operationCancelled:
        return NSLocalizedString("Story Operation Cancelled", comment: "Error message for reason why an operation failed")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  
  // MARK: - Public Read-Only Static Variables
  private(set) static var currentStory: FoodieStory?
  
  
  
  // MARK: - Public Instance Variables
  var isEditStory: Bool { return objectId != nil }
  var thumbnail: FoodieMedia?
  var criticalMutex = SwiftMutex.create()
  
  
  
  // MARK: - Private Instance Variables
  private var asyncOperationQueue = OperationQueue()
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
  
  private func retrieve(from location: FoodieObject.StorageLocation,
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
  
  
  private func retrieveOpDigest(for storyOperation: StoryAsyncOperation,
                                from location: FoodieObject.StorageLocation,
                                type localType: FoodieObject.LocalType,
                                forceAnyways: Bool = false,
                                withBlock callback: SimpleErrorBlock?){
    
    // Retrieve self first, then retrieve children afterwards
    retrieve(from: location, type: localType, forceAnyways: forceAnyways) { error in
      
      if let error = error {
        CCLog.assert("Story.retrieve() resulted in error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      guard let venue = self.venue else {
        CCLog.fatal("Story retrieved but venue = nil")
      }
      
      guard let author = self.author else {
        CCLog.fatal("Story retrieved but author = nil")
      }
      
      // Not retrieving Thumbnail for Digest
      
      // Calculate how many outstanding children operations there will be before hand
      // This helps avoiding the need of a lock
      var outstandingChildOperations = 1   // The venue for sure, so start with 1
      
      if localType != .draft { outstandingChildOperations += 1 }
      
      // Can we just use a mutex lock then?
      SwiftMutex.lock(&self.criticalMutex)
      defer { SwiftMutex.unlock(&self.criticalMutex) }
      
      guard !storyOperation.isCancelled else {
        callback?(ErrorCode.operationCancelled)
        return
      }
      
      self.foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
      
      // There will be no Markups for Story Covers
      
      self.foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
      self.foodieObject.retrieveChild(venue, from: location, type: localType, forceAnyways: forceAnyways, for: storyOperation, withReady: self.executeReady, withCompletion: callback)

      if localType != .draft {
        self.foodieObject.retrieveChild(author, from: location, type: localType, forceAnyways: forceAnyways, for: storyOperation, withReady: self.executeReady, withCompletion: callback)
      }
    }
  }
  
  
  private func saveOpDigest(for storyOperation: StoryAsyncOperation,
                            to location: FoodieObject.StorageLocation,
                            type localType: FoodieObject.LocalType,
                            withBlock callback: SimpleErrorBlock?) {
    
    // We should always make sure we fill in the author for a Story
    guard let currentUser = FoodieUser.current else {
      CCLog.fatal("No Current User when trying to do saveOpRecursive on a Story")
    }
    author = currentUser
    
    // Calculate how many outstanding children operations there will be before hand
    // This helps avoiding the need of a lock
    var outstandingChildOperations = 0
    
    if venue != nil { outstandingChildOperations += 1 }
    if localType != .draft { outstandingChildOperations += 1 }
    
    // Can we just use a mutex lock then?
    SwiftMutex.lock(&criticalMutex)
    defer { SwiftMutex.unlock(&criticalMutex) }
    
    guard !storyOperation.isCancelled else {
      callback?(ErrorCode.operationCancelled)
      return
    }
    
    // If there's no child op, then just save and return
    guard outstandingChildOperations != 0 else {
      self.foodieObject.savesCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
      return
    }
    
    foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
    
    // We will assume that the Moment will get saved properly, avoiding a double save on the Thumbnail
    // We are not gonna save the User here either
    
    // There will be no Markups for Story Covers
      
    if let venue = self.venue {
      foodieObject.saveChild(venue, to: location, type: localType, for: storyOperation, withBlock: callback)
    }
    
    if localType != .draft {
      foodieObject.saveChild(author!, to: location, type: localType, for: storyOperation, withBlock: callback)
    }
  }
  
  
  private func retrieveOpRecursive(for storyOperation: StoryAsyncOperation,
                                   from location: FoodieObject.StorageLocation,
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
      
      guard let author = self.author else {
        CCLog.fatal("Story retrieved but author = nil")
      }
      
      // Do we really need the Thumbnail at all?
      guard let thumbnail = self.thumbnail else {
        CCLog.fatal("Unexpected Story.retrieve() resulted in self.thumbnail = nil")
      }
      
      // Calculate how many outstanding children operations there will be before hand
      // This helps avoiding the need of a lock
      var outstandingChildOperations = 1   // just thumbnail to start
      if self.venue != nil { outstandingChildOperations += 1 }
      if localType != .draft { outstandingChildOperations += 1 }
      
      if let moments = self.moments {
        outstandingChildOperations += moments.count
      }
      
      // Can we just use a mutex lock then?
      SwiftMutex.lock(&self.criticalMutex)
      defer { SwiftMutex.unlock(&self.criticalMutex) }
      
      guard !storyOperation.isCancelled else {
        callback?(ErrorCode.operationCancelled)
        return
      }
      
      // There will be no Markups for Story Covers
      
      self.foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
      
      if let venue = self.venue {
        self.foodieObject.retrieveChild(venue, from: location, type: localType, forceAnyways: forceAnyways, for: storyOperation, withCompletion: callback)
      }
      
      self.foodieObject.retrieveChild(thumbnail, from: location, type: localType, forceAnyways: forceAnyways, for: storyOperation, withCompletion: callback)
        
      if let moments = self.moments {
        for moment in moments {
          self.foodieObject.retrieveChild(moment, from: location, type: localType, forceAnyways: forceAnyways, for: storyOperation, withCompletion: callback)
        }
      }
 
      if localType != .draft {
        self.foodieObject.retrieveChild(author, from: location, type: localType, forceAnyways: forceAnyways, for: storyOperation, withCompletion: callback)
      }
    }
  }
  
  
  private func saveOpRecursive(for storyOperation: StoryAsyncOperation,
                               to location: FoodieObject.StorageLocation,
                               type localType: FoodieObject.LocalType,
                               withBlock callback: SimpleErrorBlock?) {
    
    // We should always make sure we fill in the author for a Story
    guard let currentUser = FoodieUser.current else {
      CCLog.fatal("No Current User when trying to do saveOpRecursive on a Story")
    }
    author = currentUser
    
    // Calculate how many outstanding children operations there will be before hand
    // This helps avoiding the need of a lock
    var outstandingChildOperations = 0
    
    if venue != nil { outstandingChildOperations += 1 }
    if localType != .draft { outstandingChildOperations += 1 }
    
    if let moments = self.moments {
      outstandingChildOperations += moments.count
    }
    
    // Can we just use a mutex lock then?
    SwiftMutex.lock(&criticalMutex)
    defer { SwiftMutex.unlock(&criticalMutex) }
    
    guard !storyOperation.isCancelled else {
      callback?(ErrorCode.operationCancelled)
      return
    }
    
    // If there's no child op, then just save and return
    guard outstandingChildOperations != 0 else {
      self.foodieObject.savesCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
      return
    }
    
    foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
    
    // We will assume that the Moment will get saved properly, avoiding a double save on the Thumbnail
    // We are not gonna save the User here either
    
    // There will be no Markups for Story Covers
    
    if let venue = self.venue {
      foodieObject.saveChild(venue, to: location, type: localType, for: storyOperation, withBlock: callback)
    }
    
    if localType != .draft {
      foodieObject.saveChild(author!, to: location, type: localType, for: storyOperation, withBlock: callback)
    }
    
    if let moments = self.moments {
      for moment in moments {
        foodieObject.saveChild(moment, to: location, type: localType, for: storyOperation, withBlock: callback)
      }
    }
  }
  
  
  private func deleteOpRecursive(for storyOperation: StoryAsyncOperation,
                                 from location: FoodieObject.StorageLocation,
                                 type localType: FoodieObject.LocalType,
                                 withBlock callback: SimpleErrorBlock?) {
    
    // Retrieve the Story (only) to guarentee access to the childrens
    retrieve(from: location, type: localType, forceAnyways: false) { error in
      
      if let error = error {
        CCLog.assert("Story.retrieve() resulted in error: \(error.localizedDescription)")
        callback?(error)
        return
      }

      // Calculate how many outstanding children operations there will be before hand
      // This helps avoiding the need of a lock
      var outstandingChildOperations = 0
      
      if self.venue != nil { outstandingChildOperations += 1 }
      if let author = self.author, author != FoodieUser.current, localType == .cache {
        outstandingChildOperations += 1
      }
      
      if let moments = self.moments {
        outstandingChildOperations += moments.count
      }
      
      // Can we just use a mutex lock then?
      SwiftMutex.lock(&self.criticalMutex)
      defer { SwiftMutex.unlock(&self.criticalMutex) }
      
      guard !storyOperation.isCancelled else {
        callback?(ErrorCode.operationCancelled)
        return
      }
      
      // If there's no child op, then just delete and return
      guard outstandingChildOperations != 0 else {
        self.foodieObject.deleteCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
        return
      }
      
      self.foodieObject.resetChildOperationVariables(to: outstandingChildOperations)
      
      // There will be no Markups for Story Covers
      
      // Never delete a venue from server
      if let venue = self.venue {
         self.foodieObject.deleteChild(venue, from: .local, type: localType, for: storyOperation, withBlock: callback)
      }
      
      // Delete user only if from Cache and it's not the current user
      if let author = self.author, author != FoodieUser.current, localType == .cache {
        self.foodieObject.deleteChild(author, from: .local, type: localType, for: storyOperation, withBlock: callback)
      }
      
      if let moments = self.moments {
        for moment in moments {
          self.foodieObject.deleteChild(moment, from: location, type: localType, for: storyOperation, withBlock: callback)
        }
      }
    }
  }

  
  private func cancelRetrieveOpRecursive() {
    
    CCLog.verbose("Cancel Retrieve Recursive for Story \(getUniqueIdentifier())")
    
    digestReadyCallback = nil // Not too sure about this one...
    
    // ??? Retrieve the Story (only) to guarentee access to the childrens
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
      
      // Author and Moments are all operation based. Gets cancelled in MomentAsyncOperation.cancel()
      //      if let author = self.author {
      //        author.cancelRetrieveFromServerRecursive()
      //      }
      //
      //      if let moments = self.moments {
      //        for moment in moments {
      //          moment.cancelRetrieveFromServerRecursive()
      //        }
      //      }
      
      // There will be no Markups for Story Covers
      
      if let venue = self.venue {
        venue.cancelRetrieveFromServerRecursive()
      }
    }
  }
  
  
  private func cancelSaveOpRecursive() {
    
    CCLog.verbose("Cancel Save Recursive for Story \(getUniqueIdentifier())")
    
    // Author and Moments are all operation based. Gets cancelled in MomentAsyncOperation.cancel()
    //    if let author = self.author {
    //      author.cancelSaveToServerRecursive()
    //    }
    //
    //    if let moments = moments {
    //      for moment in moments {
    //        moment.cancelSaveToServerRecursive()
    //      }
    //    }
    
    // There will be no Markups for Story Covers
    
    if let venue = venue {
      venue.cancelSaveToServerRecursive()
    }
  }
  
  
  // MARK: - Public Instance Functions
  
  // This is the Initilizer Parse will call upon Query or Retrieves
  override init() {
    super.init()
    foodieObject.delegate = self
    asyncOperationQueue.qualityOfService = .userInitiated
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

      if(self.moments!.contains(moment)) {
        CCLog.assert("Failed to add a moment as it already exists within this story")
      } else {
        self.moments!.append(moment)
      }
    } else {
      self.moments = [moment]
    }
  }

  static func cleanUpDraft(withBlock callback: @escaping SimpleErrorBlock) {
    guard let story = currentStory else {
      CCLog.fatal("Discard current Story but no current Story")
    }

    if let moments = story.moments {
      for moment in moments {
        moment.cancelRetrieveFromServerRecursive()
      }
    }

    removeCurrent()
    // Delete all traces of this unPosted Story
    story.deleteRecursive(from: .local, type: .draft) { error in
      if let error = error {
        CCLog.warning("Deleting Story resulted in Error - \(error.localizedDescription)")
        callback(error)
      }

      if(!story.isEditStory) {
        // this draft is a newly created story and need to remove presaved moments 
        _ = story.deleteRecursive(from: .both, type: .draft) { error in
          if let error = error {
            CCLog.warning("Deleting Story resulted in Error - \(error.localizedDescription)")
            callback(error)
          }
        }
      } else {
        // story was reverted and the thumbnail needs to be restored
        if let moments = story.moments {
          for moment in moments {
            if(moment.thumbnailFileName == story.thumbnailFileName) {
              story.thumbnail = moment.thumbnail
            }

            // clean up video player
            if(moment.media != nil) {
              moment.media!.videoExportPlayer?.cancelExport()
              moment.media!.videoExportPlayer = nil
            }
          }
        }
      }
      callback(nil)
    }
  }

  static func preSave(_ object: FoodieObjectDelegate?, withBlock callback: SimpleErrorBlock?) {

    CCLog.debug("Pre-Save Operation Started")

    guard let story = currentStory else {
      CCLog.fatal("No Working Story on Pre Save")
    }

    // Save Journal only if no object supplied
    guard let object = object else {
      CCLog.debug("No Foodie Object supplied on preSave(), skipping Object Server save")
      
      // Save Story to Local
      story.saveDigest(to: .local, type: .draft, for: nil) { error in
        
        if let error = error {
          CCLog.warning("Story pre-save to Local resulted in error - \(error.localizedDescription)")
          callback?(error)
          return
        }
        
        CCLog.debug("Completed pre-saving Story to Local")
        callback?(nil)
      }
      return
    }
    
    // TODO: - !!!!! If the user quit the app after Markups are pre-saved to draft, but Moment is not yet pinned, then the entire Draft gets trashed
    // Solution is probably to compartmentalize such that a single corrupted Moment won't scrap the entire Draft
    object.saveRecursive(to: .local, type: .draft, for: nil) { error in
      
      if let error = error {
        CCLog.warning("\(object.foodieObjectType()) pre-save to local resulted in error - \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      CCLog.debug("Completed Pre-Saving \(object.foodieObjectType()) to Local")
      
      // Save Story to Local
      story.saveDigest(to: .local, type: .draft, for: nil) { error in

        if let error = error {
          CCLog.warning("Story pre-save to Local resulted in error - \(error.localizedDescription)")
          callback?(error)
          return
        }
        CCLog.debug("Completed pre-saving Story to Local")

        // Finally save the Moment to Server
        object.saveRecursive(to: .both, type: .draft, for: nil) { error in

          if let error = error {
            CCLog.warning("\(object.foodieObjectType()) pre-save to local & server resulted in error - \(error.localizedDescription)")
            callback?(error)
            return
          }

          CCLog.debug("Completed Pre-Saving \(object.foodieObjectType()) to Local & Server")
          callback?(nil)
        }
      }
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
    
    SwiftMutex.lock(&digestReadyMutex)
    isReady = isDigestRetrieved
    
    if !isReady {
      notReadyBlock?()
      digestReadyCallback = readyBlock
    } else {
      digestReadyCallback = nil
    }
    SwiftMutex.unlock(&digestReadyMutex)
    
//    if isReady {
//      readyBlock()
//    }
  }
  
  
  func executeReady() {
    var blockToExecute: SimpleBlock?
    
    SwiftMutex.lock(&digestReadyMutex)
    blockToExecute = digestReadyCallback
    digestReadyCallback = nil
    SwiftMutex.unlock(&digestReadyMutex)
    
    blockToExecute?()
  }
  
  
  // MARK: - Foodie Digest Conceptual Sub-Object
  
  var isDigestRetrieved: Bool {
    guard super.isRetrieved else {
      return false  // Don't go further if even the parent isn't retrieved
    }
    
    guard let venue = venue, let author = author else {  // We don't need to retrieve Thumbnail anymore. ASDK will take care of that!
      // If anything is nil, just re-retrieve? CCLog.assert("Thumbnail, Markups and Venue should all be not nil")
      return false
    }
    
    // There will be no Markups for Story Covers
    
    return venue.isRetrieved && author.isRetrieved
  }
  
  
  // Function to retrieve the Digest (Story minus the Moments)
  func retrieveDigest(from location: FoodieObject.StorageLocation,
                      type localType: FoodieObject.LocalType,
                      forceAnyways: Bool = false,
                      for parentOperation: AsyncOperation? = nil,
                      withBlock callback: SimpleErrorBlock?) -> AsyncOperation {
    
    CCLog.verbose("Retrieve Digest of Story \(getUniqueIdentifier())")

    let retrieveDigestOperation = StoryAsyncOperation(on: .retrieveDigest, for: self, to: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
    parentOperation?.add(retrieveDigestOperation)
    asyncOperationQueue.addOperation(retrieveDigestOperation)
    return retrieveDigestOperation
  }
  
  
  // Function to save the Digest (Story minus the Moments)
  func saveDigest(to location: FoodieObject.StorageLocation,
                  type localType: FoodieObject.LocalType,
                  for parentOperation: AsyncOperation? = nil,
                  withBlock callback: SimpleErrorBlock?) {
    
    CCLog.verbose("Save Digest of Story \(getUniqueIdentifier())")
    
    let saveDigestOperation = StoryAsyncOperation(on: .saveDigest, for: self, to: location, type: localType, withBlock: callback)
    parentOperation?.add(saveDigestOperation)
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
                         for parentOperation: AsyncOperation? = nil,
                         withReady readyBlock: SimpleBlock? = nil,
                         withCompletion callback: SimpleErrorBlock?) {
    
    guard readyBlock == nil else {
      CCLog.fatal("FoodieStory does not support Ready Responses")
    }
    
    CCLog.verbose("Retrieve Recursive for Story \(getUniqueIdentifier())")
    
    let retrieveOperation = StoryAsyncOperation(on: .retrieveStory, for: self, to: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
    parentOperation?.add(retrieveOperation)
    asyncOperationQueue.addOperation(retrieveOperation)
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     for parentOperation: AsyncOperation? = nil,
                     withBlock callback: SimpleErrorBlock?) {
    
    CCLog.verbose("Save Recursive for Story \(getUniqueIdentifier())")
    
    let saveOperation = StoryAsyncOperation(on: .saveStory, for: self, to: location, type: localType, withBlock: callback)
    parentOperation?.add(saveOperation)
    asyncOperationQueue.addOperation(saveOperation)
  }
 
  
  // Trigger recursive delete against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       for parentOperation: AsyncOperation? = nil,
                       withBlock callback: SimpleErrorBlock?) {
    
    CCLog.verbose("Delete Recursive for Story \(getUniqueIdentifier())")
    
    let deleteOperation = StoryAsyncOperation(on: .deleteStory, for: self, to: location, type: localType, withBlock: callback)
    parentOperation?.add(deleteOperation)
    asyncOperationQueue.addOperation(deleteOperation)
  }
  
  
  func cancelRetrieveFromServerRecursive() {
    CCLog.info("Cancel All Rerieval (All Operations!) for Story \(getUniqueIdentifier())")
    asyncOperationQueue.cancelAllOperations()
  }
  
  
  func cancelSaveToServerRecursive() {
    CCLog.info("Cancel All Saves (All Operations!) for Story \(getUniqueIdentifier())")
    asyncOperationQueue.cancelAllOperations()
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

