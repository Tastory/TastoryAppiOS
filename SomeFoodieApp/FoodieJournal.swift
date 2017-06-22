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
  @NSManaged var eatery: FoodieEatery? // Pointer to the Restaurant object
  @NSManaged var eateryName: String? // Easy access to eatery name
  @NSManaged var categories: Array<FoodieCategory>? // Array of internal restaurant categoryIDs (all cateogires that applies, most accurate at index 0. Remove top levels if got sub already)
  @NSManaged var location: PFGeoPoint? // Geolocation of the Journal entry
  
  @NSManaged var mondayOpen: Int // Open time in seconds
  @NSManaged var mondayClose: Int // Close time in seconds
  @NSManaged var tuesdayOpen: Int
  @NSManaged var tuesdayClose: Int
  @NSManaged var wednesdayOpen: Int
  @NSManaged var wednesdayClose: Int
  @NSManaged var thursdayOpen: Int
  @NSManaged var thursdayClose: Int
  @NSManaged var fridayOpen: Int
  @NSManaged var fridayClose: Int
  @NSManaged var saturdayOpen: Int
  @NSManaged var saturdayClose: Int
  @NSManaged var sundayOpen: Int
  @NSManaged var sundayClose: Int
  
  @NSManaged var journalURL: String? // URL to the Journal article
  @NSManaged var tags: Array<String>? // Array of Strings, unstructured

  @NSManaged var journalRating: Double // TODO: Placeholder for later rev
  @NSManaged var views: Int
  @NSManaged var clickthroughs: Int
  
  // Date created vs Date updated is given for free
  
  
  // MARK: - Types & Enumerations
  enum FoodieJournalError: LocalizedError {
    case saveSyncParseRethrowGeneric
  }
  
  
  // MARK: Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case saveSyncFailedWithNoError
    
    var errorDescription: String? {
      switch self {
      case .saveSyncFailedWithNoError:
        return NSLocalizedString("saveSync Failed, but no Error was returned from saveRecursive", comment: "Error description for an exception error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      DebugPrint.error(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Public Static Variables
  static var currentJournal: FoodieJournal? { return currentJournalPrivate }
  
  // MARK: - Private Static Variables
  private static var currentJournalPrivate: FoodieJournal?
  
  // MARK: - Public Instance Variables
  var thumbnailObj: FoodieMedia?
  var foodieObject = FoodieObject()


  // MARK: - Private Instance Variables
  fileprivate var contentRetrievalInProg = false
  fileprivate var contentRetrievalPending = false
  
  
  // MARK: - Public Static Functions
  
  // Function to create a new FoodieJournal as the current Journal. Will assert if there already is a current Journal
  static func newCurrent() -> FoodieJournal {
    if currentJournalPrivate != nil {
      DebugPrint.assert(".newCurrent() without Save attempted but currentJournal != nil")
    }
    currentJournalPrivate = FoodieJournal()
    
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
      DebugPrint.log("Current Journal being overwritten without Save")
    } else {
      DebugPrint.assert("Use .newCurrent() without Save instead")  // Only barfs at development time. Continues on Production...
    }
    currentJournalPrivate = FoodieJournal()
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
    currentJournalPrivate = FoodieJournal()
    return currentJournalPrivate
  }
  
  
  // Querying function for All
  static func queryAll(skip: Int = 0, limit: Int, block: FoodieObject.QueryResultBlock?) { // Sorted by modified date in new to old order
    let query = PFQuery(className: FoodieJournal.parseClassName())
    query.skip = skip
    query.limit = limit
    //query.order(byDescending: <#T##String#>)
    query.findObjectsInBackground { pfObjectArray, error in
      block?(pfObjectArray, error)
    }
  }
  
  // More complex Query functionality TBD. Need a query structure? Query class? Hmm...
  // Caching Queries
  
  
  // MARK: - Public Instance Functions
  override init() {
    super.init()
    foodieObject.delegate = self
  }
  
  
  // Function to save Journal. Block until complete
  func saveSync() throws {
    
    var block = true
    var blockError: Error? = nil
    var blockSuccess = false
    var blockWait = 0
    
    saveRecursive(to: .local) { [unowned self] (success, error) in
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
    saveRecursive(to: .local) { [unowned self] (success, error) in
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
    
    // Temporary Code?
    if self.moments != nil {
      self.moments!.append(moment)
    } else {
      self.moments = [moment]
    }
    
    // Set all the approrpriate sync status bits for the Moment
    // Redetermine what sync should be performed against the Moments of the Journal
  }
  
  
  // Function to move Moment to specified position in Moment array. Return failure if moving past end of array
  // Other Moments in the array might have their position altered accordingly
  // Controller layer should query to confirm how other Moments might have their orders and positions changed
  func move(moment: FoodieMoment,
            to position: Int) {
    
  }
  
  
  func deleteAsync(withBlock callback: FoodieObject.BooleanErrorBlock?){
    deleteRecursive(withBlock: callback)
  }
  

  
  // Function to mark Moments and Media to retrieve, and then kick off the retrieval state machine
  func contentRetrievalKickoff(fromMoment startNumber: Int, forUpTo numberOfMoments: Int) {
    
    guard let momentArray = moments else {
      DebugPrint.assert("Unexpected FoodieJournal.moments = nil")
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
      _ = moment.foodieObject.markRetrieval()
      
      numberToRetrieve -= 1
      index += 1
    }
    
    // Start the content retrieval state machine if it's not already started
    // TODO: Do we need a mutex lock here?
    if contentRetrievalInProg {
      DebugPrint.verbose("Content retrieval already in progress.")
      contentRetrievalPending = true
    } else {
      DebugPrint.verbose("Content retrieval begins.")
      contentRetrievalInProg = true
      contentRetrievalStateMachine()
    }
  }
  
    
  // The brain of the content retrieval process
  func contentRetrievalStateMachine() {
    
    guard let momentArray = moments else {
      DebugPrint.assert("Unexpected FoodieJournal.moments = nil")
      return
    }
    
    DebugPrint.verbose("contentRetrievalStateMachine called")
    
    for moment in momentArray {
      
      // Retrieve the Moment first. One step at a time...
      if moment.foodieObject.retrieveIfPending(withBlock: { [unowned self] (retrieved, error) in
        if let err = error {
          // TODO: How do we signal a background task error?
          DebugPrint.error("Moment.retrieve Error = \(err.localizedDescription)")
        } else {
          guard let retrievedMoment = retrieved as? FoodieMoment else {
            DebugPrint.assert("Unexpected retrievedMoment = nil")
            return
          }
          
          DebugPrint.verbose("FoodieMoment \(retrievedMoment.objectId!) retrieved!")
          
          guard let media = retrievedMoment.mediaObj else {
            DebugPrint.assert("Unexpected retrievedMoment.mediaObj = nil")
            return
          }
          
          // Mark all the Media and Markups as for retrieval
          _ = media.foodieObject.markRetrieval()
          
          // There might not be any Markups
          if let markups = retrievedMoment.markups {
            for markup in markups {
              _ = markup.foodieObject.markRetrieval()
            }
          }
        }
        self.contentRetrievalStateMachine()
      }) { return }
      
      DebugPrint.verbose("Retrieving Media and Markup for FoodieMoment \(moment.objectId!)")
      
      guard let media = moment.mediaObj else {
        // No Media. Nothing to do for this moment?
        DebugPrint.verbose("Moment.mediaObj = nil")
        continue
      }
      
      // Retrieve the Media
      if media.foodieObject.retrieveIfPending(withBlock: { [unowned self] (retrieved, error) in
        if let err = error {
          // TODO: How do we signal a background task error?
          DebugPrint.error("Media.retrieve Error = \(err.localizedDescription)")
        } else {
          DebugPrint.verbose("FoodieMedia retrieved!")
        }
        self.contentRetrievalStateMachine()
      }) { return }
      
      guard let markupArray = moment.markups else {
        // No Markups. This moment is done
        DebugPrint.verbose("Markups = nil")
        moment.setContentsRetrieved()
        continue
      }
      
      // Retrieve the Markups
      for markup in markupArray {
        if markup.foodieObject.retrieveIfPending(withBlock: { [unowned self] retrieved, error in
          if let err = error {
            // TODO: How do we signal a background task error?
            DebugPrint.error("Markup.retrieved Error = \(err.localizedDescription)")
          }
          self.contentRetrievalStateMachine()
        }) { return }
      }
      moment.setContentsRetrieved()
    }

    // TODO: Do we need a mutex lock here
    if contentRetrievalPending {
      DebugPrint.verbose("Content retrieval was pending. Initiate another round of content retrieval")
      contentRetrievalPending = false
      contentRetrievalStateMachine()
    } else {
      DebugPrint.verbose("Content retrieval completes!")
      contentRetrievalInProg = false
    }
  }
  

  // MARK: - Foodie Object Delegate Conformance
  
  override func retrieve(forceAnyways: Bool = false, withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    super.retrieve(forceAnyways: forceAnyways) { (someObject, error) in
      if let journal = someObject as? FoodieJournal, journal.thumbnailObj == nil, let fileName = journal.thumbnailFileName {
        journal.thumbnailObj = FoodieMedia(fileName: fileName, type: .photo)  // TODO: This will cause double thumbnail. Already a copy in the Moment
      }
      callback?(someObject, error)  // Callback regardless
    }
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                    withName name: String? = nil,
                    withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    DebugPrint.verbose("FoodieJournal.saveRecursive to Location: \(location)")
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
    
    if let earlySuccess = earlyReturnStatus.success {
      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
      return
    }
    
    var childOperationPending = false
    
    // Need to make sure all children FoodieRecursives saved before proceeding
    if let hasMoments = moments {
      for moment in hasMoments {
        foodieObject.saveChild(moment, to: location, withName: name, withBlock: callback)
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
        foodieObject.saveChild(markup, to: location, withName: name, withBlock: callback)
        childOperationPending = true
      }
    }
    
    // Do we need to save User? Is User considered modified?
    
    if let eatery = eatery {
      foodieObject.saveChild(eatery, to: location, withName: name, withBlock: callback)
      childOperationPending = true
    }
    
    if let hasCategories = categories {
      for category in hasCategories {
        foodieObject.saveChild(category, to: location, withName: name, withBlock: callback)
        childOperationPending = true
      }
    }
    
    if !childOperationPending {
      DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
        self.foodieObject.savesCompletedFromAllChildren(to: location, withBlock: callback)
      }
    }
  }
 
  // Trigger recursive delete against all child objects.
  func deleteRecursive(withName name: String? = nil,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    DebugPrint.verbose("FoodieJournal.deleteRecursive \(objectId)")
    self.retrieve() { (success, error) in
      
      // TOOD: Victor, what happens if retrieve fails?
      
      self.foodieObject.deleteObjectLocalNServer(withName: name) { (success, error) in
        
        if (success) {
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
    return "FoodieJournalDemo"
  }
}
