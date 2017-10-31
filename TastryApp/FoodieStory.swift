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
    
    private var childOperations = [AsyncOperation]()
    
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
          self.callback?(error)
          self.finished()
        }
        
      case .saveStory:
        story.saveOpRecursive(for: self, to: location, type: localType) { error in
          self.callback?(error)
          self.finished()
        }
        
      case .deleteStory:
        story.deleteOpRecursive(for: self, from: location, type: localType) { error in
          self.callback?(error)
          self.finished()
        }
        
      case .retrieveDigest:
        story.retrieveOpDigest(for: self, from: location, type: localType, forceAnyways: forceAnyways) { error in
          self.callback?(error)
          self.finished()
        }
      
      case .saveDigest:
        story.saveOpDigest(for: self, to: location, type: localType) { error in
          self.callback?(error)
          self.finished()
        }
      }
    }
    
    func add(_ childOperation: AsyncOperation) {
      childOperations.append(childOperation)
    }
    
    override func cancel() {
      // Sample isExecuting firsty
      let executing = isExecuting
      
      // Cancel regardless
      super.cancel()
      
      CCLog.debug("Cancel for Story \(story.getUniqueIdentifier()), Executing = \(executing)")
      
      if executing {
        story.childOperationQueue.async {
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
  
  
  
  // MARK: - Public Constants
  struct Constants {
    static let MomentsToBufferAtATime = 2
  }
  
  
  
  // MARK: - Public Read-Only Static Variables
  private(set) static var currentStory: FoodieStory?
  
  
  
  // MARK: - Public Instance Variables
  var thumbnail: FoodieMedia?
  //var operation: StoryOperation?
  var childOperationQueue = DispatchQueue(label: "Child Operation Queue", qos: .userInitiated)
  
  
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
      
      guard let thumbnail = self.thumbnail else {
        CCLog.fatal("Story retrieved but thumbnail = nil")
      }
      
      guard let venue = self.venue else {
        CCLog.fatal("Story retrieved but venue = nil")
      }
      
      guard let author = self.author else {
        CCLog.fatal("Story retrieved but author = nil")
      }
      
      self.foodieObject.resetChildOperationVariables()
      
      self.childOperationQueue.async {
        guard !storyOperation.isCancelled else {
          callback?(ErrorCode.operationCancelled)
          return
        }
        
        if let childOperation = self.foodieObject.retrieveChild(thumbnail, from: location, type: localType, forceAnyways: forceAnyways, on: self.childOperationQueue, withReady: self.executeReady, withCompletion: callback) {
          storyOperation.add(childOperation)
        }
        
        if let childOperation = self.foodieObject.retrieveChild(venue, from: location, type: localType, forceAnyways: forceAnyways, on: self.childOperationQueue, withReady: self.executeReady, withCompletion: callback) {
          storyOperation.add(childOperation)
        }
        
        if let markups = self.markups {
          for markup in markups {
            if let childOperation = self.foodieObject.retrieveChild(markup, from: location, type: localType, forceAnyways: forceAnyways, on: self.childOperationQueue, withReady: self.executeReady, withCompletion: callback) {
              storyOperation.add(childOperation)
            }
          }
        }
        
        if localType != .draft {
          if let childOperation  = self.foodieObject.retrieveChild(author, from: location, type: localType, forceAnyways: forceAnyways, on: self.childOperationQueue, withReady: self.executeReady, withCompletion: callback) {
            storyOperation.add(childOperation)
          }
        }
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
    
    self.foodieObject.resetChildOperationVariables()
    
    childOperationQueue.async {
      guard !storyOperation.isCancelled else {
        callback?(ErrorCode.operationCancelled)
        return
      }
      
      var childOperationPending = false
      
      // Need to make sure all children recursive saved before proceeding
      
      // We will assume that the Moment will get saved properly, avoiding a double save on the Thumbnail
      // We are not gonna save the User here either
      
      if let markups = self.markups {
        for markup in markups {
          if let childOperation = self.foodieObject.saveChild(markup, to: location, type: localType, on: self.childOperationQueue, withBlock: callback) {
            storyOperation.add(childOperation)
          }
          childOperationPending = true
        }
      }
      
      if let venue = self.venue {
        if let childOperation = self.foodieObject.saveChild(venue, to: location, type: localType, on: self.childOperationQueue, withBlock: callback) {
          storyOperation.add(childOperation)
        }
        childOperationPending = true
      }
      
      if let author = self.author, localType != .draft {
        if let childOperation = self.foodieObject.saveChild(author, to: location, type: localType, on: self.childOperationQueue, withBlock: callback) {
          storyOperation.add(childOperation)
        }
        childOperationPending = true
      }
      
      if !childOperationPending {
        self.foodieObject.savesCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
      }
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
      
      guard let thumbnail = self.thumbnail else {
        CCLog.fatal("Unexpected Story.retrieve() resulted in self.thumbnail = nil")
      }
      
      self.foodieObject.resetChildOperationVariables()
      
      self.childOperationQueue.async {
        guard !storyOperation.isCancelled else {
          callback?(ErrorCode.operationCancelled)
          return
        }
        
        if let childOperation = self.foodieObject.retrieveChild(thumbnail, from: location, type: localType, forceAnyways: forceAnyways, on: self.childOperationQueue, withCompletion: callback) {
          storyOperation.add(childOperation)
        }
        
        if let moments = self.moments {
          for moment in moments {
            if let childOperation = self.foodieObject.retrieveChild(moment, from: location, type: localType, forceAnyways: forceAnyways, on: self.childOperationQueue, withCompletion: callback) {
              storyOperation.add(childOperation)
            }
          }
        }
        
        if let markups = self.markups {
          for markup in markups {
            if let childOperation = self.foodieObject.retrieveChild(markup, from: location, type: localType, forceAnyways: forceAnyways, on: self.childOperationQueue, withCompletion: callback) {
              storyOperation.add(childOperation)
            }
          }
        }
        
        if let venue = self.venue {
          if let childOperation = self.foodieObject.retrieveChild(venue, from: location, type: localType, forceAnyways: forceAnyways, on: self.childOperationQueue, withCompletion: callback) {
            storyOperation.add(childOperation)
          }
        }
        
        if let author = self.author, localType != .draft {
          if let childOperation = self.foodieObject.retrieveChild(author, from: location, type: localType, forceAnyways: forceAnyways, on: self.childOperationQueue, withCompletion: callback) {
            storyOperation.add(childOperation)
          }
        }
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
    
    self.foodieObject.resetChildOperationVariables()
    
    childOperationQueue.async {
      guard !storyOperation.isCancelled else {
        callback?(ErrorCode.operationCancelled)
        return
      }
      var childOperationPending = false
      
      // Need to make sure all children recursive saved before proceeding
      // We will assume that the Moment will get saved properly, avoiding a double save on the Thumbnail
      
      if let moments = self.moments {
        for moment in moments {
          if let childOperation = self.foodieObject.saveChild(moment, to: location, type: localType, on: self.childOperationQueue, withBlock: callback){
            storyOperation.add(childOperation)
          }
          childOperationPending = true
        }
      }
      
      if let markups = self.markups {
        for markup in markups {
          if let childOperation = self.foodieObject.saveChild(markup, to: location, type: localType, on: self.childOperationQueue, withBlock: callback) {
            storyOperation.add(childOperation)
          }
          childOperationPending = true
        }
      }
      
      if let venue = self.venue {
        if let childOperation = self.foodieObject.saveChild(venue, to: location, type: localType, on: self.childOperationQueue, withBlock: callback) {
          storyOperation.add(childOperation)
        }
        childOperationPending = true
      }
      
      if let author = self.author, localType != .draft {
        if let childOperation = self.foodieObject.saveChild(author, to: location, type: localType, on: self.childOperationQueue, withBlock: callback) {
          storyOperation.add(childOperation)
        }
        childOperationPending = true
      }
      
      if !childOperationPending {
        self.foodieObject.savesCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
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
      
      // Delete self first before deleting children
      self.foodieObject.deleteObject(from: location, type: localType) { error in
        
        if let error = error {
          CCLog.warning("Deleting self resulted in error: \(error.localizedDescription)")
          
          // Do best effort delete of all children
          if let moments = self.moments {
            for moment in moments {
              _ = self.foodieObject.deleteChild(moment, from: location, type: localType, on: self.childOperationQueue, withBlock: nil)
            }
          }
          
          if let markups = self.markups {
            for markup in markups {
              _ = self.foodieObject.deleteChild(markup, from: location, type: localType, on: self.childOperationQueue, withBlock: nil)
            }
          }
          
          if let venue = self.venue {
            _ = self.foodieObject.deleteChild(venue, from: .local, type: localType, on: self.childOperationQueue, withBlock: nil)  // Don't ever delete venues from the server
          }
          
          // Delete user only if from Cache and it's not the current user
          if let author = self.author, author != FoodieUser.current, localType != .draft {
            _ = self.foodieObject.deleteChild(author, from: .local, type: localType, on: self.childOperationQueue, withBlock: nil)  // Don't delete User as part of a recursive operation
          }
          
          // Don't delete Thumbnail!!!
          
          // Just callback with the error
          callback?(error)
          return
        }
        
        self.foodieObject.resetChildOperationVariables()
       
        self.childOperationQueue.async {
          guard !storyOperation.isCancelled else {
            callback?(ErrorCode.operationCancelled)
            return
          }
          var childOperationPending = false
          
          if let moments = self.moments {
            for moment in moments {
              if let childOperation = self.foodieObject.deleteChild(moment, from: location, type: localType, on: self.childOperationQueue, withBlock: callback) {
                storyOperation.add(childOperation)
              }
              childOperationPending = true
            }
          }
          
          if let markups = self.markups {
            for markup in markups {
              if let childOperation = self.foodieObject.deleteChild(markup, from: location, type: localType, on: self.childOperationQueue, withBlock: callback) {
                storyOperation.add(childOperation)
              }
              childOperationPending = true
            }
          }
          
          if let venue = self.venue {
            if let childOperation = self.foodieObject.deleteChild(venue, from: .local, type: localType, on: self.childOperationQueue, withBlock: nil) { // Don't ever delete venues from the server
              storyOperation.add(childOperation)
            }
          }
          
          // Delete user only if from Cache and it's not the current user
          if let author = self.author, author != FoodieUser.current {
            if let childOperation = self.foodieObject.deleteChild(author, from: .local, type: localType, on: self.childOperationQueue, withBlock: nil) { // Don't delete User as part of a recursive operation
              storyOperation.add(childOperation)
            }
          }
          
          if !childOperationPending {
            CCLog.assert("No child deletes pending. Is this okay?")
            callback?(error)
          }
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
    
    if let markups = markups {
      for markup in markups {
        markup.cancelSaveToServerRecursive()
      }
    }
    
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
      self.moments!.append(moment)
    } else {
      self.moments = [moment]
    }
  }

  static func cleanUpDraft(withBlock callback: @escaping SimpleErrorBlock) {
    guard let story = currentStory else {
      CCLog.fatal("Discard current Story but no current Story")
    }

    story.cancelSaveToServerRecursive()

    var location: FoodieObject.StorageLocation = .both
    if(story.objectId != nil) {
      // this indicate that we are editing a story
      location = .local
    }

    // Delete all traces of this unPosted Story
    story.deleteRecursive(from: location, type: .draft) { error in
      if let error = error {
        CCLog.warning("Deleting Story resulted in Error - \(error.localizedDescription)")
        callback(error)
      }

      // restore the thumbnail correctly
      if let moments = story.moments {
        for moment in moments {
          if(moment.thumbnailFileName == story.thumbnailFileName) {
            story.thumbnail = moment.thumbnail
          }

          // clean up video player
          if(moment.media != nil) {
            moment.media!.videoExportPlayer = nil

          }
        }
      }
      removeCurrent()
      callback(nil)
    }
  }

  static func preSave(_ object: FoodieObjectDelegate?, withBlock callback: SimpleErrorBlock?) {

    CCLog.debug("Pre-Save Operation Started")

    guard let story = currentStory else {
      CCLog.fatal("No Working Story on Pre Save")
    }

    // Save Story to Local 
    _ = story.saveRecursive(to: .local, type: .draft) { error in

      if let error = error {
        CCLog.warning("Story pre-save to Local resulted in error - \(error.localizedDescription)")
        callback?(error)
        return
      }
      CCLog.debug("Completed pre-saving Story to Local")

      guard let object = object else {
        CCLog.debug("No Foodie Object supplied on preSave(), skipping Object Server save")
        callback?(nil)
        return
      }
      
      // The only reason why this is working is because story.saveDigest actually saves every single child PFObjects also.
      // Otherwise if a Moment PreSave to .both is stuck waiting for a large media upload and the user kills the app,
      // the Moment save to Parse Database (and Server) actually takes place after the server save completes...

      // Okay screw this, add an extra step to save to Local first. Then save to Both. Just to make double sure in case
      // One day we somehow turn off recursive child saves on Parse
      _ = object.saveRecursive(to: .local, type: .draft) { error in

        if let error = error {
          CCLog.warning("\(object.foodieObjectType()) pre-save to local resulted in error - \(error.localizedDescription)")
          callback?(error)
          return
        }

        CCLog.debug("Completed Pre-Saving \(object.foodieObjectType()) to Local")
        _ = object.saveRecursive(to: .both, type: .draft) { error in

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
    
    guard let thumbnail = thumbnail, let venue = venue, let author = author else {
      // If anything is nil, just re-retrieve? CCLog.assert("Thumbnail, Markups and Venue should all be not nil")
      return false
    }
    
    var markupsAreRetrieved = true
    if let markups = markups {
      for markup in markups {
        markupsAreRetrieved = markupsAreRetrieved && markup.isRetrieved
      }
    }
    
    return thumbnail.isRetrieved && venue.isRetrieved && markupsAreRetrieved && author.isRetrieved
  }
  
  
  // Function to retrieve the Digest (Story minus the Moments)
  func retrieveDigest(from location: FoodieObject.StorageLocation,
                      type localType: FoodieObject.LocalType,
                      forceAnyways: Bool = false,
                      withBlock callback: SimpleErrorBlock?) -> AsyncOperation? {
    
    CCLog.verbose("Retrieve Digest of Story \(getUniqueIdentifier())")

    let retrieveDigestOperation = StoryAsyncOperation(on: .retrieveDigest, for: self, to: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
    asyncOperationQueue.addOperation(retrieveDigestOperation)
    
    return retrieveDigestOperation
  }
  
  
  // Function to save the Digest (Story minus the Moments)
  func saveDigest(to location: FoodieObject.StorageLocation,
                  type localType: FoodieObject.LocalType,
                  withBlock callback: SimpleErrorBlock?) -> AsyncOperation? {
    
    CCLog.verbose("Save Digest of Story \(getUniqueIdentifier())")
    
    let saveDigestOperation = StoryAsyncOperation(on: .saveDigest, for: self, to: location, type: localType, withBlock: callback)
    asyncOperationQueue.addOperation(saveDigestOperation)
    
    return saveDigestOperation
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
                         withCompletion callback: SimpleErrorBlock?) -> AsyncOperation? {
    
    guard readyBlock == nil else {
      CCLog.fatal("FoodieStory does not support Ready Responses")
    }
    
    CCLog.verbose("Retrieve Recursive for Story \(getUniqueIdentifier())")
    
    let retrieveOperation = StoryAsyncOperation(on: .retrieveStory, for: self, to: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
    asyncOperationQueue.addOperation(retrieveOperation)
    
    return retrieveOperation
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     withBlock callback: SimpleErrorBlock?) -> AsyncOperation? {
    
    CCLog.verbose("Save Recursive for Story \(getUniqueIdentifier())")
    
    let saveOperation = StoryAsyncOperation(on: .saveStory, for: self, to: location, type: localType, withBlock: callback)
    asyncOperationQueue.addOperation(saveOperation)
    
    return saveOperation
  }
 
  
  // Trigger recursive delete against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       withBlock callback: SimpleErrorBlock?) -> AsyncOperation? {
    
    CCLog.verbose("Delete Recursive for Story \(getUniqueIdentifier())")
    
    let deleteOperation = StoryAsyncOperation(on: .deleteStory, for: self, to: location, type: localType, withBlock: callback)
    asyncOperationQueue.addOperation(deleteOperation)
    
    return deleteOperation
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

