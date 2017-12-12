//
//  FoodieCategory.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 Tastry. All rights reserved.
//


import Parse
import QuadratTouch
import HTTPStatusCodes


class FoodieCategory: FoodiePFObject, FoodieObjectDelegate {
  
  @NSManaged var foursquareCategoryID: String?
  @NSManaged var name: String?
  @NSManaged var pluralName: String?
  @NSManaged var shortName: String?
  @NSManaged var iconPrefix: String?
  @NSManaged var iconSuffix: String?
  @NSManaged var subcategoryIDs: Array<String>?

  
  // MARK: - Public Instance Variables
  var parentCategory: FoodieCategory?
  var subcategories: [FoodieCategory]?
  var substitudedCategoryIDs: Array<String>?
  var catLevel: Int = 0
  var selected: SelectionState = .unselected
  
  
  // MARK: - Types & Enumeration
  typealias CategoriesErrorBlock = ([FoodieCategory]?, Error?) -> Void
  
  
  enum SelectionState {
    case selected
    case partial
    case unselected
  }
  

  
  // MARK: - Error Types
  enum ErrorCode: LocalizedError {
    
    case searchFoursquareBothNearAndLocation
    case foursquareHttpStatusNil
    case foursquareHttpStatusFailed
    case foursquareResponseError
    
