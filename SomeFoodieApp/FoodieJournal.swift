//
//  FoodieJournal.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
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
  
  
  // MARK: - Private Static Variable
  private static var currentJournal: FoodieJournal?
  
  
  // MARK: - Internal Static Functions
  
  // Return the current FoodieJournal that is under addition/edit
  static func current() -> FoodieJournal? {
    return currentJournal
  }
  
  // Create a new FoodieJournal as the current Journal. Save or discard the previous current Journal
  static func new(saveCurrent: Bool, errorCallback: ((Bool, Error?) -> Void)?)  -> FoodieJournal? {
    if saveCurrent {
      guard let callback = errorCallback else {
        print("DEBUG_ERROR: Expected non-nil errorCallback function")
        return nil
      }
      self.saveCurrent(errorCallback: callback)
    }
    return FoodieJournal()
  }
  
  // Save the current Journal
  static func saveCurrent(errorCallback: ((Bool, Error?) -> Void)?) {
    // TODO: Gotta save all related media/objects/files first, etc
    currentJournal?.saveInBackground()  // Block the user from proceeding further in the app until all the saves comes back
  }
}


extension FoodieJournal: PFSubclassing {
  static func parseClassName() -> String {
    return "foodieJournal"
  }
}
