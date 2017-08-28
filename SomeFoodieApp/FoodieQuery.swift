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
    case noLocation = "noLocation"
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
  
  
  // MARK: Error Types Definition
  enum ErrorCode: LocalizedError {
    
    case noPFQueryToPerformAnotherSearch
    
    var errorDescription: String? {
      switch self {
      case .noPFQueryToPerformAnotherSearch:
        return NSLocalizedString("No initial PFQuery created, so cannot get another batch of query results", comment: "Error description for a FoodieQuery error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      DebugPrint.error(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Private Instance Variables
  private var pfQuery: PFQuery<PFObject>?
  
  private var foursquareVenueID: String?
  
  // Allow 2 ways to do location queries. Either coordinate + radius, or upper left and lower right coordinate
  private var locationType: LocationType = .noLocation
  private var southWestCoordinate: CLLocationCoordinate2D!
  private var northEastCoordinate: CLLocationCoordinate2D!
  private var lowerRightCoordiante: CLLocationCoordinate2D!
  private var originCoordinate: CLLocationCoordinate2D!
  private var radius: Double!  // In km
  
  // Parameters for filteringy by Category
  private var filterByCategory: Bool = false
  
  // Parameters for filtering by Hour of Operation
  private var filterByHour: Bool = false
  
  // Parameters for filtering by Price
  private var filterByPrice: Bool = false
  
  // Constraining Parameters
  private var skip: Int = 0
  private var limit: Int = 0
  
  // Arrangement Parameters
  private var arrangementArray: [(type: SortType, direction: SortDirection)] = [(SortType, SortDirection)]()
  
  
  // MARK: - Private Functions
  
  
  
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
  
  
  func setupCommon(for query: PFQuery<PFObject>) -> PFQuery<PFObject> {
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
  
  
  func setupVenueCommon(for query: PFQuery<PFObject>) -> PFQuery<PFObject> {
    if let id = foursquareVenueID {
      query.whereKey("foursquareVenueID", equalTo: id)
      
    } else {
      switch locationType {
        
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
        
      case .noLocation:
        break
      }
    }
    return query
  }
  
  func initJournalQueryAndSearch(withBlock callback: JournalsErrorBlock?) {
    pfQuery = FoodieJournal.query()
    pfQuery = setupCommon(for: pfQuery!)
    pfQuery = setupVenueCommon(for: pfQuery!)  // TODO: This should be relational query
    
    // Do the actual search!
    pfQuery!.findObjectsInBackground { (objects, error) in
      if let journals = objects as? [FoodieJournal] {
        callback?(journals, error)
      } else {
        callback?(nil, error)
      }
    }
  }
  
  func initVenueQueryAndSearch(withBlock callback: VenuesErrorBlock?) {
    pfQuery = FoodieVenue.query()
    pfQuery = setupCommon(for: pfQuery!)
    pfQuery = setupVenueCommon(for: pfQuery!)
    
    // Do the actual search!
    pfQuery!.findObjectsInBackground { (objects, error) in
      if let journals = objects as? [FoodieVenue] {
        callback?(journals, error)
      } else {
        callback?(nil, error)
      }
    }
  }
  
  func getNextJournals(for count: Int, withBlock callback: JournalsErrorBlock?) {
    guard let query = pfQuery else {
      DebugPrint.assert("No initial PFQuery created, so cannot get another batch of query results")
      callback?(nil, ErrorCode.noPFQueryToPerformAnotherSearch)
      return
    }
    
    skip = skip + limit
    limit = count
    query.skip = skip
    query.limit = limit
    
    // Do the actual search!
    query.findObjectsInBackground { (objects, error) in
      if let journals = objects as? [FoodieJournal] {
        callback?(journals, error)
      } else {
        callback?(nil, error)
      }
    }
  }
  
  func getNextVenues(for count: Int, withBlock callback: VenuesErrorBlock?) {
    guard let query = pfQuery else {
      DebugPrint.assert("No initial PFQuery created, so cannot get another batch of query results")
      callback?(nil, ErrorCode.noPFQueryToPerformAnotherSearch)
      return
    }
    
    skip = skip + limit
    limit = count
    query.skip = skip
    query.limit = limit
    
    // Do the actual search!
    query.findObjectsInBackground { (objects, error) in
      if let journals = objects as? [FoodieVenue] {
        callback?(journals, error)
      } else {
        callback?(nil, error)
      }
    }
  }
}
