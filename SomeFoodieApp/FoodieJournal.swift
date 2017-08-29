//
//  FoodieJournal.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//


import Parse

class FoodieJournal: FoodiePFObject, FoodieObjectDelegate {
  
  // MARK: - Parse PFObject keys
  // If new objects or external types are added here, check if save and delete algorithms needs updating
  @NSManaged var moments: Array<FoodieMoment>? // A FoodieMoment Photo or Video
  @NSManaged var thumbnailFileName: String? // URL for the thumbnail media. Needs to go with the thumbnail object.
  @NSManaged var type: Int // Really enum for the thumbnail type. Allow videos in the future?
  @NSManaged var aspectRatio: Double
  @NSManaged var width: Int
  @NSManaged var markups: Array<FoodieMarkup>? // Array of PFObjects as FoodieMarkup for the thumbnail
  @NSManaged var title: String? // Title for the Journal
  @NSManaged var author: FoodieUser? // Pointer to the user that authored this Moment
  @NSManaged var venue: FoodieVenue? // Pointer to the Restaurant object
  //@NSManaged var venueName: String? // Easy access to venue name
  @NSManaged var location: PFGeoPoint? // Geolocation of the Journal entry, TODO: Should be made into a relational query
  
  @NSManaged var journalURL: String? // URL to the Journal article
  @NSManaged var tags: Array<String>? // Array of Strings, unstructured

  @NSManaged var journalRating: Double // TODO: Placeholder for later rev
  @NSManaged var views: Int
  @NSManaged var clickthroughs: Int
  
  // Date created vs Date updated is given for free
  
  
  // MARK: Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case saveSyncFailedWithNoError
    case selfRetrievalJournalNilThumbnail
    case selfRetrievalThumbnailNilImage
    case contentRetrieveMomentArrayNil
    case contentRetrieveObjectNilNotMoment
    
