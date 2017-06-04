//
//  FoodieEatery.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//


import Parse

class FoodieEatery: FoodiePFObject  {
  
  @NSManaged var name: String?
  @NSManaged var foursquareID: String?
  @NSManaged var foursquareCatID: String?
  @NSManaged var categories: Array<Int>? // Array of internal restaurant categoryIDs (all cateogires that applies, most accurate at index 0. Remove top levels if got sub already)
  @NSManaged var price: Double // Average meal spending? vs restaurant rating out of 5 stars
  @NSManaged var eateryURL: String?
  
  @NSManaged var location: PFGeoPoint? // Geolocation of the Journal entry
  @NSManaged var formattedAddress: String? // Formatted address
  @NSManaged var phoneNumber: String?
  
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
  
  @NSManaged var restuarnatViewed: Int
  @NSManaged var journalsViewed: Int
  @NSManaged var momentsViewed: Int
  @NSManaged var eateryRating: Double // TODO: Placeholder for later rev
  
  
  // MARK: - Public Instance Variable
  var foodieObject = FoodieObject()
  
  
  // MARK: - Public Instance Functions
  override init() {
    super.init()
    foodieObject.delegate = self
  }
}


// MARK: - Foodie Object Delegate Conformance
extension FoodieEatery: FoodieObjectDelegate {
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     withName name: String?,
                     withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
    
    if let earlySuccess = earlyReturnStatus.success {
      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
      return
    }
  }
  
  
  // Trigger recursive saves against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       withName name: String?,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
  }
  
  
  func verbose() {
    
  }
  
  
  func foodieObjectType() -> String {
    return "FoodieEatery"
  }
}


extension FoodieEatery: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieEatery"
  }
}
