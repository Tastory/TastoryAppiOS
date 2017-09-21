//
//  FoodieQuery.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-08-05.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import Parse
import CoreLocation

class FoodieQuery {
  
  // MARK: - Types & Enumerations
  typealias JournalsErrorBlock = ([FoodieJournal]?, Error?) -> Void
  typealias VenuesErrorBlock = ([FoodieVenue]?, Error?) -> Void
  
  enum LocationType: String {
    case coordinateRectangle = "coordinateRectangle"
    case pointAndRadius = "pointAndRadius"
  }
  
  enum SortType: String {
    case creationTime = "creationTime"
    case modificationTime = "modificationTime"
    // case proximity = "proximity"  // Always sorted from nearest to further by default. Other explicit arrangements takes precedence however.
    case price = "price"  // TODO: This doesn't work for now
  }
  
  enum SortDirection: String {
    case ascending = "ascending"
    case descending = "descending"
  }
  
  
  
  // MARK: - Constants
  struct Constants {
    static let QueryRetryCount = 5
    static let QueryRetryDelaySeconds: Double = 0.5
  }
  
  
  
  // MARK: Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case cannotCreatePFQuery
    case noPFQueryToPerformAnotherSearch
    
    var errorDescription: String? {
      switch self {
      case .cannotCreatePFQuery:
        return NSLocalizedString("Cannot create PFQuery, unable to perform the Query", comment: "Error description for a FoodieQuery error code")
      case .noPFQueryToPerformAnotherSearch:
        return NSLocalizedString("No initial PFQuery created, so cannot get another batch of query results", comment: "Error description for a FoodieQuery error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Private Instance Variables
  private var pfQuery: PFQuery<PFObject>?
  private var pfInnerQuery: PFQuery<PFObject>?
  
  private var foursquareVenueID: String?
  
  // Allow 2 ways to do location queries. Either coordinate + radius, or upper left and lower right coordinate
  private var locationType: LocationType?
  private var southWestCoordinate: CLLocationCoordinate2D!
  private var northEastCoordinate: CLLocationCoordinate2D!
  private var lowerRightCoordiante: CLLocationCoordinate2D!
  private var originCoordinate: CLLocationCoordinate2D!
  private var radius: Double!  // In km
  
  // Parameters for filteringy by Category
  private var category: String?
  
  // Parameters for filtering by Hour of Operation
  private var hourOpen: String?
  
  // Parameters for filtering by Price
  private var priceTiers: [Int]?
  
  // Constraining Parameters
  private var skip: Int = 0
  private var limit: Int = 0
  
  // Arrangement Parameters
  private var arrangementArray: [(type: SortType, direction: SortDirection)] = [(SortType, SortDirection)]()
  
  
  // MARK: - Public Static Functions
  static func getFirstStory(from localType: FoodieObject.LocalType, withBlock callback: FoodieObject.RetrievedObjectBlock?) {
    let query = FoodieJournal.query()!
    query.fromPin(withName: localType.rawValue)  // the Pin Name is just the Local Type String value
    query.getFirstObjectInBackground(block: callback)
  }
  
  
  // MARK: - Public Instance Functions
  
  func addLocationFilter(southWest: CLLocationCoordinate2D, northEast: CLLocationCoordinate2D) {
    self.locationType = .coordinateRectangle
    self.southWestCoordinate = southWest
    self.northEastCoordinate = northEast
  }
  
  
  func addLocationFilter(origin: CLLocationCoordinate2D, radius: Double) {
    self.locationType = .pointAndRadius
    self.originCoordinate = origin
    self.radius = radius
  }
  
  
  func addCategoryFilter() {
  
  }
  
  
  func addHourFilter() {
    
  }
  
  
  func addPriceFilter() {
    
  }
  
  func addFoursquareVenueIdFilter(id: String) {
    foursquareVenueID = id
  }
  
  func setSkip(to value: Int) {
    skip = value
  }
  
  
  func setLimit(to value: Int) {
    limit = value
  }
  
  
  // Return index of first element found. Otherwise returns nil if element not found
  func findArrangement(type: SortType, direction: SortDirection) -> Int? {
    var arrangementIndex = 0
    
    while arrangementIndex < arrangementArray.count {
      if arrangementArray[arrangementIndex].type == type && arrangementArray[arrangementIndex].direction == direction {
        return arrangementIndex
      }
      arrangementIndex += 1
    }
    
    return nil
  }
  
  
  // Not added and returns false if arrangement already exists
  func addArrangement(type: SortType, direction: SortDirection) -> Bool {
    if findArrangement(type: type, direction: direction) == nil {
      arrangementArray.append((type, direction))
      return true
    } else {
      return false
    }
  }
  
  
  // Not removed and returns false if arrangemnt not found
  func removeArrangement(type: SortType, direction: SortDirection) -> Bool {
    var arrangementRemoved = false
    var arrangementIndex: Int?
    
    while true {
      arrangementIndex = findArrangement(type: type, direction: direction)
      
      if arrangementIndex != nil {
        arrangementArray.remove(at: arrangementIndex!)
        arrangementRemoved = true
      } else {
        break
      }
    }
    
    return arrangementRemoved
  }

  
  func clearArrangements() {
    arrangementArray.removeAll()
  }
  
  
  func setupCommonQuery(for query: PFQuery<PFObject>) -> PFQuery<PFObject> {
    // TODO: Setup query cache policy
    // query.cachePolicy = .networkElseCache  // With Pinning enabled, this results in 'NSInternalInconsistencyException', reason: 'Method not allowed when Pinning is enabled.'
    
    // Set query constraints
    query.limit = limit
    query.skip = skip

    // Set query arrangements
    for arrangement in arrangementArray {

      var typeString: String!

      switch arrangement.type {
      case .creationTime:
        typeString = "createdAt"
      case .modificationTime:
        typeString = "updatedAt"
      case .price:
        typeString = "price"  // TODO: This doesn't work for now
      }

      switch arrangement.direction {
      case .ascending:
        query.addAscendingOrder(typeString)
      case .descending:
        query.addDescendingOrder(typeString)
      }
    }
    return query
  }
  
  
  func setupVenueQuery(for query: PFQuery<PFObject>) -> PFQuery<PFObject>? {
    var addedQueryMetric = false
    
    if let location = locationType {
      addedQueryMetric = true
      
      switch location {
      case .coordinateRectangle:
        let southWestGeoPoint = PFGeoPoint(latitude: southWestCoordinate.latitude,
                                           longitude: southWestCoordinate.longitude)
        let northEastGeoPoint = PFGeoPoint(latitude: northEastCoordinate.latitude,
                                           longitude: northEastCoordinate.longitude)
        query.whereKey("location",
                       withinGeoBoxFromSouthwest: southWestGeoPoint,
                       toNortheast: northEastGeoPoint)
      case .pointAndRadius:
        let originGeoPoint = PFGeoPoint(latitude: originCoordinate.latitude,
                                        longitude: originCoordinate.longitude)
        query.whereKey("location",
                       nearGeoPoint: originGeoPoint,
                       withinKilometers: radius)
      }
    }
    
    if let category = category {
      addedQueryMetric = true
      query.whereKey("category", equalTo: category)
    }
    
    if let priceTiers = priceTiers {
      addedQueryMetric = true
      if priceTiers.isEmpty {
        CCLog.assert("Non-nil but empty priceTiers array supplied")
      } else {
        query.whereKey("priceTier", containedIn: priceTiers)
      }
    }
    
    if let hourOpen = hourOpen {
      addedQueryMetric = true
      CCLog.assert("Hours based query not implemented yet!")
    }
    
    return addedQueryMetric ? query : nil
  }
  

  func setupVenueQueryWithFoursquareID(for query: PFQuery<PFObject>) -> PFQuery<PFObject> {
    if let id = foursquareVenueID {
      return query.whereKey("foursquareVenueID", equalTo: id)
    } else {
      CCLog.assert("Expected Foursquare Venue ID to setup query")
      return query
    }
  }
  
  
  func initJournalQueryAndSearch(withBlock callback: JournalsErrorBlock?) {
    // This is the Outer Query
    guard var outerQuery = FoodieJournal.query() else {
      CCLog.assert("Cannot create a PFQuery object from FoodieJournal")
      callback?(nil, ErrorCode.cannotCreatePFQuery)
      return
    }
    
    // This is the Inner Query
    guard let innerQuery = FoodieVenue.query() else {
      CCLog.assert("Cannot create a PFQuery object from FoodieJournal")
      callback?(nil, ErrorCode.cannotCreatePFQuery)
      return
    }
    
    outerQuery = setupCommonQuery(for: outerQuery)
    
    // If there's any Venue filtering criteria, create a relational query
    if let innerQuery = setupVenueQuery(for: innerQuery) {
      outerQuery.whereKey("venue", matchesQuery: innerQuery)
    }
  
    // Keep track of the Query objects
    pfQuery = outerQuery
    pfInnerQuery = innerQuery
    
    // Do the actual search!
    let queryRetry = SwiftRetry()
    queryRetry.start("query and search for Story", withCountOf: Constants.QueryRetryCount) {
      self.pfQuery!.findObjectsInBackground { (objects, error) in
        if let journals = objects as? [FoodieJournal] {
          callback?(journals, error)
        } else {
          if queryRetry.attempt(after: Constants.QueryRetryDelaySeconds, withQoS: .userInitiated) { return }
          callback?(nil, error)
        }
      }
    }
  }
  
  
  func initVenueQueryAndSearch(withBlock callback: VenuesErrorBlock?) {
    guard var query = FoodieVenue.query() else {
      CCLog.assert("Cannot create a PFQuery object from FoodieJournal")
      callback?(nil, ErrorCode.cannotCreatePFQuery)
      return
    }
    
    query = setupCommonQuery(for: query)
    query = setupVenueQueryWithFoursquareID(for: query)
    pfQuery = query
    
    // Do the actual search!
    let queryRetry = SwiftRetry()
    queryRetry.start("query and search for Venue", withCountOf: Constants.QueryRetryCount) {
      self.pfQuery!.findObjectsInBackground { (objects, error) in
        if let journals = objects as? [FoodieVenue] {
          callback?(journals, error)
        } else {
          if queryRetry.attempt(after: Constants.QueryRetryDelaySeconds, withQoS: .userInitiated) { return }
          callback?(nil, error)
        }
      }
    }
  }
  
  
  func getNextJournals(for count: Int, withBlock callback: JournalsErrorBlock?) {
    guard let query = pfQuery else {
      CCLog.assert("No initial PFQuery created, so cannot get another batch of query results")
      callback?(nil, ErrorCode.noPFQueryToPerformAnotherSearch)
      return
    }
    
    skip = skip + limit
    limit = count
    query.skip = skip
    query.limit = limit
    
    // Do the actual search!
    let queryRetry = SwiftRetry()
    queryRetry.start("query and search for next Stories", withCountOf: Constants.QueryRetryCount) {
      query.findObjectsInBackground { (objects, error) in
        if let journals = objects as? [FoodieJournal] {
          callback?(journals, error)
        } else {
          if queryRetry.attempt(after: Constants.QueryRetryDelaySeconds, withQoS: .userInitiated) { return }
          callback?(nil, error)
        }
      }
    }
  }
  
  
  func getNextVenues(for count: Int, withBlock callback: VenuesErrorBlock?) {
    guard let query = pfQuery else {
      CCLog.assert("No initial PFQuery created, so cannot get another batch of query results")
      callback?(nil, ErrorCode.noPFQueryToPerformAnotherSearch)
      return
    }
    
    skip = skip + limit
    limit = count
    query.skip = skip
    query.limit = limit
    
    // Do the actual search!
    let queryRetry = SwiftRetry()
    queryRetry.start("query and search for next Venues", withCountOf: Constants.QueryRetryCount) {
      query.findObjectsInBackground { (objects, error) in
        if let journals = objects as? [FoodieVenue] {
          callback?(journals, error)
        } else {
          if queryRetry.attempt(after: Constants.QueryRetryDelaySeconds, withQoS: .userInitiated) { return }
          callback?(nil, error)
        }
      }
    }
  }
}
