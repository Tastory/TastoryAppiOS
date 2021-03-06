//
//  FoodieQuery.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-08-05.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
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
    case discoverability = "discoverability"
  }
  
  enum SortDirection: String {
    case ascending = "ascending"
    case descending = "descending"
  }
  
  
  
  // MARK: - Constants
  struct Constants {
    static let QueryRetryCount = 5
    static let QueryRetryDelaySeconds: Double = 0.5
    static let MaxStoriesLimitCount: Int = 200
    static let RadiusForMinStoriesFunctionName = "radiusForMinStories"
    static let RadiusForMinStoriesCloudParamLatitude = "latitude"
    static let RadiusForMinStoriesCloudParamLongitude = "longitude"
    static let RadiusForMinStoriesCloudParamMinStories = "minStories"
  }
  
  
  
  // MARK: Error Types
  enum ErrorCode: LocalizedError {
    
    case cannotCreatePFQuery
    case noPFQueryToPerformAnotherSearch
    case getFirstResultedInMoreThanOne
    case queryInitStoriesNoRadius
    case queryInitStoriesNoResults
    
    var errorDescription: String? {
      switch self {
      case .cannotCreatePFQuery:
        return NSLocalizedString("Cannot create PFQuery, unable to perform the Query", comment: "Error description for a FoodieQuery error code")
      case .noPFQueryToPerformAnotherSearch:
        return NSLocalizedString("No initial PFQuery created, so cannot get another batch of query results", comment: "Error description for a FoodieQuery error code")
      case .getFirstResultedInMoreThanOne:
        return NSLocalizedString("Not expecting more than 1 Story when getting first from Draft", comment: "Error description for a FoodieQuery error code")
      case .queryInitStoriesNoRadius:
        return NSLocalizedString("Initial search radius = nil from Cloud Function", comment: "Error description for a FoodieQuery error code")
      case .queryInitStoriesNoResults:
        return NSLocalizedString("Initial stories = nil from initial Query", comment: "Error description for a FoodieQuery error code")
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

  // Parameters for filtering by Venue
  private var  venue: String?

  // Parameters for filtering by Category
  private var categories = [String]()
  
  // Paramters for filtering by Meal Type
  private var mealTypes = [String]()
  
  // Parameters for filtering by Hour of Operation
  private var hourOpen: String?
  
  // Parameters for filtering by Price
  private var priceLowerLimit: Double?
  private var priceUpperLimit: Double?
  
  // Parameters for filtering by Author(s). This is ORed with the Role(s) filter
  private var authors: [FoodieUser]?
  private var bookmarkOfUser: FoodieUser?
  
  // Parameters for filtering by Discoverability, inclusive.
  private var minDiscoverability: Double?
  private var maxDiscoverability: Double?
  private var discoverableOnly: Bool = false
  private var ownStoriesAlso: Bool = false
  
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
  
  
  static func queryInitStories(at coordinate: CLLocationCoordinate2D, minStories: UInt, maxRadius: Double? = nil,  withBlock callback: StoriesQueryBlock?) {
    
    let cloudFunctionName = Constants.RadiusForMinStoriesFunctionName
    
    // Setup parameters and submit Cloud function
    var parameters = [AnyHashable: Any]()
    parameters[Constants.RadiusForMinStoriesCloudParamLatitude] = coordinate.latitude
    parameters[Constants.RadiusForMinStoriesCloudParamLongitude] = coordinate.longitude
    parameters[Constants.RadiusForMinStoriesCloudParamMinStories] = minStories
    
    PFCloud.callFunction(inBackground: cloudFunctionName, withParameters: parameters) { (radius, error) in
      
      if let error = error {
        CCLog.warning("PFCloud Function \(cloudFunctionName) failed - \(error.localizedDescription)")
        callback?(nil, nil, error)
        return
      }
      
      guard var radius = radius as? Double else {
        CCLog.warning("PFCloud Function \(cloudFunctionName) expected to return Radius")
        callback?(nil, nil, ErrorCode.queryInitStoriesNoRadius)
        return
      }

      if let maxRadius = maxRadius, radius > maxRadius {
        radius = maxRadius
      }

      let query = FoodieQuery()
      query.addLocationFilter(origin: coordinate, radius: radius)
      
      if !FoodieFilter.main.showEverything {
        query.addDiscoverabilityFilter(min: 0.01, max: nil)
        query.setDiscoverableOnly(to: true)
      }
      
      // Make sure you can alway see your own posts
//      if let currentUser = FoodieUser.current, currentUser.isRegistered {
//        query.setOwnStoriesAlso()
//      }

      var storiesLimit = lround(radius * 10)
      if storiesLimit < FoodieGlobal.Constants.StoryFeedPaginationCount {
        storiesLimit = FoodieGlobal.Constants.StoryFeedPaginationCount
      }
      if storiesLimit > FoodieQuery.Constants.MaxStoriesLimitCount {
        storiesLimit = FoodieQuery.Constants.MaxStoriesLimitCount
      }
      
      query.setSkip(to: 0)
      query.setLimit(to: storiesLimit)
      _ = query.addArrangement(type: .discoverability, direction: .descending)
      _ = query.addArrangement(type: .creationTime, direction: .descending)
      
      // Actually do the Query
      query.initStoryQueryAndSearch { (stories, error) in
        
        if let error = error {
          CCLog.warning("Create Story Query & Search failed with error: \(error.localizedDescription)")
          callback?(nil, nil, error)
          return
        }
        
        guard let stories = stories else {
          CCLog.warning("Create Story Query & Search returned with nil Story Array")
          callback?(nil, nil, ErrorCode.queryInitStoriesNoResults)
          return
        }
        
        callback?(stories, query, nil)
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
  
  
  func addCategoryFilter(for categories: [FoodieCategory]) {
    self.categories.removeAll()
    
    for category in categories {
      guard let categoryID = category.foursquareCategoryID else {
        CCLog.fatal("Category for filtering doesn't contain a Foursquare Category ID")
      }
      self.categories.append(categoryID)
    }
  }
  
  
  func addPriceFilter(lowerLimit: Double, upperLimit: Double) {
    
    // Therea are Venues that have no price Tier. So if the filter is as wide as possible, we gotta include nil'ed out Price Tier Venues too.
    if lowerLimit == FoodieFilter.Constants.PriceLowerLimit, upperLimit == FoodieFilter.Constants.PriceUpperLimit {
      priceUpperLimit = nil
      priceLowerLimit = nil
    } else {
      priceUpperLimit = upperLimit
      priceLowerLimit = lowerLimit
    }
  }
  
  
  func addMealTypeFilter(for mealTypes: [MealType]) {
    self.mealTypes.removeAll()
    
    for mealType in mealTypes {
      self.mealTypes.append(mealType.rawValue)
    }
  }
  
  
  func addHourFilter() {
    CCLog.fatal("FoodieQuery Hour Filters is not yet implemented")
  }
  
  
  func addFoursquareVenueIdFilter(id: String) {
    foursquareVenueID = id
  }
  
  
  func addDiscoverabilityFilter(min: Double?, max: Double?) {
    minDiscoverability = min
    maxDiscoverability = max
  }
  
  
  func setDiscoverableOnly(to discoverable: Bool) {
    discoverableOnly = discoverable
  }
  
  
  func addAuthorsFilter(users: [FoodieUser]) {
    authors = users
  }
  
  func addVenueFilter(venueId: String) {
    venue = venueId
  }

  func addBookmarkFilter(for user: FoodieUser) {
    bookmarkOfUser = user
  }
  
  func setOwnStoriesAlso() {
    ownStoriesAlso = true
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
      case .discoverability:
        typeString = "discoverability"
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
    
    if categories.count > 0 {
      addedQueryMetric = true
      query.whereKey("foursquareCategoryIDs", containedIn: categories)
    }
    
    if let priceLowerLimit = priceLowerLimit {
      addedQueryMetric = true
      query.whereKey("priceTier", greaterThanOrEqualTo: priceLowerLimit)
    }
    
    if let priceUpperLimit = priceUpperLimit {
      addedQueryMetric = true
      query.whereKey("priceTier", lessThanOrEqualTo: priceUpperLimit)
    }

    if let venueId = venue {
      addedQueryMetric = true
      query.whereKey("objectId", equalTo: venueId)
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
  
  
  func setupAuthorQuery() -> PFQuery<PFObject>? {
    guard let usersSubQuery = FoodieUser.query() else {
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
      return usersSubQuery
    } else {
      return nil
    }
  }
  
  
  func initStoryQueryAndSearch(withBlock callback: StoriesErrorBlock?) {
    
    var coreQuery = PFQuery()
    
    if let user = bookmarkOfUser {
      coreQuery = user.relation(forKey: "bookmarkedStories").query()
    } else {
      
      guard let query = FoodieStory.query() else {
        CCLog.assert("Cannot create a PFQuery object from FoodieStory")
        callback?(nil, ErrorCode.cannotCreatePFQuery)
        return
      }
      coreQuery = query
    }
    
    guard let venueSubQuery = FoodieVenue.query() else {
      CCLog.assert("Cannot create a PFQuery object from FoodieStory")
      callback?(nil, ErrorCode.cannotCreatePFQuery)
      return
    }
    
    // If there's any User filtering criteria, create a relational query
    if let authorsSubQuery = setupAuthorQuery() {
      coreQuery.whereKey("author", matchesQuery: authorsSubQuery)
      pfAuthorsSubQuery = authorsSubQuery
    }
    
    // If there's any Venue filtering criteria, create a relational query
    if let venueSubQuery = setupVenueQuery(for: venueSubQuery) {
      coreQuery.whereKey("venue", matchesQuery: venueSubQuery)
      pfVenueSubQuery = venueSubQuery
    }
    
    // If there's any Meal Type filtering criteria
    if mealTypes.count > 0 {
      coreQuery.whereKey("mealType", containedIn: mealTypes)
    }
    
    // See your own story in addition to Discoverability filtering?
    if ownStoriesAlso, let currentUser = FoodieUser.current {
      let ownQuery = coreQuery.copy() as! PFQuery
      ownQuery.whereKey("author", equalTo: currentUser)
      
      if let maxDiscoverability = maxDiscoverability {
        coreQuery.whereKey("discoverability", lessThanOrEqualTo: maxDiscoverability)
      }
      
      if let minDiscoverability = minDiscoverability {
        coreQuery.whereKey("discoverability", greaterThanOrEqualTo: minDiscoverability)
      }
    
      if discoverableOnly {
        coreQuery.whereKey("discoverable", equalTo: true)
      }
      
      pfQuery = PFQuery.orQuery(withSubqueries: [coreQuery, ownQuery])
    }
    
    else {
      if let maxDiscoverability = maxDiscoverability {
        coreQuery.whereKey("discoverability", lessThanOrEqualTo: maxDiscoverability)
      }
      
      if let minDiscoverability = minDiscoverability {
        coreQuery.whereKey("discoverability", greaterThanOrEqualTo: minDiscoverability)
      }
      
      if discoverableOnly {
        coreQuery.whereKey("discoverable", equalTo: true)
      }
      
      pfQuery = coreQuery
    }
    
    pfQuery = setupCommonQuery(for: pfQuery!)
    
    // Always also just fetch the Venue and Author data associated
    pfQuery!.includeKey("author")
    pfQuery!.includeKey("venue")
    pfQuery!.includeKey("reputation")
    
    // Do the actual search!
    CCLog.info("Performing Query!")
    
    let queryRetry = SwiftRetry()
    queryRetry.start("query and search for Story", withCountOf: Constants.QueryRetryCount) {
      self.pfQuery!.findObjectsInBackground { (objects, error) in
        
        if let stories = objects as? [FoodieStory] {
          CCLog.debug("Perform Query complete finding objects in background")
          callback?(stories, error)
        } else {
          if queryRetry.attempt(after: Constants.QueryRetryDelaySeconds, withQoS: .utility) { return }
          CCLog.warning("Perform Query exhausted retry with error - \(error?.localizedDescription ?? "error = nil")")
          callback?(nil, error)
        }
        queryRetry.done()
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
    queryRetry.start("query and search for Venue", withCountOf: Constants.QueryRetryCount) {
      self.pfQuery!.findObjectsInBackground { (objects, error) in
        if let stories = objects as? [FoodieVenue] {
          callback?(stories, error)
        } else {
          if queryRetry.attempt(after: Constants.QueryRetryDelaySeconds, withQoS: .utility) { return }
          callback?(nil, error)
        }
        queryRetry.done()
      }
    }
  }
  
  
  func getNextStories(for count: Int, withBlock callback: StoriesErrorBlock?) {
    guard pfQuery != nil else {
      CCLog.assert("No initial PFQuery created, so cannot get another batch of query results")
      callback?(nil, ErrorCode.noPFQueryToPerformAnotherSearch)
      return
    }
    
    skip = skip + limit
    limit = count
    pfQuery!.skip = skip
    pfQuery!.limit = limit
    
    // Do the actual search!
    let queryRetry = SwiftRetry()
    queryRetry.start("Query and search for next Stories", withCountOf: Constants.QueryRetryCount) {
      self.pfQuery!.findObjectsInBackground { (objects, error) in
        if let stories = objects as? [FoodieStory] {
          callback?(stories, error)
        } else {
          if queryRetry.attempt(after: Constants.QueryRetryDelaySeconds, withQoS: .utility) { return }
          callback?(nil, error)
        }
        queryRetry.done()
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
        queryRetry.done()
      }
    }
  }
}
