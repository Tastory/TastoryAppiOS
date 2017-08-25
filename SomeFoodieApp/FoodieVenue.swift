//
//  FoodieVenue.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//


import Parse
import QuadratTouch
import HTTPStatusCodes


class FoodieVenue: FoodiePFObject  {
  
  // For now, we shall track all information that we might want to be able to filter on.
  // All additional information just for displaying to the user will be through a direct Foursquare query
  
  @NSManaged var name: String?
  @NSManaged var foursquareVenueID: String?
  @NSManaged var foursquareCategoryIDs: Array<String>?  // Arrange so that best matching highest level is closest to index 0?
  @NSManaged var venueURL: String?
  @NSManaged var geoLocation: PFGeoPoint?  // Geolocation of the Journal entry

  // Hour Information (Machine Readable only)  // For human readable string, query Foursquare
  @NSManaged var openingHours: [Int: Int]?  // Array of opening times indexed by day of the week. Comparison only. Do not do regular arithmetic on these because 0059 + 1 needs to become 0100
  @NSManaged var closingHours: [Int: Int]?  // Array of closing times indexed by day of the week. Next day would be 24+whenever in might be
  
//  @NSManaged var mondayOpen: Int // Open time in minutes
//  @NSManaged var mondayClose: Int // Close time in minutes. Next day would be 24+whenever it might be
//  @NSManaged var tuesdayOpen: Int
//  @NSManaged var tuesdayClose: Int
//  @NSManaged var wednesdayOpen: Int
//  @NSManaged var wednesdayClose: Int
//  @NSManaged var thursdayOpen: Int
//  @NSManaged var thursdayClose: Int
//  @NSManaged var fridayOpen: Int
//  @NSManaged var fridayClose: Int
//  @NSManaged var saturdayOpen: Int
//  @NSManaged var saturdayClose: Int
//  @NSManaged var sundayOpen: Int
//  @NSManaged var sundayClose: Int
  
  // Price Information
  @NSManaged var priceTier: Double  // Average meal spending
  @NSManaged var averagePrice: Double  // Placeholder: In currency as represented by currencyCode
  @NSManaged var currencySymbol: String? // Placeholder
  @NSManaged var currencyCode: String?  // Placeholder: Currency type by ISO 4217 code
  
  // For everything else, for now, query Foursquare
  
  // Analytics
  @NSManaged var venueViewed: Int
  @NSManaged var journalsViewed: Int
  @NSManaged var momentsViewed: Int
  @NSManaged var venueURLViewed: Int
  @NSManaged var venueRating: Double  // Placeholder
  
  
  // MARK: - Types & Enumerations
  typealias VenueErrorBlock = ([FoodieVenue]?, Error?) -> Void

  
  
  // MARK: - Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case searchFoursquareBothNearAndLocation
    case searchFoursquareHttpStatusNil
    case searchFoursquareHttpStatusFailed
    case searchFoursquareResponseError
    
