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

  // Location Information
  @NSManaged var streetAddress: String?
  @NSManaged var crossStreet: String?
  @NSManaged var city: String?
  @NSManaged var state: String?
  @NSManaged var postalCode: String?
  @NSManaged var country: String?
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
  typealias VenueErrorBlock = ([FoodieVenue]?, Geocode?, Error?) -> Void

  // Struct based on https://developer.foursquare.com/docs/responses/geocode
  struct Geocode {
    var cc: String?
    var center: CLLocation?
    var ne: CLLocationCoordinate2D?
    var sw: CLLocationCoordinate2D?
    var name: String?
    var displayName: String?
  }
  
  
  // MARK: - Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case searchFoursquareBothNearAndLocation
    case searchFoursquareHttpStatusNil
    case searchFoursquareHttpStatusFailed
    case searchFoursquareResponseError
    case searchFoursquareFailedGeocode
    
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
      case .searchFoursquareFailedGeocode:
        return NSLocalizedString("Cannot find specified location", comment: "Error description for an exception error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      DebugPrint.error(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Private Constants
  private struct Constants {
    static let FoursquareSearchResultsLimit = 20  // 20 Venues at a time is more than enough?
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
      callback?(nil, nil, ErrorCode.searchFoursquareBothNearAndLocation)
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
        
        guard let statusCode = result.HTTPSTatusCode, let httpStatusCode = HTTPStatusCode(rawValue: statusCode) else {
          DebugPrint.assert("No valid HTTP Status Code on Foursquare Search")
          callback?(nil, nil, ErrorCode.searchFoursquareHttpStatusNil)
          return
        }
        
        switch httpStatusCode {
        
        case .ok:
          break
          
        case .badRequest:
          if let error = result.error, let errorType = error.userInfo["errorType"] as? String {
            if errorType == "failed_geocode" {
              DebugPrint.userError("User inputted a location to perform Foursquare Venue search 'Near', but the Geocode was not found")
              callback?(nil, nil, ErrorCode.searchFoursquareFailedGeocode)
              break
            }
          }
          fallthrough
          
        default:
          if foursquareErrorLogging(for: httpStatusCode) {
            callback?(nil, nil, ErrorCode.searchFoursquareHttpStatusFailed)
          } else {
            DebugPrint.error("Search for Foursquare Venue responded with HTTP status code \(httpStatusCode) - \(result.description)")
            if !searchRetry.attemptRetryBasedOnHttpStatus(httpStatus: httpStatusCode,
                                                          after: Constants.FoursquareSearchRetryDelay,
                                                          withQoS: .userInteractive) {
              callback?(nil, nil, ErrorCode.searchFoursquareHttpStatusFailed)
            }
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
              callback?(nil, nil, ErrorCode.searchFoursquareResponseError)
            }
            return
          } else {
            callback?(nil, nil, ErrorCode.searchFoursquareResponseError)
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
              
              // Get the rest of the address. Might not always be populated?
              if let address = location["address"] as? String {
                foodieVenue.streetAddress = address
              }
              
              if let crossStreet = location["crossStreet"] as? String {
                foodieVenue.crossStreet = crossStreet
              }
              
              if let city = location["city"] as? String {
                foodieVenue.city = city
              }
              
              if let state = location["state"] as? String {
                foodieVenue.state = state
              }
              
              if let postalCode = location["postalCode"] as? String {
                foodieVenue.postalCode = postalCode
              }
              
              if let country = location["country"] as? String {
                foodieVenue.country = country
              }
              
              // Category, URL, Price and Hour information is not necassary at this point. Defer to only when the user actually do want this Venue
              responseVenueArray.append(foodieVenue)
            }
            
            // Grab the Geocode if there is one
            var geocodeStruct: Geocode!
            
            if let geocode = response["geocode"] as? [String : AnyObject] {
              geocodeStruct = Geocode()
              if let feature = geocode["feature"] as? [String: AnyObject] {
              
                if let cc = feature["cc"] as? String {
                  geocodeStruct.cc = cc
                }
                
                if let center = feature["center"] as? [String : AnyObject],
                   let latString = center["lat"] as? String,
                   let lngString = center["lng"] as? String,
                   let latitude = Double(latString),
                   let longitude = Double(lngString) {
                  geocodeStruct.center = CLLocation(latitude: latitude, longitude: longitude)
                }
                
                if let bounds = feature["bounds"] as? [String : AnyObject],
                   let ne = bounds["ne"] as? [String : AnyObject],
                   let sw = bounds["sw"] as? [String : AnyObject],
                   let neLatString = ne["lat"] as? String,
                   let neLngString = ne["lng"] as? String,
                   let swLatString = sw["lat"] as? String,
                   let swLngString = sw["lng"] as? String,
                   let neLat = Double(neLatString),
                   let neLng = Double(neLngString),
                   let swLat = Double(swLatString),
                   let swLng = Double(swLngString) {
                  geocodeStruct.ne = CLLocationCoordinate2D(latitude: neLat, longitude: neLng)
                  geocodeStruct.sw = CLLocationCoordinate2D(latitude: swLat, longitude: swLng)
                }
                
                if let name = feature["name"] as? String {
                  geocodeStruct.name = name
                }
                
                if let displayName = feature["displayName"] as? String {
                  geocodeStruct.displayName = displayName
                }
              }
            }
            
            // Return all the collected venues through the callback!
            callback?(responseVenueArray, geocodeStruct, nil)
            //}
          }
        }
      }
      searchTask.start()
    }
  }
  
  // Return true if the error should result in callback & return, false otherwise to fallthrough
  private static func foursquareErrorLogging(for httpStatusCode: HTTPStatusCode) -> Bool {
    // Handling here is loosely based on the description in https://developer.foursquare.com/overview/responses
    
    switch httpStatusCode {
      
    case .unauthorized:
      DebugPrint.error("Foursquare HTTP error: Unauthorized - The OAuth token was provided but was invalid")
      return true
    
    case .forbidden:
      DebugPrint.error("Foursquare HTTP error: Forbidden - The requested information cannot be viewed by the acting user, for example, because they are not friends with the user whose data they are trying to read")
      return true
      
    case .notFound:
      DebugPrint.error("Foursquare HTTP error: Not Found - Endpoint does not exist")
      return true
    
    case .methodNotAllowed:
      DebugPrint.error("Foursquare HTTP error: Method Not Allowed - Attempting to use POST with a GET-only endpoint, or vice-versa")
      return true
      
    case .conflict:
      DebugPrint.error("Foursquare HTTP error: Conflict - The request could not be completed as it is. Use the information included in the response to modify the request and retry")
      return true

    default:
      return false
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