    var errorDescription: String? {
      switch self {
      case .searchFoursquareBothNearAndLocation:
        return NSLocalizedString("Both near & location nil or both not nil in Foursquare search common", comment: "Error description for an exception error code")
      case .foursquareHttpStatusNil:
        return NSLocalizedString("HTTP Status came back nil upon Foursquare search", comment: "Error description for an exception error code")
      case .foursquareHttpStatusFailed:
        return NSLocalizedString("HTTP Status failure upon Foursquare search", comment: "Error description for an exception error code")
      case .foursquareResponseError:
        return NSLocalizedString("General response error upon Foursquare search", comment: "Error description for an exception error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Private Constants
  private struct Constants {
    //static let FoursquareSearchResultsLimit = 50
    static let FoursquareSearchRetryCount = 10  // More retries, shorter delay
    static let FoursquareSearchRetryDelay = 2.0
    static let NonOthersFoursquareCategories = ["4d4b7105d754a06374d81259" /* Food */, "4d4b7105d754a06376d81259" /* Nightlife Spot */]
  }
  
  
  // MARK: - Read-Only Static Varaibles
  private(set) static var list = [String: FoodieCategory]()
  private(set) static var tree = [FoodieCategory]()
  
  
  // MARK: - Public Static Variables
  static var otherCategoryID: String = ""

  
  // MARK: - Public Static Functions
  static func getFromFoursquare(withBlock callback: CategoriesErrorBlock?) {
    let session = FoodieVenue.foursquareSession
    
    let categoriesRetry = SwiftRetry()
    categoriesRetry.start("get Categories from Foursquare", withCountOf: Constants.FoursquareSearchRetryCount) {
      // Get Foursquare Categories with async response handling in block
      let categoriesTask = session.venues.categories { result in
        
        guard let statusCode = result.HTTPSTatusCode, let httpStatusCode = HTTPStatusCode(rawValue: statusCode) else {
          CCLog.warning("No valid HTTP Status Code on Foursquare Search")
          callback?(nil, ErrorCode.foursquareHttpStatusNil)
          categoriesRetry.done()
          return
        }
        
        if httpStatusCode != HTTPStatusCode.ok {
          CCLog.warning("Search for Foursquare Venue responded with HTTP status code \(httpStatusCode) - \(result.description)")
          if !categoriesRetry.attemptRetryBasedOnHttpStatus(httpStatus: httpStatusCode,
                                                            after: Constants.FoursquareSearchRetryDelay,
                                                            withQoS: .utility) {
            callback?(nil, ErrorCode.foursquareHttpStatusFailed)
            categoriesRetry.done()
          }
          return
        }
        
        // TODO: - Consider CocoaErrorDomain and QuadratResponseErrorDomain error parsing
        if let error = result.error {
          CCLog.warning("Search For Foursquare Venue responded with error \(error.localizedDescription) - \(result.description)")
          if error.domain == NSURLErrorDomain, let urlError = error as? URLError {
            if !categoriesRetry.attemptRetryBasedOnURLError(urlError,
                                                            after: Constants.FoursquareSearchRetryDelay,
                                                            withQoS: .utility) {
              callback?(nil, ErrorCode.foursquareResponseError)
              categoriesRetry.done()
            }
            return
          } else {
            callback?(nil, ErrorCode.foursquareResponseError)
            categoriesRetry.done()
            return
          }
        }
        
        // Let the list and tree start anew
        list.removeAll(keepingCapacity: true)
        tree.removeAll(keepingCapacity: true)
        
        if let categoryArray = result.response?["categories"] as? [[String: Any]] {
          
          // Create a 'Others' category
          otherCategoryID = UUID().uuidString  // It doesn't matter that a new one is generated each time, as long as it's the same everytime
          let others = FoodieCategory()
          others.foursquareCategoryID = otherCategoryID
          others.name = "Other"
          others.pluralName = "Others"
          others.shortName = "Other"
          others.iconPrefix = nil  // TODO: ??
          others.iconSuffix = nil
          others.catLevel = 1
          others.substitudedCategoryIDs = [String]()
          
          for category in categoryArray {
            
            // Unfortunately we need the id first
            guard let id = category["id"] as? String else {
              CCLog.assert("Received dictionary with no ID")
              break
            }
            
            // Food & Nightlife goes through the regular processing
            if Constants.NonOthersFoursquareCategories.contains(id) {
              if let foodieCategory = convertRecursive(from: category, forLevel: 1) {
                tree.append(foodieCategory)
              }
            }
            
            // All other categories just becomes Others
            else {
              others.substitudedCategoryIDs!.append(id)
            }
          }
          
          // Append the Others category
          tree.append(others)
          list[otherCategoryID] = others
        }
      }
      categoriesTask.start()
    }
  }
  
  
  // MARK: - Private Static Functions
  private static func convertRecursive(from dictionary: [String : Any], forLevel level: Int) -> FoodieCategory? {
    let foodieCategory = FoodieCategory()
    guard let id = dictionary["id"] as? String else {
      CCLog.assert("Received dictionary with no ID")
      return nil
    }
    foodieCategory.foursquareCategoryID = id
    
    if let name = dictionary["name"] as? String {
      foodieCategory.name = name
    }
    
    if let pluralName = dictionary["pluralName"] as? String {
      foodieCategory.pluralName = pluralName
    }
    
    if let shortName = dictionary["shortName"] as? String {
      foodieCategory.shortName = shortName
    }
    
    if let icon = dictionary["icon"] as? [String : Any] {
      if let prefix = icon["prefix"] as? String {
        foodieCategory.iconPrefix = prefix
      }
      if let suffix = icon["suffix"] as? String {
        foodieCategory.iconSuffix = suffix
      }
    }
    
    foodieCategory.catLevel = level
    
    // Must append in here, cuz if you are not top level there's no other place
    list[id] = foodieCategory
    
    if let categories = dictionary["categories"] as? [[String : Any]] {
      foodieCategory.subcategories = [FoodieCategory]()
      foodieCategory.subcategoryIDs = [String]()
      
      for category in categories {
        if let childCategory = convertRecursive(from: category, forLevel: level+1) {
          foodieCategory.subcategoryIDs?.append(childCategory.foursquareCategoryID!)  // Force unwrap because you know a freshly converted Category will have ID for sure
          foodieCategory.subcategories?.append(childCategory)
          childCategory.parentCategory = foodieCategory
        }
      }
    }
    
    return foodieCategory
  }
  
  
  static func setAllSelection(to selectionState: SelectionState) {
    for category in list {
      category.value.selected = selectionState
    }
  }
  
  
  
  // MARK: - Public Instance Functions
  
  override init() {
    super.init()
    foodieObject.delegate = self
  }

  
  func setSelectionRecursive(to state: SelectionState) {
    selected = state
    selectionUpstreamRecursive(to: state)
    selectionDownstreamRecursive(to: state)
  }
  
  
  func selectionUpstreamRecursive(to state: SelectionState) {
    
    // Check Peer Selection States
    if let parentCategory = parentCategory {
      
      guard let subcategories = parentCategory.subcategories, subcategories.count > 0 else {
        CCLog.fatal("No subcategories on Upstream Recursive")
      }
      
      var allUnselected = true
      var allSelected = true
      
      for category in subcategories {
        switch category.selected {
        case .unselected:
          allSelected = false
        case .partial:
          allSelected = false
          allUnselected = false
        case .selected:
          allUnselected = false
        }
      }
      
      if allSelected, allUnselected {
        CCLog.fatal("Cannot be all Selected and all Unselected at the same time")
      } else if allSelected {
        parentCategory.selected = .selected
      } else if allUnselected {
        parentCategory.selected = .unselected
      } else {
        parentCategory.selected = .partial
      }
      
      parentCategory.selectionUpstreamRecursive(to: parentCategory.selected)
    }
  }
  
  
  func selectionDownstreamRecursive(to state: SelectionState) {
    if let subcategories = subcategories {
      for category in subcategories {
        category.selected = state
        category.selectionDownstreamRecursive(to: state)
      }
    }
  }
  
  
  // MARK: - Foodie Object Delegate Conformance

  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(from location: FoodieObject.StorageLocation,
                         type localType: FoodieObject.LocalType,
                         forceAnyways: Bool = false,
                         for parentOperation: AsyncOperation?,
                         withReady readyBlock: SimpleBlock? = nil,
                         withCompletion callback: SimpleErrorBlock?) -> AsyncOperation? {
    
    guard readyBlock == nil else {
      CCLog.fatal("FoodieCategory does not support Ready Responses")
    }
    
    // Retrieve self. This object have no children
    foodieObject.retrieveObject(from: location, type: localType, forceAnyways: forceAnyways, withBlock: callback)
    return nil
  }
  
  
  // Trigger recursive saves against all child objects. Save of the object itself will be triggered as part of childSaveCallback
  func saveRecursive(to location: FoodieObject.StorageLocation,
                     type localType: FoodieObject.LocalType,
                     for parentOperation: AsyncOperation?,
                     withBlock callback: SimpleErrorBlock?) {
    
    CCLog.assert("FoodieCategory.saveRecursive called, but not yet implemented!")
  }
  
  
  func saveWhole(to location: FoodieObject.StorageLocation,
                 type localType: FoodieObject.LocalType,
                 for parentOperation: AsyncOperation?,
                 withBlock callback: SimpleErrorBlock?) {
    
    CCLog.assert("FoodieCategory.saveWhole called, but not yet implemented!")
  }
  
  
  // Trigger recursive delete against all child objects.
  func deleteRecursive(from location: FoodieObject.StorageLocation,
                       type localType: FoodieObject.LocalType,
                       for parentOperation: AsyncOperation?,
                       withBlock callback: SimpleErrorBlock?) {

    // Delete self. This object have no children
    foodieObject.deleteObject(from: location, type: localType, withBlock: callback)
  }
  
  
  func cancelRetrieveFromServerRecursive() {
    // At this point, nothing can be cancelled for Markups
    return
  }
  
  
  func cancelSaveToServerRecursive() {
    // At this point, nothing can be cancelled for Markups
    return
  }
  
  
  func foodieObjectType() -> String {
    return "FoodieCategory"
  }
}


extension FoodieCategory: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieCategory"
  }
}