    var errorDescription: String? {
      switch self {
      case .saveSyncFailedWithNoError:
        return NSLocalizedString("saveSync() Failed, but no Error was returned from saveRecursive", comment: "Error description for an exception error code")
      case .selfRetrievalJournalNilThumbnail:
        return NSLocalizedString("selfRetrieval() Journal retrieved with thumbnailFileName = nil", comment: "Error description for an exception error code")
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
      DebugPrint.error(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Public Constants
  struct Constants {
    static let MomentsToBufferAtATime = 2
  }
  
  
  // MARK: - Public Static Variables
  static var currentJournal: FoodieJournal? { return currentJournalPrivate }
  
  // MARK: - Private Static Variables
  private static var currentJournalPrivate: FoodieJournal?
  
  // MARK: - Public Instance Variables
  var thumbnailObj: FoodieMedia?
  var selfPrefetchContext: FoodiePrefetch.Context?
  var contentPrefetchContext: FoodiePrefetch.Context?


  // MARK: - Private Instance Variables
  fileprivate var contentRetrievalMutex = pthread_mutex_t()
  fileprivate var contentRetrievalInProg = false
  fileprivate var contentRetrievalPending = false
  fileprivate var contentRetrievalPendingCallback: FoodieObject.SimpleErrorBlock?
  
  // MARK: - Public Static Functions

  static func setJournal(journal: FoodieJournal) {
    currentJournalPrivate = journal
  }


  static func newCurrent() -> FoodieJournal {
    if currentJournalPrivate != nil {
      DebugPrint.assert(".newCurrent() without Save attempted but currentJournal != nil")
    }
    currentJournalPrivate = FoodieJournal(withState: .objectModified)

    guard let current = currentJournalPrivate else {
      DebugPrint.fatal("Just created a new FoodieJournal() but currentJournalPrivate still nil")
    }
    return current
  }
  

  // Function to create a new FoodieJournal as the current Journal. Save or discard the previous current Journal
  static func newCurrentSync(saveCurrent: Bool) throws -> FoodieJournal? {
    if saveCurrent {
      guard let current = currentJournalPrivate else {
        DebugPrint.assert("nil currentJournalPrivate on Journal Save when trying to create a new current Journal")
        return nil
      }
      
      // This save blocks until complete
      try current.saveSync()

    } else if currentJournalPrivate != nil {
      
      // make sure that this journal has never been saved to server before deleting otherwise you want to preserve it
      if(currentJournalPrivate?.foodieObject.operationState == .savedToLocal)
      {
        currentJournalPrivate?.deleteRecursive(withBlock: {(success,error)-> Void in
          if(success) {
            DebugPrint.verbose("Removed local copy from discared journal")
          }
        })
      }
      
      DebugPrint.log("Current Journal being overwritten without Save")
    } else {
      DebugPrint.assert("Use .newCurrent() without Save instead")  // Only barfs at development time. Continues on Production...
    }
    currentJournalPrivate = FoodieJournal(withState: .objectModified)
    return currentJournalPrivate
  }
  
  
  // Asynchronous version of creating a new Current Journal
  static func newCurrentAsync(saveCurrent: Bool, saveCallback: ((Bool, Error?) -> Void)?)  -> FoodieJournal? {
    if saveCurrent {
      // If anything fails here report failure up to Controller layer and let Controller handle
      guard let callback = saveCallback else {
        DebugPrint.assert("nil errorCallback on Journal Save when trying to create a new current Journal")
        return nil
      }
      guard let current = currentJournalPrivate else {
        DebugPrint.assert("nil currentJournalPrivate on Journal Save when trying ot create a new current Journal")
        return nil
      }
      
      // This save happens in the background
      current.saveAsync(callback: callback)
      
    } else if currentJournalPrivate != nil {
      DebugPrint.log("Current Journal being overwritten without Save")
    } else {
      DebugPrint.assert("Use .newCurrent() without Save instead")  // Only barfs at development time. Continues on Production...
    }
    currentJournalPrivate = FoodieJournal(withState: .objectModified)
    return currentJournalPrivate
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
  
  
  // Function to save Journal. Block until complete
  func saveSync() throws {
    
    var block = true
    var blockError: Error? = nil
    var blockSuccess = false
    var blockWait = 0
    
    saveRecursive(to: .local) { /*[unowned self]*/ (success, error) in
      if success {
        self.saveRecursive(to: .server) { (success, error) in
          if success {
            block = false
            blockSuccess = true
            blockError = nil
          } else {
            block = false
            blockSuccess = false
            blockError = error
          }
        }
      } else {
        block = false
        blockSuccess = false
        blockError = error
      }
    }
    
    while block {
      sleep(1)
      blockWait = blockWait + 1
    }
  
    DebugPrint.verbose("FoodieJournal.saveSync Completed. Save took \(blockWait) seconds")
  
    if let error = blockError {
      throw error
    } else if blockSuccess != true {
      throw ErrorCode(.saveSyncFailedWithNoError)
    }
    
    return
  }

  
  // Function to save Journal in background
  func saveAsync(callback: ((Bool, Error?) -> Void)?) {
    saveRecursive(to: .local) { /*[unowned self]*/ (success, error) in
      if success {
        self.saveRecursive(to: .server, withBlock: callback)
      } else {
        callback?(false, error)
      }
    }
  }
  

  // Function to add Moment to Journal. If no position specified, add to end of array
  func add(moment: FoodieMoment,
           to position: Int? = nil) {
    
    if position != nil {
      DebugPrint.assert("FoodieJournal.add(to position:) not yet implemented. Adding to 'end' position")
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
  
  
  func deleteAsync(withBlock callback: FoodieObject.BooleanErrorBlock?){
    deleteRecursive(withBlock: callback)
  }
  

  
  // Function to get index of specified Moment in Moment Array
  func getIndexOf(_ moment: FoodieMoment) -> Int {

    guard let momentArray = moments else {
      DebugPrint.fatal("journal.getIndexOf() has moments = nil. Invalid")
    }
    
    var index = 0
    while index < momentArray.count {
      if momentArray[index] === moment {
        return index
      }
      index += 1
    }
    
    DebugPrint.assert("journal.getIndexOf() cannot find Moment from Moment Array")
    return momentArray.count  // This is error case
  }
  
  
  func setGeoPoint(latitude: Double, longitude: Double) {
    location = PFGeoPoint(latitude: latitude, longitude: longitude)
  }
  
  
  // MARK: - Journal specific Retrieval algorithms
  
  // Function to retrieve the Journal minus the Moments
  func selfRetrieval(withBlock callback: FoodieObject.SimpleErrorBlock? = nil) {
    
    // Do we still need to fetch the Journal?
    retrieve() { journalError in
      if let error = journalError {
        DebugPrint.assert("Journal.retrieve() callback with error: \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      guard let thumbnailObject = self.thumbnailObj else {
        DebugPrint.assert("Unexpected, thumbnailObject = nil")
        callback?(ErrorCode.selfRetrievalJournalNilThumbnail)
        return
      }
      
      thumbnailObject.retrieve() { thumbnailError in
        if let error = thumbnailError {
          DebugPrint.assert("Thumbnail.retrieve() callback with error: \(error.localizedDescription)")
          callback?(error)
          return
        }
        
        // Both retrieved, we can now callback!
        callback?(nil)
      }
    }
  }
  
  
  // Function to mark Moments and Media to retrieve, and then kick off the retrieval state machine
  func contentRetrievalRequest(fromMoment startNumber: Int, forUpTo numberOfMoments: Int, withBlock callback: FoodieObject.SimpleErrorBlock? = nil) {
    
    guard let momentArray = moments else {
      DebugPrint.assert("journal.contentRetrieve momentArray = nil. Journal with 0 moment is invalid")
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
    pthread_mutex_lock(&contentRetrievalMutex)
    
    if contentRetrievalInProg {
      DebugPrint.verbose("Content Retrieval already in progress")
      contentRetrievalPending = true
      contentRetrievalPendingCallback = callback
    } else {
      DebugPrint.verbose("Content Retrieval begins")
      contentRetrievalInProg = true
      executeStateMachine = true
    }
    
    pthread_mutex_unlock(&contentRetrievalMutex)
    
    // Bringing function call out of critical section
    if executeStateMachine {
      contentRetrievalStateMachine(momentIndex: 0, withError: nil, withBlock: callback)
    }
  }
  
    
  // The brain of the content retrieval process
  func contentRetrievalStateMachine(momentIndex: Int, withError firstError: Error?, withBlock callback: FoodieObject.SimpleErrorBlock? = nil) {
    
    guard let momentArray = moments else {
      DebugPrint.assert("journal.contentRetrieve momentArray = nil unexpected")
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
          DebugPrint.error("journal.contentRetrieve moment.retrieveIfPending returned error = \(err.localizedDescription)")
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
    pthread_mutex_lock(&contentRetrievalMutex)
    
    if contentRetrievalPending {
      DebugPrint.verbose("Content Retrieval was pending. Initiate another round of Content Retrieval")
      contentRetrievalPending = false
      executeStateMachine = true
    } else {
      DebugPrint.verbose("Content Retrieval completes!")
      contentRetrievalInProg = false
    }
    
    pthread_mutex_unlock(&contentRetrievalMutex)
    
    // Bringing function call out of critical section
    if executeStateMachine {
      contentRetrievalStateMachine(momentIndex: 0, withError: nil, withBlock: contentRetrievalPendingCallback)
    }
  }
  

  // MARK: - Foodie Object Delegate Conformance
  
  override func retrieve(forceAnyways: Bool = false, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    super.retrieve(forceAnyways: forceAnyways) { error in
      if self.thumbnailObj == nil, let fileName = self.thumbnailFileName {
        self.thumbnailObj = FoodieMedia(withState: .notAvailable, fileName: fileName, type: .photo)  // TODO: This will cause double thumbnail. Already a copy in the Moment
      }
      callback?(error)  // Callback regardless
    }
  }
  
  
  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(forceAnyways: Bool = false, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Retrieve self first, then retrieve children afterwards
    retrieve(forceAnyways: forceAnyways) { error in
      
      if let journalError = error {
        DebugPrint.assert("Journal.retrieve() resulted in error: \(journalError.localizedDescription)")
        callback?(error)
        return
      }
      
      guard let thumbnail = self.thumbnailObj else {
        DebugPrint.assert("Unexpected Journal.retrieve() resulted in self.thumbnailObj = nil")
        callback?(error)
        return
      }
      
      self.foodieObject.resetOutstandingChildOperations()
      
      // Got through all sanity check, calling children's retrieveRecursive
      self.foodieObject.retrieveChild(thumbnail, forceAnyways: forceAnyways, withBlock: callback)
      
      if let hasMoments = self.moments {
        for moment in hasMoments {
          self.foodieObject.retrieveChild(moment, forceAnyways: forceAnyways, withBlock: callback)
        }
      }
      
      if let hasMarkups = self.markups {
        for markup in hasMarkups {
          self.foodieObject.retrieveChild(markup, forceAnyways: forceAnyways, withBlock: callback)
        }
      }
      
      // Do we need to retrieve User?
      
      if let venue = self.venue {
        self.foodieObject.retrieveChild(venue, forceAnyways: forceAnyways, withBlock: callback)
      }
    }
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                    withName name: String? = nil,
                    withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
//    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
//    
//    if let earlySuccess = earlyReturnStatus.success {
//      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
//      return
//    }
//    
    var childOperationPending = false
    self.foodieObject.resetOutstandingChildOperations()
    
    // Need to make sure all children FoodieRecursives saved before proceeding
    if let hasMoments = moments {
      for moment in hasMoments {
        // omit saving of moment if they are not marked modified to prevent double saving of moments to server
        if(moment.foodieObject.operationState == .objectModified ||
          moment.foodieObject.operationState == .savedToLocal)
        {
          foodieObject.saveChild(moment, to: location, withName: name, withBlock: callback)
          childOperationPending = true
        }
      }
    }
    
    // This is just a pointer to the existing thumbnail on the Moment, do we need to re-save? Or create a seperate Thumbnail?
//    if let thumbnail = thumbnailObj {
//      foodieObject.saveChild(thumbnail, to: location, withName: name, withBlock: callback)
//      childOperationPending = true
//    }
    
    if let hasMarkups = markups {
      for markup in hasMarkups {
        foodieObject.saveChild(markup, to: location, withName: name, withBlock: callback)
        childOperationPending = true
      }
    }
    
    // Do we need to save User? Is User considered modified?
    
    if let venue = venue {
      foodieObject.saveChild(venue, to: location, withName: name, withBlock: callback)
      childOperationPending = true
    }
    
    if !childOperationPending {
      DispatchQueue.global(qos: .userInitiated).async { /*[unowned self] in */
        self.foodieObject.savesCompletedFromAllChildren(to: location, withName: name, withBlock: callback)
      }
    }
  }
 
  // Trigger recursive delete against all child objects.
  func deleteRecursive(withName name: String? = nil,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    retrieve() { error in
      
      // TOOD: Victor, what happens if retrieve fails?
      
      self.foodieObject.deleteObjectLocalNServer(withName: name) { (success, error) in
        
        if (success) {
          self.foodieObject.resetOutstandingChildOperations()
          
          // check to see if there are more items such as moments, markups to delete
          if let hasMoment = self.moments {
            for moment in hasMoment {
              self.foodieObject.deleteChild(moment, withBlock: callback)
            }
          }
          
          if let hasMarkup = self.markups {
            for markup in hasMarkup {
              self.foodieObject.deleteChild(markup, withBlock: callback)
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
//    DebugPrint.verbose("FoodieJournal ID: \(getUniqueIdentifier())")
//    DebugPrint.verbose("  Title: \(title)")
//    DebugPrint.verbose("  Thumbnail Filename: \(thumbnailFileName)")
//    DebugPrint.verbose("  Contains \(moments!.count) Moments with ID as follows:")
//    
//    for moment in moments! {
//      DebugPrint.verbose("    \(moment.getUniqueIdentifier())")
//    }
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
        DebugPrint.verbose("doPrefetch journal.selfRetrieval")
        journal.selfRetrieval() { error in
          if let journalError = error {
            DebugPrint.assert("On prefetch, Journal.selfRetrieval() callback with error: \(journalError.localizedDescription)")
          }
          callback?(context)
        }
        
      } else {
        journal.contentRetrievalRequest(fromMoment: 0, forUpTo: Constants.MomentsToBufferAtATime) { error in
          if let journalError = error {
            DebugPrint.assert("On prefetch, Journal.contentRetrieval() callback with error: \(journalError.localizedDescription)")
          }
          callback?(context)
        }
      }
    }
  }
}
