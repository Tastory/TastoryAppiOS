//
//  FoodieJournal.swift
//  Eatelly
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 Eatelly. All rights reserved.
//


import Parse

class FoodieJournal: FoodiePFObject, FoodieObjectDelegate {
  
  // MARK: - Parse PFObject keys
  // If new objects or external types are added here, check if save and delete algorithms needs updating
  @NSManaged var moments: Array<FoodieMoment>? // A FoodieMoment Photo or Video
  @NSManaged var pendingDeleteMomentList: Array<FoodieMoment>?
  @NSManaged var thumbnailFileName: String? // URL for the thumbnail media. Needs to go with the thumbnail object.
  @NSManaged var type: Int // Really enum for the thumbnail type. Allow videos in the future?
  @NSManaged var aspectRatio: Double
  @NSManaged var width: Int
  @NSManaged var markups: Array<FoodieMarkup>? // Array of PFObjects as FoodieMarkup for the thumbnail
  
  @NSManaged var title: String? // Title for the Journal
  @NSManaged var author: FoodieUser? // Pointer to the user that authored this Moment
  @NSManaged var venue: FoodieVenue? // Pointer to the Restaurant object
  @NSManaged var authorText: String? // Placeholder before real user ability is added
  @NSManaged var journalURL: String? // URL to the Journal article
  @NSManaged var tags: Array<String>? // Array of Strings, unstructured

  @NSManaged var journalRating: Double // TODO: Placeholder for later rev
  @NSManaged var views: Int
  @NSManaged var clickthroughs: Int
  
  // Date created vs Date updated is given for free
  
  
  
  // MARK: Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case selfRetrievalJournalNilThumbnail
    case selfRetrievalJournalNilVenue
    case selfRetrievalThumbnailNilImage
    case contentRetrieveMomentArrayNil
    case contentRetrieveObjectNilNotMoment
    
