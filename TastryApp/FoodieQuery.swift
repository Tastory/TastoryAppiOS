//
//  FoodieQuery.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-08-05.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Parse
import CoreLocation

class FoodieQuery {
  
  // MARK: - Types & Enumerations
  typealias StoriesErrorBlock = ([FoodieStory]?, Error?) -> Void
  typealias StoriesQueryBlock = ([FoodieStory]?, FoodieQuery?, Error?) -> Void
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
  
  
  
  // MARK: Error Types
  enum ErrorCode: LocalizedError {
    
    case cannotCreatePFQuery
    case noPFQueryToPerformAnotherSearch
    case getFirstResultedInMoreThanOne
    
    var errorDescription: String? {
      switch self {
      case .cannotCreatePFQuery:
        return NSLocalizedString("Cannot create PFQuery, unable to perform the Query", comment: "Error description for a FoodieQuery error code")
      case .noPFQueryToPerformAnotherSearch:
        return NSLocalizedString("No initial PFQuery created, so cannot get another batch of query results", comment: "Error description for a FoodieQuery error code")
      case .getFirstResultedInMoreThanOne:
        return NSLocalizedString("Not expecting more than 1 Story when getting first from Draft", comment: "Error description for a FoodieQuery error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARK: - Private Instance Variables
  private var pfQuery: PFQuery<PFObject>?
  private var pfVenueSubQuery: PFQuery<PFObject>?
  private var pfAuthorsSubQuery: PFQuery<PFObject>?
  
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
  
  // Parameters for filtering by Author(s). This is ORed with the Role(s) filter
  private var authors: [FoodieUser]?
  
  // Parameters for filtering by Role(s), inclusive. This is ORed with Author(s) filter
  private var minRoleLevel: FoodieRole.Level?
  private var maxRoleLevel: FoodieRole.Level?
  
  // Constraining Parameters
  private var skip: Int = 0
  private var limit: Int = 0
  
  // Arrangement Parameters
  private var arrangementArray: [(type: SortType, direction: SortDirection)] = [(SortType, SortDirection)]()
  
  
  // MARK: - Public Static Functions
  
  static func getFirstStory(byAuthor user: FoodieUser, from localType: FoodieObject.LocalType, withBlock callback: AnyErrorBlock?) {
    let query = FoodieStory.query()!
    query.whereKey("author", equalTo: user)
    query.fromPin(withName: localType.rawValue)  // the Pin Name is just the Local Type String value
    query.findObjectsInBackground { (objects, error) in
      if let objects = objects, (objects.count > 1 || objects.count < 0), error == nil {
        CCLog.warning("Expecting 0 or 1 Story in Draft at this point. Got \(objects.count) instead")
        callback?(nil, ErrorCode.getFirstResultedInMoreThanOne)
      } else if let objects = objects, objects.count == 1 {
        callback?(objects[0], error)
      } else {
        callback?(nil, error)
      }
    }
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
  
  
  func addRoleFilter(min: FoodieRole.Level?, max: FoodieRole.Level?) {
    minRoleLevel = min
    maxRoleLevel = max
  }
  
  
  func addAuthorsFilter(users: [FoodieUser]) {
    authors = users
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
    
//    if let hourOpen = hourOpen {
//      addedQueryMetric = true
//      CCLog.assert("Hours based query not implemented yet!")
//    }
    
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
  
  
  func setupAuthorORedQuery() -> PFQuery<PFObject>? {
    
    var userQueryEnabled = false
    var roleQueryEnabled = false
    
    guard let usersSubQuery = FoodieUser.query() else {
      CCLog.fatal("Cannot create a PFQuery object from FoodieUser")
    }
    
    guard let roleSubQuery = FoodieUser.query() else {
      CCLog.fatal("Cannot create a PFQuery object from FoodieUser")
    }
    
    if let users = authors, users.count > 0 {
      var authorUsernames = [String]()
      for user in users {
        guard let username = user.username else {
          CCLog.fatal("User in Author list does not contain a Username")
        }
        authorUsernames.append(username)
      }
      usersSubQuery.whereKey("username", containedIn: authorUsernames)
      userQueryEnabled = true
    }
    

    if let maxRoleLevel = maxRoleLevel {
      roleSubQuery.whereKey("roleLevel", lessThanOrEqualTo: maxRoleLevel.rawValue)
      roleQueryEnabled = true
    }
      
    if let minRoleLevel = minRoleLevel {
      roleSubQuery.whereKey("roleLevel", greaterThanOrEqualTo: minRoleLevel.rawValue)
      roleQueryEnabled = true
    }
      
    if userQueryEnabled && roleQueryEnabled {
      return PFQuery.orQuery(withSubqueries: [usersSubQuery, roleSubQuery])
    } else if userQueryEnabled {
      return usersSubQuery
    } else if roleQueryEnabled {
      return roleSubQuery
    } else {
      return nil
    }
  }
  
  
  func initStoryQueryAndSearch(withBlock callback: StoriesErrorBlock?) {
    
    guard var outerQuery = FoodieStory.query() else {
      CCLog.assert("Cannot create a PFQuery object from FoodieStory")
      callback?(nil, ErrorCode.cannotCreatePFQuery)
      return
    }
    
    guard let venueSubQuery = FoodieVenue.query() else {
      CCLog.assert("Cannot create a PFQuery object from FoodieStory")
      callback?(nil, ErrorCode.cannotCreatePFQuery)
      return
    }
    
    outerQuery = setupCommonQuery(for: outerQuery)
    
    // If there's any User filtering criteria, create a relational query
    if let authorsSubQuery = setupAuthorORedQuery() {
      outerQuery.whereKey("author", matchesQuery: authorsSubQuery)
      pfAuthorsSubQuery = authorsSubQuery
    }
    
    // If there's any Venue filtering criteria, create a relational query
    if let venueSubQuery = setupVenueQuery(for: venueSubQuery) {
      outerQuery.whereKey("venue", matchesQuery: venueSubQuery)
      pfVenueSubQuery = venueSubQuery
    }
  
    // Keep track of the Query objects
    pfQuery = outerQuery
    
    // Do the actual search!
    let queryRetry = SwiftRetry()
    queryRetry.start("query and search for Story", withCountOf: Constants.QueryRetryCount) { [unowned self] in
      self.pfQuery!.findObjectsInBackground { (objects, error) in
        if let stories = objects as? [FoodieStory] {
          callback?(stories, error)
        } else {
          if queryRetry.attempt(after: Constants.QueryRetryDelaySeconds, withQoS: .utility) { return }
          callback?(nil, error)
        }
      }
    }
  }
  
  
  func initVenueQueryAndSearch(withBlock callback: VenuesErrorBlock?) {
    guard var query = FoodieVenue.query() else {
      CCLog.assert("Cannot create a PFQuery object from FoodieStory")
      callback?(nil, ErrorCode.cannotCreatePFQuery)
      return
    }
    
    query = setupCommonQuery(for: query)
    query = setupVenueQueryWithFoursquareID(for: query)
    pfQuery = query
    
    // Do the actual search!
    let queryRetry = SwiftRetry()
    queryRetry.start("query and search for Venue", withCountOf: Constants.QueryRetryCount) { [unowned self] in
      self.pfQuery!.findObjectsInBackground { (objects, error) in
        if let stories = objects as? [FoodieVenue] {
          callback?(stories, error)
        } else {
          if queryRetry.attempt(after: Constants.QueryRetryDelaySeconds, withQoS: .utility) { return }
          callback?(nil, error)
        }
      }
    }
  }
  
  
  func getNextStories(for count: Int, withBlock callback: StoriesErrorBlock?) {
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
        if let stories = objects as? [FoodieStory] {
          callback?(stories, error)
        } else {
          if queryRetry.attempt(after: Constants.QueryRetryDelaySeconds, withQoS: .utility) { return }
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
        if let stories = objects as? [FoodieVenue] {
          callback?(stories, error)
        } else {
          if queryRetry.attempt(after: Constants.QueryRetryDelaySeconds, withQoS: .utility) { return }
          callback?(nil, error)
        }
      }
    }
  }
}
