//
//  FoodieEatery.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//


import Parse

class FoodieEatery: PFObject {
  
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
}


extension FoodieEatery: PFSubclassing {
  static func parseClassName() -> String {
    return "foodieEatery"
  }
}