    var errorDescription: String? {
      switch self {
      case .selfRetrievalJournalNilThumbnail:
        return NSLocalizedString("selfRetrieval() Journal retrieved with thumbnailFileName = nil", comment: "Error description for an exception error code")
      case .selfRetrievalJournalNilVenue:
        return NSLocalizedString("selfRetrieval() Journal retrieved with venue = nil", comment: "Error description for an exception error code")
      case .selfRetrievalThumbnailNilImage:
        return NSLocalizedString("selfRetrieval() Thumbnail retrieved with imageMemoryBuffer = nil", comment: "Error description for an exception error code")
      case .contentRetrieveMomentArrayNil:
        return NSLocalizedString("journal.contentRetrieve momentArray = nil unexpected", comment: "Error description for an exception error code")
      case .contentRetrieveObjectNilNotMoment:
        return NSLocalizedString("journal.contentRetrieve moment.retrieveIfPending returned nil or non-FoodieMoment object", comment: "Error description for an exception error code")
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
  fileprivate(set) static var currentJournal: FoodieJournal?
  
  
  
  // MARK: - Public Instance Variables
  var thumbnailObj: FoodieMedia?
  var selfPrefetchContext: FoodiePrefetch.Context?
  var contentPrefetchContext: FoodiePrefetch.Context?

  
  // MARK: - Private Instance Variables
  fileprivate var contentRetrievalMutex = SwiftMutex.create()
  fileprivate var contentRetrievalInProg = false
  fileprivate var contentRetrievalPending = false
  fileprivate var contentRetrievalPendingCallback: FoodieObject.SimpleErrorBlock?
  
  
  
  // MARK: - Public Static Functions
  static func newCurrent() -> FoodieJournal {
    if currentJournal != nil {
      CCLog.assert("Attempted to create a new currentJournal but currentJournal != nil")
    }
    
    currentJournal = FoodieJournal(withState: .objectModified)
    CCLog.debug("New Current Journal created. Session FoodieObject ID = \(currentJournal!.getUniqueIdentifier())")

    guard let current = currentJournal else {
      CCLog.fatal("Just created a new FoodieJournal but currentJournal still nil")
    }
    return current
  }
  
  
  static func removeCurrent() {
    if currentJournal == nil { CCLog.assert("CurrentJournal is already nil") }
    CCLog.debug("Current Journal Nil'd")
    currentJournal = nil
  }
  
  
  static func setCurrentJournal(to journal: FoodieJournal) {
    currentJournal = journal
    CCLog.debug("Current Journal set. Session FoodieObject ID = \(journal.getUniqueIdentifier())")
  }
  
  
  // MARK: - Public Instance Functions
  
  // This is the Initilizer Parse will call upon Query or Retrieves
  override init() {
    super.init(withState: .notAvailable)
    foodieObject.delegate = self
  }
  
  
  // This is the Initializer we will call internally
  override init(withState operationState: FoodieObject.OperationStates) {
    super.init(withState: operationState)
    foodieObject.delegate = self
  }
  
  
  // Function to add Moment to Journal. If no position specified, add to end of array
  func add(moment: FoodieMoment,
           to position: Int? = nil) {
    
    if position != nil {
      CCLog.assert("FoodieJournal.add(to position:) not yet implemented. Adding to 'end' position")
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
      CCLog.fatal("journal.getIndexOf() has moments = nil. Invalid")
    }
    
    var index = 0
    while index < momentArray.count {
      if momentArray[index] === moment {
        return index
      }
      index += 1
    }
    
    CCLog.assert("journal.getIndexOf() cannot find Moment from Moment Array")
    return momentArray.count  // This is error case
  }
  
  
  
  // MARK: - Journal specific Retrieval algorithms
  
  // Function to retrieve the Journal minus the Moments
  func selfRetrieval(withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Do we still need to fetch the Journal?
    retrieve(from: .both, type: .cache, forceAnyways: false) { error in
      
      if let error = error {
        CCLog.assert("Journal.retrieve() callback with error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      guard let thumbnailObject = self.thumbnailObj else {
        CCLog.assert("Unexpected, thumbnailObject = nil")
        callback?(ErrorCode.selfRetrievalJournalNilThumbnail)
        return
      }
      
      guard let venue = self.venue else {
        CCLog.assert("Unexpected, venue = nil")
        callback?(ErrorCode.selfRetrievalJournalNilVenue)
        return
      }
      
      thumbnailObject.retrieveRecursive(from: .both, type: .cache) { error in
        
        if let error = error {
          CCLog.warning("Thumbnail.retrieve() callback with error: \(error.localizedDescription)")
          callback?(error)
          return
        }
        
        venue.retrieveRecursive(from: .both, type: .cache) { error in
          if let error = error {
            CCLog.warning("Venue.retrieve() callback with error: \(error.localizedDescription)")
            callback?(error)
            return
          }
          
          // Both retrieved, we can now callback!
          callback?(nil)
        }
      }
    }
  }
  
  
  // Function to mark Moments and Media to retrieve, and then kick off the retrieval state machine
  func contentRetrievalRequest(fromMoment startNumber: Int, forUpTo numberOfMoments: Int, withBlock callback: FoodieObject.SimpleErrorBlock? = nil) {
    
    guard let momentArray = moments else {
      CCLog.assert("journal.contentRetrieve momentArray = nil. Journal with 0 moment is invalid")
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
      CCLog.verbose("Content Retrieval already in progress")
      contentRetrievalPending = true
      contentRetrievalPendingCallback = callback
    } else {
      CCLog.verbose("Content Retrieval begins")
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
  func contentRetrievalStateMachine(momentIndex: Int, withError firstError: Error?, withBlock callback: FoodieObject.SimpleErrorBlock? = nil) {
    
    guard let momentArray = moments else {
      CCLog.assert("journal.contentRetrieve momentArray = nil unexpected")
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
          CCLog.warning("journal.contentRetrieve moment.retrieveIfPending returned error = \(err.localizedDescription)")
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
      CCLog.verbose("Content Retrieval was pending. Initiate another round of Content Retrieval")
      contentRetrievalPending = false
      executeStateMachine = true
    } else {
      CCLog.verbose("Content Retrieval completes!")
      contentRetrievalInProg = false
    }
    
    SwiftMutex.unlock(&contentRetrievalMutex)
    
    // Bringing function call out of critical section
    if executeStateMachine {
      contentRetrievalStateMachine(momentIndex: 0, withError: nil, withBlock: contentRetrievalPendingCallback)
    }
  }
  

  // MARK: - Foodie Object Delegate Conformance
  
  fileprivate func retrieve(from location: FoodieObject.StorageLocation,
                            type localType: FoodieObject.LocalType,
                            forceAnyways: Bool,
                            withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    foodieObject.retrieveObject(from: location, type: localType, forceAnyways: forceAnyways) { error in
      
      if self.thumbnailObj == nil, let fileName = self.thumbnailFileName {
        self.thumbnailObj = FoodieMedia(withState: .notAvailable, for: fileName, localType: localType, mediaType: .photo)  // TODO: This will cause double thumbnail. Already a copy in the Moment
      }
      callback?(error)  // Callback regardless
    }
  }
  
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(from location: FoodieObject.StorageLocation,
                         type localType: FoodieObject.LocalType,
                         forceAnyways: Bool = false,
                         withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Retrieve self first, then retrieve children afterwards
    retrieve(from: location, type: localType, forceAnyways: forceAnyways) { error in
      
      if let error = error {
        CCLog.assert("Journal.retrieve() resulted in error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      guard let thumbnail = self.thumbnailObj else {
        CCLog.assert("Unexpected Journal.retrieve() resulted in self.thumbnailObj = nil")
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
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
//    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
//    
//    if let earlySuccess = earlyReturnStatus.success {
//      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
//      return
//    }
//
    self.foodieObject.resetOutstandingChildOperations()
    var childOperationPending = false
    
    // Need to make sure all children FoodieRecursives saved before proceeding
    if let moments = moments {
      for moment in moments {
        foodieObject.saveChild(moment, to: location, type: localType, withBlock: callback)
        childOperationPending = true
      }
    }
    
    // This is just a pointer to the existing thumbnail on the Moment, do we need to re-save? Or create a seperate Thumbnail?
//    if let thumbnail = thumbnailObj {
//      foodieObject.saveChild(thumbnail, to: location, withName: name, withBlock: callback)
//      childOperationPending = true
//    }
    
    if let hasMarkups = markups {
      for markup in hasMarkups {
        foodieObject.saveChild(markup, to: location, type: localType, withBlock: callback)
        childOperationPending = true
      }
    }
    
    // Do we need to save User? Is User considered modified?
    
    if let venue = venue {
      foodieObject.saveChild(venue, to: location, type: localType, withBlock: callback)
      childOperationPending = true
    }
    
    if !childOperationPending {
      DispatchQueue.global(qos: .userInitiated).async {
        self.foodieObject.savesCompletedFromAllChildren(to: location, type: localType, withBlock: callback)
      }
    }
  }
 
  
  // Trigger recursive delete against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Retrieve the Journal (only) to guarentee access to the childrens
    retrieve(from: location, type: localType, forceAnyways: false) { error in
      
      if let error = error {
        CCLog.assert("Journal.retrieve() resulted in error: \(error.localizedDescription)")
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
  
  
  func foodieObjectType() -> String {
    return "FoodieJournal"
  }
}


// MARK: - Parse Subclass Conformance
extension FoodieJournal: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieJournal"
  }
}


extension FoodieJournal: FoodiePrefetchDelegate {
  
  func removePrefetchContexts() {
    selfPrefetchContext = nil
    contentPrefetchContext = nil
  }
  
  func doPrefetch(on objectToFetch: AnyObject, for context: FoodiePrefetch.Context, withBlock callback: FoodiePrefetch.PrefetchCompletionBlock? = nil) {
    if let journal = objectToFetch as? FoodieJournal {
      
      if journal.thumbnailObj == nil {
        // No Thumbnail Object, so assume the Journal itself needs to be retrieved
        CCLog.verbose("doPrefetch journal.selfRetrieval")
        journal.selfRetrieval() { error in
          if let journalError = error {
            CCLog.assert("On prefetch, Journal.selfRetrieval() callback with error: \(journalError.localizedDescription)")
          }
          callback?(context)
        }
        
      } else {
        journal.contentRetrievalRequest(fromMoment: 0, forUpTo: Constants.MomentsToBufferAtATime) { error in
          if let journalError = error {
            CCLog.assert("On prefetch, Journal.contentRetrieval() callback with error: \(journalError.localizedDescription)")
          }
          callback?(context)
        }
      }
    }
  }
}