    var errorDescription: String? {
      switch self {
      case .searchFoursquareBothNearAndLocation:
        return NSLocalizedString("Both near & location nil or both not nil in Foursquare search common", comment: "Error description for an exception error code")
      case .searchFoursquareHttpStatusNil:
        return NSLocalizedString("HTTP Status came back nil upon Foursquare search", comment: "Error description for an exception error code")
      case .searchFoursquareHttpStatusFailed:
        return NSLocalizedString("HTTP Status failure upon Foursquare search", comment: "Error description for an exception error code")
      case .searchFoursquareResponseError:
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
    static let FoursquareSearchResultsLimit = 50
    static let FoursquareSearchRetryCount = 5  // More retries, shorter delay
    static let FoursquareSearchRetryDelay = 1.0
  }
  
  
  // MARK: - Public Static Functions
  static func searchFoursquare(for venueName: String, near location: String, withBlock callback: VenueErrorBlock?) {
    searchFoursquareCommon(for: venueName, near: location, withBlock: callback)
  }
  
  static func searchFoursquare(for venueName: String, at location: CLLocation, withBlock callback: VenueErrorBlock?) {
    searchFoursquareCommon(for: venueName, at: location, withBlock: callback)
  }
  
  
  // MARK: - Private Static Functions
  
  // Search Foursquare and return list of matching Compact responses
  private static func searchFoursquareCommon(for venueName: String, near area: String? = nil, at point: CLLocation? = nil, withBlock callback: VenueErrorBlock?) {
    
    if (area != nil && point != nil) || (area == nil && point == nil) {
      callback?(nil, ErrorCode.searchFoursquareBothNearAndLocation)
      DebugPrint.assert("Either both Near & Location are nil, or both are not-nil. This is theoretically impossible.")
    }
    
    let session = FoodieGlobal.foursquareSession
    var parameters = [Parameter.query:venueName]
    parameters += [Parameter.limit: String(Constants.FoursquareSearchResultsLimit)]
    parameters += [Parameter.intent:"checkin"]
    
    if let point = point {
      parameters += point.foursquareParameters()
    }
    
    if let area = area {
      parameters += [Parameter.near: area]
    }
    
    let searchRetry = SwiftRetry()
    searchRetry.start("search Foursquare for \(venueName)", withCountOf: Constants.FoursquareSearchRetryCount) {
      // Perform Foursquare search with async response handling in block
      let searchTask = session.venues.search(parameters) { (result) in
        
        guard let httpStatusCode = result.HTTPSTatusCode else {
          DebugPrint.assert("No valid HTTP Status Code on Foursquare Search")
          callback?(nil, ErrorCode.searchFoursquareHttpStatusNil)
          return
        }
        
        if httpStatusCode != HTTPStatusCode.ok.rawValue {
          DebugPrint.error("Search for Foursquare Venue responded with HTTP status code \(httpStatusCode) - \(result.description)")
          if !searchRetry.attemptRetryBasedOnHttpStatus(code: httpStatusCode,
                                                        after: Constants.FoursquareSearchRetryDelay,
                                                        withQoS: .userInteractive) {
            callback?(nil, ErrorCode.searchFoursquareHttpStatusFailed)
          }
          return
        }
        
        // TODO: - Consider CocoaErrorDomain and QuadratResponseErrorDomain error parsing
        if let error = result.error {
          DebugPrint.error("Search For Foursquare Venue responded with error \(error.localizedDescription) - \(result.description)")
          if error.domain == NSURLErrorDomain, let urlError = error as? URLError {
            if !searchRetry.attemptRetryBasedOnURLError(urlError,
                                                        after: Constants.FoursquareSearchRetryDelay,
                                                        withQoS: .userInteractive) {
              callback?(nil, ErrorCode.searchFoursquareResponseError)
            }
            return
          } else {
            callback?(nil, ErrorCode.searchFoursquareResponseError)
            return
          }
        }
        
        if let response = result.response {
          if let venues = response["venues"] as? [[String: AnyObject]] {
            //autoreleasepool {
            var responseVenueArray = [FoodieVenue]()
            
            for venue: [String: AnyObject] in venues {
              
              // From Foursquare Developer's documentation, it is possible to not have anything but a name. Keep that in mind
              let foodieVenue = FoodieVenue(withState: .objectModified)
              
              guard let id = venue["id"] as? String else {
                if let name = venue["name"] as? String {
                  DebugPrint.log("Invalid Foursquare entry with no ID but Name: \(name))")
                } else {
                  DebugPrint.log ("Invalid Foursquare entry with no ID nor Name")
                }
                continue
              }
              
              guard let name = venue["name"] as? String else {
                DebugPrint.log("Invalid Foursquare entry with no Name but ID: \(id)")
                continue
              }
              
              guard let location = venue["location"] as? [String: AnyObject] else {
                DebugPrint.log("Invalid Foursquare entry with no Location information. ID: \(id), Name: \(name)")
                continue
              }
              
              guard let latitude = location["lat"] as? Float else {
                DebugPrint.log("Invalid Foursquare entry with no Latitude information. ID: \(id), Name: \(name)")
                continue
              }
              
              guard let longitude = location["lng"] as? Float else {
                DebugPrint.log("Invalid Foursquare entry with no Longitude information. ID: \(id), Name: \(name)")
                continue
              }
              
              foodieVenue.name = name
              foodieVenue.foursquareVenueID = id
              foodieVenue.geoLocation = PFGeoPoint(latitude: Double(latitude), longitude: Double(longitude))
              
              // Category, URL, Price and Hour information is not necassary at this point. Defer to only when the user actually do want this Venue
              responseVenueArray.append(foodieVenue)
            }
            
            // Return all the collected venues through the callback!
            callback?(responseVenueArray, nil)
            //}
          }
        }
      }
      searchTask.start()
    }
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
}


// MARK: - Foodie Object Delegate Conformance
extension FoodieVenue: FoodieObjectDelegate {
  
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
    return "FoodieVenue"
  }
}


extension FoodieVenue: PFSubclassing {
  static func parseClassName() -> String {
    return "FoodieVenue"
  }
}


// MARK: - Parameterization of Core Location
extension CLLocation
{
  func foursquareParameters() -> Parameters
  {
    let ll      = "\(self.coordinate.latitude),\(self.coordinate.longitude)"
    let llAcc   = "\(self.horizontalAccuracy)"
    let alt     = "\(self.altitude)"
    let altAcc  = "\(self.verticalAccuracy)"
    let parameters = [
      Parameter.ll:ll,
      Parameter.llAcc:llAcc,
      Parameter.alt:alt,
      Parameter.altAcc:altAcc
    ]
    return parameters
  }
}
