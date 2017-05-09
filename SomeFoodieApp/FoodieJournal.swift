//
//  FoodieJournal.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//


import Parse

class FoodieJournal: FoodieObject {
  
  // MARK: - Parse PFObject keys
  @NSManaged var moments: Array<PFObject>? // A FoodieMoment Photo or Video
  @NSManaged var thumbnail: PFFile? // Thumbnail for the Journal
  @NSManaged var type: Int // Really enum for the thumbnail type. Allow videos in the future?
  @NSManaged var aspectRatio: Double
  @NSManaged var width: Int
  @NSManaged var markup: Array<PFObject>? // Array of PFObjects as FoodieMarkup for the thumbnail
  @NSManaged var title: String? // Title for the Journal
  @NSManaged var author: PFUser? // Pointer to the user that authored this Moment
  @NSManaged var eatery: PFObject? // Pointer to the Restaurant object
  @NSManaged var eateryName: String? // Easy access to eatery name
  @NSManaged var categories: Array<Int>? // Array of internal restaurant categoryIDs (all cateogires that applies, most accurate at index 0. Remove top levels if got sub already)
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
  
  
  // MARK: - Internal Static Variable
  static var currentJournal: FoodieJournal? { return currentJournalPrivate }
  
  
  // MARK: - Private Static Variable
  private static var currentJournalPrivate: FoodieJournal?
  
  
  // MARK: - Internal Static Functions
  
  // FUNCTION newCurrent - Create a new FoodieJournal as the current Journal. Will assert if there already is a current Journal
  
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
  
  // FUNCTION newCurrentSync - Create a new FoodieJournal as the current Journal. Save or discard the previous current Journal
  
  static func newCurrentSync(saveCurrent: Bool) throws -> FoodieJournal? {
    if saveCurrent {
      guard let current = currentJournalPrivate else {
        DebugPrint.assert("nil currentJournalPrivate on Journal Save when trying ot create a new current Journal")
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
  
  
  // FUNCTION newCurrentAsync - Asynchronouse version of creating a new Current Journal
  
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
  
  
  // MARK: - Internal Instance Functions
  
  // Functions managing the Journal itself
  
  // FUNCTION saveSync - Save Journal. Block until complete
  
  func saveSync() throws {
    
    // TODO: Complex algorithm to ensure that all the attached Moments have been saved.
    do {
      try self.save()
    }
    catch let thrown {
      // TODO: This rethrow is ugly as sh_t...
      let error = thrown as NSError
      let foodieErrorCode = FoodieError.Code.Journal.saveSyncParseRethrowGeneric.rawValue | error.code
      throw FoodieError(error: foodieErrorCode, description: error.localizedDescription)
    }
  }

  
  // FUNCTION saveAsync - Save Journal in background
  
  func saveAsync(callback: ((Bool, Error?) -> Void)?) {
    
    // TODO: Complex algorithm to ensure that all the attached Moments have been saved.
    self.saveInBackground(block: callback)
  }
  
  
  // Functions for managing associated FoodieMoments
  
  // FUNCTION add - Add Moment to Journal. If no position specified, add to end of array
  
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
  
  
  // FUNCTION move - Move Moment to specified position in Moment array. Return failure if moving past end of array
  // Other Moments in the array might have their position altered accordingly
  // Controller layer should query to confirm how other Moments might have their orders and positions changed
  
  func move(moment: FoodieMoment,
            to position: Int) {
    
  }
  
  
  // FUNCTION delete - Delete specified Moment
  // Other Moments in the array might have their position altered accordingly
  // Controller layer should query to confirm how other Moments might have their orders and positions changed
  
  func delete(moment: FoodieMoment) {
    
  }
}


extension FoodieJournal: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieJournal"
  }
}
