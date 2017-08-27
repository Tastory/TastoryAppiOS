//
//  FoodieCategory.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
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

  
  // MARK: - Types & Enumeration
  typealias CategoriesErrorBlock = ([FoodieCategory]?, Error?) -> Void
  
  
  // MARK: - Error Types Definition
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
      DebugPrint.error(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Private Constants
  private struct Constants {
    //static let FoursquareSearchResultsLimit = 50
    static let FoursquareSearchRetryCount = 10  // More retries, shorter delay
    static let FoursquareSearchRetryDelay = 2.0
  }
  
  
  // MARK: - Private Static Varaibles
  private static var protectedList = [String: FoodieCategory]()
  private static var protectedTree = [String: FoodieCategory]()
  
  
  // MARK: - Public Static Variables
  static var list: [String: FoodieCategory] { return protectedList }
  static var tree: [String: FoodieCategory] { return protectedTree }
  
  
  // MARK: - Public Instance Variables
  var subcategories: [FoodieCategory]?
  
  
  // MARK: - Public Static Functions
  static func getFromFoursquare(withBlock callback: CategoriesErrorBlock?) {
    let session = FoodieGlobal.foursquareSession
    
    let categoriesRetry = SwiftRetry()
    categoriesRetry.start("get Categories from Foursquare", withCountOf: Constants.FoursquareSearchRetryCount) {
      // Get Foursquare Categories with async response handling in block
      let categoriesTask = session.venues.categories { (result) in
        
        guard let statusCode = result.HTTPSTatusCode, let httpStatusCode = HTTPStatusCode(rawValue: statusCode) else {
          DebugPrint.error("No valid HTTP Status Code on Foursquare Search")
          callback?(nil, ErrorCode.foursquareHttpStatusNil)
          return
        }
        
        if httpStatusCode != HTTPStatusCode.ok {
          DebugPrint.error("Search for Foursquare Venue responded with HTTP status code \(httpStatusCode) - \(result.description)")
          if !categoriesRetry.attemptRetryBasedOnHttpStatus(httpStatus: httpStatusCode,
                                                            after: Constants.FoursquareSearchRetryDelay,
                                                            withQoS: .userInteractive) {
            callback?(nil, ErrorCode.foursquareHttpStatusFailed)
          }
          return
        }
        
        // TODO: - Consider CocoaErrorDomain and QuadratResponseErrorDomain error parsing
        if let error = result.error {
          DebugPrint.error("Search For Foursquare Venue responded with error \(error.localizedDescription) - \(result.description)")
          if error.domain == NSURLErrorDomain, let urlError = error as? URLError {
            if !categoriesRetry.attemptRetryBasedOnURLError(urlError,
                                                            after: Constants.FoursquareSearchRetryDelay,
                                                            withQoS: .userInteractive) {
              callback?(nil, ErrorCode.foursquareResponseError)
            }
            return
          } else {
            callback?(nil, ErrorCode.foursquareResponseError)
            return
          }
        }
        
        // Let the list and tree start anew
        protectedList.removeAll(keepingCapacity: true)
        protectedTree.removeAll(keepingCapacity: true)
        
        if let categoryArray = result.response?["categories"] as? [[String: Any]] {
          for category in categoryArray {
            if let foodieCategory = convertRecursive(from: category) {
              protectedTree[foodieCategory.foursquareCategoryID!] = foodieCategory
            }
          }
        }
      }
      categoriesTask.start()
    }
  }
  
  
  // MARK: - Private Static Functions
  private static func convertRecursive(from dictionary: [String : Any]) -> FoodieCategory? {
    let foodieCategory = FoodieCategory()
    guard let id = dictionary["id"] as? String else {
      DebugPrint.assert("Received dictionary with no ID")
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
    
    // Append self to static list first. It's by reference anyways so it's fine.
    protectedList[id] = foodieCategory
    
    if let categories = dictionary["categories"] as? [[String : Any]] {
      foodieCategory.subcategories = [FoodieCategory]()
      foodieCategory.subcategoryIDs = [String]()
      
      for category in categories {
        if let childCategory = convertRecursive(from: category) {
          foodieCategory.subcategoryIDs?.append(childCategory.foursquareCategoryID!)  // Force unwrap because you know a freshly converted Category will have ID for sure
          foodieCategory.subcategories?.append(childCategory)
        }
      }
    }
    
    return foodieCategory
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


  // MARK: - Foodie Object Delegate Conformance

  // Trigger recursive retrieve, with the retrieve of self first, then the recursive retrieve of the children
  func retrieveRecursive(forceAnyways: Bool = false, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    // Retrieve self. This object have no children
    retrieve(forceAnyways: forceAnyways, withBlock: callback)
  }
  
  
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
  
  // Trigger recursive delete against all child objects.
  func deleteRecursive(withName name: String? = nil,
                       withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    DebugPrint.verbose("FoodieJournal.deleteRecursive \(getUniqueIdentifier())")
    
    // Delete itself first
    foodieObject.deleteObjectLocalNServer(withName: name, withBlock: callback)
  }
  
  func verbose() {
    
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
