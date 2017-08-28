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
  @NSManaged var foursquareURL: String?
  @NSManaged var venueURL: String?

  // Location Information
  @NSManaged var streetAddress: String?
  @NSManaged var crossStreet: String?
  @NSManaged var city: String?
  @NSManaged var state: String?
  @NSManaged var postalCode: String?
  @NSManaged var country: String?
  @NSManaged var location: PFGeoPoint?  // Geolocation of the Journal entry

  // Hour Information (Machine Readable only)  // For human readable string, query Foursquare
  @NSManaged var hours: Array<Array<NSDictionary>>?  // Array of hours indexed by day of the week. Each day is an array of Dictionary, where key is either open, or close with an Int value.
                                       // Int value for comparison only. Do not do regular arithmetic on these because 0059 + 1 needs to become 0100
  // Price Information
  @NSManaged var priceTier: Int  // Average meal spending
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
  typealias VenueErrorBlock = (FoodieVenue?, Error?) -> Void
  typealias VenueArrayErrorBlock = ([FoodieVenue]?, Geocode?, Error?) -> Void
  typealias HoursErrorBlock = ([[[String:Int]]]?, Error?) -> Void
  
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
    case foursquareHttpStatusNil
    case foursquareHttpStatusFailed
    case foursquareResponseError
    case searchFoursquareFailedGeocode
    case invalidFoodieVenueObject
    
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
      case .searchFoursquareFailedGeocode:
        return NSLocalizedString("Cannot find specified location", comment: "Error description for an exception error code")
      case .invalidFoodieVenueObject:
        return NSLocalizedString("An invalid Foodie Venue Object was supplied", comment: "Error description for an exception error code")
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
    static let FoursquareGetDetailsRetryCount = 5  // More retries, shorter delay
    static let FoursquareGetDetailsRetryDelay = 1.0
  }
  
  
  // MARK: - Public Static Functions
  static func searchFoursquare(for venueName: String, near location: String, withBlock callback: VenueArrayErrorBlock?) {
    searchFoursquareCommon(for: venueName, near: location, withBlock: callback)
  }
  
  static func searchFoursquare(for venueName: String, at location: CLLocation, withBlock callback: VenueArrayErrorBlock?) {
    searchFoursquareCommon(for: venueName, at: location, withBlock: callback)
  }
  
  static func getDetailsFromFoursquare(forVenue venue: FoodieVenue, withBlock callback: VenueErrorBlock?) {
    guard let venueID = venue.foursquareVenueID else {
      callback?(nil, ErrorCode.invalidFoodieVenueObject)
      DebugPrint.assert("Invalid Foodie Venue Object supplied as input to function")
      return
    }
    getDetailsFromFoursquareCommon(for: venue, with: venueID, withBlock: callback)
  }
  
  static func getDetailsFromFoursquare(forVenueID venueID: String, withBlock callback: VenueErrorBlock?) {
    getDetailsFromFoursquareCommon(for: nil, with: venueID, withBlock: callback)
  }
  

  static func getHoursFromFoursquare(forVenue venue: FoodieVenue, withBlock callback: HoursErrorBlock?) {
    guard let venueID = venue.foursquareVenueID else {
      callback?(nil, ErrorCode.invalidFoodieVenueObject)
      DebugPrint.assert("Invalid Foodie Venue Object supplied as input to function")
      return
    }
    getHoursFromFoursquareCommon(for: venue, with: venueID, withBlock: callback)
  }
  
  static func getHoursFromFoursquare(forVenueID venueID: String, withBlock callback: HoursErrorBlock?) {
    getHoursFromFoursquareCommon(for: nil, with: venueID, withBlock: callback)
  }
  
  
  // MARK: - Private Static Functions
  
  // Search Foursquare and return list of matching Compact responses
  private static func searchFoursquareCommon(for venueName: String, near area: String? = nil, at point: CLLocation? = nil, withBlock callback: VenueArrayErrorBlock?) {
    
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
          callback?(nil, nil, ErrorCode.foursquareHttpStatusNil)
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
            callback?(nil, nil, ErrorCode.foursquareHttpStatusFailed)
          } else {
            DebugPrint.error("Search for Foursquare Venue responded with HTTP status code \(httpStatusCode) - \(result.description)")
            if !searchRetry.attemptRetryBasedOnHttpStatus(httpStatus: httpStatusCode,
                                                          after: Constants.FoursquareSearchRetryDelay,
                                                          withQoS: .userInteractive) {
              callback?(nil, nil, ErrorCode.foursquareHttpStatusFailed)
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
              callback?(nil, nil, ErrorCode.foursquareResponseError)
            }
            return
          } else {
            callback?(nil, nil, ErrorCode.foursquareResponseError)
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
                  DebugPrint.log("Invalid Foursquare Venue with no ID but Name: \(name))")
                } else {
                  DebugPrint.log ("Invalid Foursquare Venue with no ID nor Name")
                }
                continue
              }
              
              guard let name = venue["name"] as? String else {
                DebugPrint.log("Invalid Foursquare Venue with no Name but ID: \(id)")
                continue
              }
              
              guard let location = venue["location"] as? [String: AnyObject] else {
                DebugPrint.log("Invalid Foursquare Venue with no Location information. ID: \(id), Name: \(name)")
                continue
              }
              
              guard let latitude = location["lat"] as? Float else {
                DebugPrint.log("Invalid Foursquare Venue with no Latitude information. ID: \(id), Name: \(name)")
                continue
              }
              
              guard let longitude = location["lng"] as? Float else {
                DebugPrint.log("Invalid Foursquare Venue with no Longitude information. ID: \(id), Name: \(name)")
                continue
              }
              
              foodieVenue.name = name
              foodieVenue.foursquareVenueID = id
              foodieVenue.location = PFGeoPoint(latitude: Double(latitude), longitude: Double(longitude))
              
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
  
  
  private static func getDetailsFromFoursquareCommon(for venue: FoodieVenue?, with venueID: String, withBlock callback: VenueErrorBlock?) {
    
    let session = FoodieGlobal.foursquareSession
    let getDetailsRetry = SwiftRetry()
    getDetailsRetry.start("get details from Foursquare for \(venueID)", withCountOf: Constants.FoursquareGetDetailsRetryCount) {
      // Perform Foursquare Venue Details get with async response handling in block
      let getDetailsTask = session.venues.get(venueID) { (result) in
        
        guard let statusCode = result.HTTPSTatusCode, let httpStatusCode = HTTPStatusCode(rawValue: statusCode) else {
          DebugPrint.assert("No valid HTTP Status Code on Foursquare Search")
          callback?(nil, ErrorCode.foursquareHttpStatusNil)
          return
        }
        
        switch httpStatusCode {
          
        case .ok:
          break
          
        default:
          if foursquareErrorLogging(for: httpStatusCode) {
            callback?(nil, ErrorCode.foursquareHttpStatusFailed)
          } else {
            DebugPrint.error("Get Details for Foursquare Venue responded with HTTP status code \(httpStatusCode) - \(result.description)")
            if !getDetailsRetry.attemptRetryBasedOnHttpStatus(httpStatus: httpStatusCode,
                                                              after: Constants.FoursquareGetDetailsRetryDelay,
                                                              withQoS: .userInteractive) {
              callback?(nil, ErrorCode.foursquareHttpStatusFailed)
            }
          }
          return
        }
        
        // TODO: - Consider CocoaErrorDomain and QuadratResponseErrorDomain error parsing
        if let error = result.error {
          DebugPrint.error("Get Details For Foursquare Venue responded with error \(error.localizedDescription) - \(result.description)")
          if error.domain == NSURLErrorDomain, let urlError = error as? URLError {
            if !getDetailsRetry.attemptRetryBasedOnURLError(urlError,
                                                            after: Constants.FoursquareGetDetailsRetryDelay,
                                                            withQoS: .userInteractive) {
              callback?(nil, ErrorCode.foursquareResponseError)
            }
            return
          } else {
            callback?(nil, ErrorCode.foursquareResponseError)
            return
          }
        }
        
        // Actual Response Venue Parsing Time
        if let response = result.response {
          if let foursquareVenue = response["venue"] as? [String: AnyObject] {
            
            let foodieVenue = venue ?? FoodieVenue()
            
            guard let id = foursquareVenue["id"] as? String else {
              if let name = foursquareVenue["name"] as? String {
                DebugPrint.log("Invalid Foursquare Venue with no ID but Name: \(name))")
              } else {
                DebugPrint.log ("Invalid Foursquare Venue with no ID nor Name")
              }
              return
            }
            
            guard let name = foursquareVenue["name"] as? String else {
              DebugPrint.log("Invalid Foursquare Venue with no Name but ID: \(id)")
              return
            }
            
            guard let location = foursquareVenue["location"] as? [String: AnyObject] else {
              DebugPrint.log("Invalid Foursquare Venue with no Location information. ID: \(id), Name: \(name)")
              return
            }
            
            guard let latitude = location["lat"] as? Float else {
              DebugPrint.log("Invalid Foursquare Venue with no Latitude information. ID: \(id), Name: \(name)")
              return
            }
            
            guard let longitude = location["lng"] as? Float else {
              DebugPrint.log("Invalid Foursquare Venue with no Longitude information. ID: \(id), Name: \(name)")
              return
            }
            
            foodieVenue.name = name
            foodieVenue.foursquareVenueID = id
            foodieVenue.location = PFGeoPoint(latitude: Double(latitude), longitude: Double(longitude))
            
            // Get the rest of the Venue Details. Might not always be populated?
            
            // Address Information
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
            
            // Category Information
            var foodieCategories: [String]?
            if let categories = foursquareVenue["categories"] as? [[String : AnyObject]] {
              foodieCategories = [String]()
              for category in categories {
                if let categoryID = category["id"] as? String {
                  if let primary = category["primary"] as? Bool, primary == true {
                    foodieCategories!.insert(categoryID, at: 0)
                  } else {
                    foodieCategories!.append(categoryID)
                  }
                }
              }
            }
            foodieVenue.foursquareCategoryIDs = foodieCategories
            
            // Venue URL
            if let url = foursquareVenue["url"] as? String {
              foodieVenue.venueURL = url
            }
            
            // Hours Information to be obtained in a subsequent call!
            
            // Price
            if let price = foursquareVenue["price"] as? [String : AnyObject], let tier = price["tier"] as? Int {
              foodieVenue.priceTier = tier
            }
            
            // Foursquare URL
            if let canonicalUrl = foursquareVenue["canonicalUrl"] as? String {
              foodieVenue.foursquareURL = canonicalUrl
            }
            
            // Return the Venue~
            callback?(foodieVenue, nil)
          }
        }
      }
      getDetailsTask.start()
    }
  }
  
  private static func getHoursFromFoursquareCommon(for venue: FoodieVenue?, with venueID: String, withBlock callback: HoursErrorBlock?) {
    
    let session = FoodieGlobal.foursquareSession
    let getHoursRetry = SwiftRetry()
    getHoursRetry.start("get details from Foursquare for \(venueID)", withCountOf: Constants.FoursquareGetDetailsRetryCount) {
      // Perform Foursquare Venue Details get with async response handling in block
      let getHoursTask = session.venues.hours(venueID) { (result) in
        
        var hourSegmentsByDay: [[[String:Int]]]?
        
        guard let statusCode = result.HTTPSTatusCode, let httpStatusCode = HTTPStatusCode(rawValue: statusCode) else {
          DebugPrint.assert("No valid HTTP Status Code on Foursquare Search")
          callback?(nil, ErrorCode.foursquareHttpStatusNil)
          return
        }
        
        switch httpStatusCode {
          
        case .ok:
          break
          
        default:
          if foursquareErrorLogging(for: httpStatusCode) {
            callback?(nil, ErrorCode.foursquareHttpStatusFailed)
          } else {
            DebugPrint.error("Get Details for Foursquare Venue responded with HTTP status code \(httpStatusCode) - \(result.description)")
            if !getHoursRetry.attemptRetryBasedOnHttpStatus(httpStatus: httpStatusCode,
                                                            after: Constants.FoursquareGetDetailsRetryDelay,
                                                            withQoS: .userInteractive) {
              callback?(nil, ErrorCode.foursquareHttpStatusFailed)
            }
          }
          return
        }
        
        // TODO: - Consider CocoaErrorDomain and QuadratResponseErrorDomain error parsing
        if let error = result.error {
          DebugPrint.error("Get Details For Foursquare Venue responded with error \(error.localizedDescription) - \(result.description)")
          if error.domain == NSURLErrorDomain, let urlError = error as? URLError {
            if !getHoursRetry.attemptRetryBasedOnURLError(urlError,
                                                          after: Constants.FoursquareGetDetailsRetryDelay,
                                                          withQoS: .userInteractive) {
              callback?(nil, ErrorCode.foursquareResponseError)
            }
            return
          } else {
            callback?(nil, ErrorCode.foursquareResponseError)
            return
          }
        }
        
        // Parsing the Response for Hour Information
        if let response = result.response,
          let hours = response["hours"] as? [String : AnyObject],
          let timeframes = hours["timeframes"] as? [[String : AnyObject]] {
          
          hourSegmentsByDay = [[[String:Int]]]() // An Array of Array of Dictionary
          for _ in 1...7 {
            hourSegmentsByDay!.append([[String:Int]]())
          }
          
          for timeframe in timeframes {
            
            guard let days = timeframe["days"] as? [Int] else {
              break
            }
            
            guard let open = timeframe["open"] as? [[String : AnyObject]] else {
              break
            }
            
            var segment = [String:Int]()
            
            for openSegment in open {
              guard let start = openSegment["start"] as? String, let startInt = Int(start) else {
                break
              }
              segment["start"] = startInt
              
              guard var end = openSegment["end"] as? String else {
                break
              }
              
              // Foursquare represents next day with a '+' symbol in front...
              if end.characters[end.characters.startIndex] == "+" {
                let index = end.index(end.startIndex, offsetBy: 1)
                let endSubstring = end.substring(from: index)
                guard let endInt = Int(endSubstring) else {
                  break
                }
                segment["end"] = 2400 + endInt
              } else {
                guard let endInt = Int(end) else {
                  break
                }
                segment["end"] = endInt
              }
              
              // Add each timeframe to the corresponding day index in the FoodieVenue.hours property
              for day in days {
                hourSegmentsByDay![day-1].append(segment)
              }
            }
          }
        }
        venue?.hours = hourSegmentsByDay as Array<Array<NSDictionary>>?
        callback?(hourSegmentsByDay, nil)
      }
      getHoursTask.start()
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
  
  
  func getDetailsFromFoursquare(withBlock callback: VenueErrorBlock?) {
    if let venueID = foursquareVenueID {
      FoodieVenue.getDetailsFromFoursquareCommon(for: self, with: venueID, withBlock: callback)
    }
  }
  
  
  func getHoursFromFoursquare(withBlock callback: HoursErrorBlock?) {
    if let venueID = foursquareVenueID {
      FoodieVenue.getHoursFromFoursquareCommon(for: self, with: venueID, withBlock: callback)
    }
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
                     withName name: String? = nil,
                     withBlock callback: FoodieObject.BooleanErrorBlock?) {
    
    // Do state transition for this save. Early return if no save needed, or if illegal state transition
    let earlyReturnStatus = foodieObject.saveStateTransition(to: location)
    
    if let earlySuccess = earlyReturnStatus.success {
      DispatchQueue.global(qos: .userInitiated).async { callback?(earlySuccess, earlyReturnStatus.error) }
      return
    }
    
    DispatchQueue.global(qos: .userInitiated).async { /*[unowned self] in */
      self.foodieObject.savesCompletedFromAllChildren(to: location, withName: name, withBlock: callback)
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
