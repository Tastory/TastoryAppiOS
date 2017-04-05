//
//  FoodieMoment.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-31.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//


import Parse

class FoodieMoment: FoodieObject {
  
  @NSManaged var media: PFFile?  // A Photo or a Video
  @NSManaged var mediaType: Int  // Really an enum saying whether it's a Photo or Video
  @NSManaged var aspectRatio: Double  // In decimal, width / height, like 16:9 = 16/9 = 1.777...
  @NSManaged var width: Int  // height = width / aspectRatio
  @NSManaged var markup: Array<PFObject>?  // Array of PFObjects as FoodieMarkup
  @NSManaged var tags: Array<String>?  // Array of Strings, unstructured
  @NSManaged var author: PFUser?  // Pointer to the user that authored this Moment
  @NSManaged var eatery: PFObject?  // Pointer to the FoodieEatery object
  @NSManaged var categories: Array<Int>?  // Array of internal restaurant categoryIDs (all cateogires that applies, sub or primary)
  @NSManaged var type: Int  // Really an enum saying whether this describes the dish, interior, or exterior, Optional
  @NSManaged var attribute: String?  // Attribute related to the type. Eg. Dish name, Optional
  @NSManaged var views: Int  // How many times have this Moment been viewed
  @NSManaged var clickthroughs: Int  // How many times have this been clicked through to the next
  
  // Date created vs Date updated is given for free
  
  struct GlobalConstants {
    static let jpegCompressionQuality: CGFloat = 0.8
  }
  
  enum mediaType: Int {
    case photo = 1
    case video = 2
  }
}

 
extension FoodieMoment: PFSubclassing {
  static func parseClassName() -> String {
    return "foodieMoment"
  }
}
