//
//  DiscoverViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-03-20.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import AsyncDisplayKit
import CoreLocation

class DiscoverViewController: OverlayViewController {

  // MARK: - Error Types
  enum ErrorCode: LocalizedError {
    
    case mapQueryExceededMaxLat
    case queryNilStory
    case nilAuthor
    case nilThumbnail
    case nilMoments

    var errorDescription: String? {
      switch self {
      case .mapQueryExceededMaxLat:
        return NSLocalizedString("Exceeded allowed maximum number of degrees latitude for map query", comment: "Error description for a Map View Controller Query")
      case .queryNilStory:
        return NSLocalizedString("Create Story Query & Search returned no errors but nil Story Array", comment: "Error description for a Map View Controller Query")
      case .nilAuthor:
        return NSLocalizedString("Author is nil in the story draft", comment: "Error description for a Map View Controller Query")
      case .nilThumbnail:
        return NSLocalizedString("The thumbnail of this story is nil", comment: "Error description for a Map View Controller Query")
      case .nilMoments:
        return NSLocalizedString("There are no moments in this draft", comment: "Error description for a Map View Controller Query")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  
  // MARK: - Class Constants
  fileprivate struct Constants {
    static let QueryMaxLatDelta: CLLocationDegrees = 1.0  // Approximately 111km
    static let InitQueryMinStories: UInt = 10 // Try to find a radius that at least finds 20 stories in the beginning
    static let PullTranslationForChange: CGFloat = 50.0  // In Points
    static let PercentageOfStoryVisibleToStartPrefetch: CGFloat = 0.6
    static let TopGradientCarouselBlackAlpha: CGFloat = 0.6
    static let TopGradientMosaicBlackAlpha: CGFloat = 0.3
    static let FeedBackgroundBlackAlpha: CGFloat = 0.8
    static let SearchBarFontName = FoodieFont.Raleway.SemiBold
    static let SearchBarFontSize: CGFloat = 15.0
    static let SearchBarTextShadowAlpha: CGFloat = 0.25
    static let SearchBarPlaceholderColor = UIColor.lightGray
    static let UIDisappearanceDuration = FoodieGlobal.Constants.DefaultUIDisappearanceDuration
    static let SearchBarTitle: String = "Search"
  }

  

  // MARK: - Private Instance Variables
  private var feedCollectionNodeController: FeedCollectionNodeController!
  private var mapNavController: MapNavController?
  private var lastMapState: MapNavController.MapState?
  private var lastSelectedAnnotationIndex: Int?

  private var highlightedStoryIndex: Int?
  
  private var topGradientNode: GradientNode!
  private var feedGradientNode: GradientNode!
  
  private var storyQuery: FoodieQuery?
  private var storyArray = [FoodieStory]()
  private var storyAnnotations = [StoryMapAnnotation]()
  
  private var discoverFilter: FoodieFilter?
  private var forceRequery: Bool = false
  private var autoFilterSearch: Bool = false
  private var currentLocation: CLLocation?
  private var scrollSelect: Bool = false
  private var searchResult: SearchResult?
  
  
  // MARK: - IBOutlets
  @IBOutlet var mosaicLayoutChangePanRecognizer: UIPanGestureRecognizer!
  
  @IBOutlet var searchField: UIButton!
  //@IBOutlet var searchField: UILabel!
  @IBOutlet var filterButton: UIButton!
  @IBOutlet var draftButton: UIButton!
  @IBOutlet var currentLocationButton: UIButton!
  @IBOutlet var cameraButton: UIButton!
  @IBOutlet var logoutButton: UIButton!
  @IBOutlet var profileButton: UIButton!
  @IBOutlet var searchButton: UIButton!
  @IBOutlet var allStoriesButton: UIButton!
  @IBOutlet var backButton: UIButton!
  
  @IBOutlet var touchForwardingView: TouchForwardingView? {
    didSet {
      if let touchForwardingView = touchForwardingView, let mapNavController = navigationController as? MapNavController {
        touchForwardingView.passthroughViews = [mapNavController.mapView]
        touchForwardingView.touchBlock = {
          self.searchField?.resignFirstResponder()
        }
      }
    }
  }
  
  @IBOutlet var topGradientView: UIView!
  @IBOutlet var feedContainerView: UIView!
  @IBOutlet var mosaicMapView: UIView!
  @IBOutlet var carouselMapView: UIImageView!
  @IBOutlet var feedBackgroundView: UIView!
  
  @IBOutlet var searchStack: UIStackView!
  @IBOutlet var middleStack: UIStackView!
  
  @IBOutlet var noStoriesMosaicView: UIImageView!
  @IBOutlet var noStoriesCarouselView: UIView!
  
  @IBOutlet var topGradientMosaicConstraint: NSLayoutConstraint!
  @IBOutlet var topGradientCarouselConstraint: NSLayoutConstraint!
  
  @IBOutlet var feedBackgroundCarouselConstraint: NSLayoutConstraint!
  @IBOutlet var feedBackgroundMosaicConstraint: NSLayoutConstraint!

  @IBOutlet weak var touchForwardingCarouselConstraint: NSLayoutConstraint!
  @IBOutlet weak var touchForwardingMosaicConstraint: NSLayoutConstraint!
  @IBOutlet weak var touchForwardingHeightConstraint: NSLayoutConstraint!

  // MARK: - IBActions
  @IBAction func searchFieldAction(_ sender: Any) {
    showUniversalSearch()
  }

  @IBAction func launchDraftStory(_ sender: Any) {
    // This is used for viewing the draft story to be used with update story later
    // Hide the button as needed, due to problems with empty draft story and saving an empty story is problematic
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryEntryViewController") as? StoryEntryViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of StoryEntryViewController Class!!")
      }
      return
    }

    if FoodieStory.currentStory == nil {
      viewController.workingStory =  FoodieStory.newCurrent()
    } else {
      viewController.workingStory = FoodieStory.currentStory
    }
    
    appearanceForAllUI(alphaValue: 0.0, animated: true, duration: Constants.UIDisappearanceDuration)
    viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func launchCamera(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "CameraViewController") as? CameraViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of CameraViewController Class!!")
      }
      return
    }
    
    appearanceForAllUI(alphaValue: 0.0, animated: true, duration: Constants.UIDisappearanceDuration)
    
    viewController.cameraReturnDelegate = self
    present(viewController, animated: true)  // Use regular present for the Camera for now. Not including the camera as part of the MapNavController for now
  }
  
  
  @IBAction func currentLocationReturn(_ sender: UIButton) {
    // Clear the text field while at it
    searchField.setTitle(Constants.SearchBarTitle, for: .normal)
    
    if let dialog = LocationWatch.checkAndRequestAuthorizations() {
      present(dialog, animated: true, completion: nil)
    } else {
      mapNavController?.showCurrentRegionExposed(animated: true)
      searchButtonsHidden(is: false)
    }
  }

  @IBAction func magnifyingGlassClick(_ sender: UIButton) {
    showUniversalSearch()
  }

  @IBAction func filterClick(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Filters", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "FiltersNavViewController") as? FiltersNavViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of FiltersNavViewController Class!!")
      }
      return
    }
    
    viewController.workingFilter = discoverFilter
    viewController.filtersReturnDelegate = self
    
    appearanceForAllUI(alphaValue: 0.0, animated: true, duration: Constants.UIDisappearanceDuration)
    
    viewController.setSlideTransition(presentTowards: .down, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: false)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func searchWithFilter(_ sender: UIButton) {
    searchFilter()
  }
  
  
  @IBAction func allStories(_ sender: UIButton) {
    
    performQuery(onAllUsers: true) { stories, query, error in
      self.unwrapQueryRefreshDiscoveryView(stories: stories, query: query, error: error)
      self.searchButtonsHidden(is: true)
    }
  }
  
  
  @IBAction func logOutAction(_ sender: UIButton) {
    LogOutDismiss.askDiscardIfNeeded(from: self)
  }
  
  
  @IBAction func profileAction(_ sender: UIButton) {

    guard let user = FoodieUser.current else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("current user is not initialized")
      }
      return
    }
    showProfileView(user: user)
  }
  
  
  @IBAction func mosaicLayoutChangeAction(_ panGesture: UIPanGestureRecognizer) {
    let gestureTranslation = panGesture.translation(in: view)
    let directionalTranslation = min(gestureTranslation.y, 0.0)
    
    switch panGesture.state {
    case.began:
      fallthrough
    case.changed:
      if directionalTranslation < 0 {
        if directionalTranslation < -Constants.PullTranslationForChange {
          CCLog.info("FeedCollectionNode should change layout to Mosaic")
          mosaicLayoutChangePanRecognizer.isEnabled = false
          feedCollectionNodeController.changeLayout(to: .mosaic, animated: true)
        } else {
          let dragTransform = CATransform3DMakeTranslation(0.0, gestureTranslation.y, 0.0)
          mosaicLayoutChangePanRecognizer.view?.layer.transform = dragTransform
        }
      }
    default:
      mosaicLayoutChangePanRecognizer.view?.layer.transform = CATransform3DIdentity
    }
  }
  
  
  @IBAction func carouselLayoutChangeAction(_ sender: UIButton) {
    feedCollectionNodeController.changeLayout(to: .carousel, animated: true)
  }
  
  
  // MARK: - Private Instance Functions
  @objc func updateFeed(_ notification: NSNotification) {

    guard let userInfo = notification.userInfo else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("userInfo is missing from notification")
      }
      return
    }

    guard let action = userInfo[FoodieGlobal.RefreshFeedNotification.ActionKey] else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("action is not in userInfo")
      }
      return
    }

    let actionStr = action as! String

    if(actionStr == FoodieGlobal.RefreshFeedNotification.DeleteAction || actionStr == FoodieGlobal.RefreshFeedNotification.UpdateAction) {
      forceRequery = true
    }
  }

  @objc private func showUniversalSearch() {
    let storyboard = UIStoryboard(name: "Filters", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "UniversalSearchViewController") as? UniversalSearchViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of UniversalSearchViewController Class!!")
      }
      return
    }

    viewController.displayDelegate = self
    viewController.currentLocation = currentLocation

    if let keyword = searchField.currentTitle , keyword != Constants.SearchBarTitle {
      viewController.searchKeyWord = keyword
    }

    appearanceForAllUI(alphaValue: 0.0, animated: true, duration: Constants.UIDisappearanceDuration)
    viewController.setSlideTransition(presentTowards: .down, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: false)
    pushPresent(viewController, animated: true)
  }

  private func searchFilter() {
    performQuery { stories, query, error in

      // This is pure analytics
      let searchSuccess = (error != nil && stories != nil)
      let searchNote = error?.localizedDescription ?? ""
      Analytics.loginDiscoverFilterSearch(username: FoodieUser.current?.username ?? "nil",
                                          categoryIDs: self.discoverFilter?.selectedCategories.map( { $0.foursquareCategoryID ?? "" } ) ?? [],
                                          priceUpperLimit: self.discoverFilter?.priceUpperLimit ?? FoodieFilter.Constants.PriceUpperLimit,
                                          priceLowerLimit: self.discoverFilter?.priceLowerLimit ?? FoodieFilter.Constants.PriceLowerLimit,
                                          mealTypes: self.discoverFilter?.selectedMealTypes.map( { $0.rawValue }) ?? [],
                                          success: searchSuccess,
                                          note: searchNote,
                                          stories: stories?.count ?? 0)

      // Now we are actually unwrapping the search results
      self.unwrapQueryRefreshDiscoveryView(stories: stories, query: query, error: error)
      self.searchButtonsHidden(is: true)
    }
  }

  private func performQuery(onAllUsers: Bool = false, at mapRect: MKMapRect? = nil, withBlock callback: FoodieQuery.StoriesQueryBlock?) {
    
    var searchMapRect = MKMapRect()
    
    if mapRect == nil {
      guard let mapController = mapNavController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("mapNavController == nil")
        }
        return
      }
      searchMapRect = mapController.exposedMapRect
    } else {
      searchMapRect = mapRect!
    }
      
    let northEastMapPoint = MKMapPointMake(searchMapRect.origin.x + searchMapRect.size.width, searchMapRect.origin.y)
    let southWestMapPoint = MKMapPointMake(searchMapRect.origin.x, searchMapRect.origin.y + searchMapRect.size.height)
    let northEastCoordinate = MKCoordinateForMapPoint(northEastMapPoint)
    let southWestCoordinate = MKCoordinateForMapPoint(southWestMapPoint)
    
    CCLog.verbose("Query Location Rectangle SouthWest - (\(southWestCoordinate.latitude), \(southWestCoordinate.longitude)), NorthEast - (\(northEastCoordinate.latitude), \(northEastCoordinate.longitude))")
    
    // We are going to limit search to a maximum of 1 degree of of Latitude (approximately 111km)
    guard (northEastCoordinate.latitude - southWestCoordinate.latitude) < Constants.QueryMaxLatDelta else {
      callback?(nil, nil, ErrorCode.mapQueryExceededMaxLat)
      return
    }
    
    let query = FoodieQuery()
    query.addLocationFilter(southWest: southWestCoordinate, northEast: northEastCoordinate)
    
    if let filter = discoverFilter {
      query.addCategoryFilter(for: filter.selectedCategories)
      query.addPriceFilter(lowerLimit: filter.priceLowerLimit, upperLimit: filter.priceUpperLimit)
      query.addMealTypeFilter(for: filter.selectedMealTypes)
    }
    
    if !onAllUsers {
      // Add Filter so only Post with more than Limit Disoverability can be seen
      // query.addRoleFilter(min: .user, max: nil)
      query.addDiscoverabilityFilter(min: 0.01, max: nil)
      query.setDiscoverableOnlyTo(true)
      
      // Make sure you can alway see your own posts
//      if let currentUser = FoodieUser.current, currentUser.isRegistered {
//        query.setOwnStoriesAlso()
//      }
    }
    
    query.setSkip(to: 0)
    query.setLimit(to: FoodieGlobal.Constants.StoryFeedPaginationCount)
    _ = query.addArrangement(type: .discoverability, direction: .descending)
    _ = query.addArrangement(type: .creationTime, direction: .descending)
    
    ActivitySpinner.globalApply()
    
    // Actually do the Query
    query.initStoryQueryAndSearch { (stories, error) in
      ActivitySpinner.globalRemove()
      
      if let error = error {
        AlertDialog.present(from: self, title: "Query Failed", message: error.localizedDescription) { _ in
          CCLog.assert("Create Story Query & Search failed with error: \(error.localizedDescription)")
        }
        callback?(nil, nil, error)
        return
      }
      
      guard let storyArray = stories else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
        CCLog.fatal("Create Story Query & Search returned with nil Story Array")
      }
      
      callback?(storyArray, query, nil)
    }
  }

  
  private func unwrapQueryRefreshDiscoveryView(stories: [FoodieStory]?,query: FoodieQuery?, error :Error?, currentLocation coordinate: CLLocationCoordinate2D? = nil) {
    if let error = error {
      if let error = error as? ErrorCode, error == .mapQueryExceededMaxLat {
        AlertDialog.present(from: self, title: "Search Area Too Large", message: "Max search distance for a side is 100km. Please reduce the range and try again")
      } else {
        AlertDialog.present(from: self, title: "Story Query Error", message: error.localizedDescription) { _ in
          CCLog.assert("Story Query resulted in Error - \(error.localizedDescription)")
        }
      }
      return
    }

    guard let stories = stories else {
      AlertDialog.present(from: self, title: "Story Query Error", message: "Story Query did not produce Stories") { _ in
        CCLog.assert("Story Query resulted in storyArray = nil")
      }
      return
    }

    self.storyQuery = query
    self.storyArray = stories
    self.refreshDiscoverView(onStories: stories, zoomToRegion: true, scrollAndSelectStory: true, currentLocation: coordinate) {
       self.displayDeepLinkContent(displayDelay: 1.0)
    }
  }

  private func refreshDiscoverView(onStories stories: [FoodieStory], zoomToRegion: Bool, scrollAndSelectStory: Bool, currentLocation coordinate: CLLocationCoordinate2D? = nil, completion callback: (() -> Void)? = nil) {
    var newAnnotations = [StoryMapAnnotation]()
    
    if stories.count <= 0 {
      DispatchQueue.main.async {
        self.mapNavController?.removeAllAnnotations()
        self.storyAnnotations = newAnnotations
        
        if #available(iOS 11.0, *) {
          self.feedCollectionNodeController.resetCollectionNode(with: stories) {
            switch self.feedCollectionNodeController.layoutType {
            case .carousel:
              self.noStoriesCarouselView.isHidden = false
              
            case .mosaic:
              self.noStoriesMosaicView.isHidden = false
            }
            self.feedContainerView.isHidden = true
          }
        }
          
        // Works around weird CollectionView crash with iOS 10
        else {
          switch self.feedCollectionNodeController.layoutType {
          case .carousel:
            self.noStoriesCarouselView.isHidden = false
            
          case .mosaic:
            self.noStoriesMosaicView.isHidden = false
          }
          self.feedContainerView.isHidden = true
        }
      }
      return
    }
    
    for story in stories {
      guard let venue = story.venue, let location = venue.location, venue.isDataAvailable else {
        CCLog.assert("No Title, Venue or Location to Story. Skipping Story")
        return
      }
      
      let annotation = StoryMapAnnotation(title: venue.name ?? "",
                                          story: story,
                                          coordinate: CLLocationCoordinate2D(latitude: location.latitude,
                                                                             longitude: location.longitude))
      newAnnotations.append(annotation)
    }
    
    DispatchQueue.main.async {
      self.noStoriesMosaicView.isHidden = true
      self.noStoriesCarouselView.isHidden = true
      self.feedContainerView.isHidden = false
      
      self.mapNavController?.remove(annotations: self.storyAnnotations)
      self.mapNavController?.add(annotations: newAnnotations)
      self.storyAnnotations = newAnnotations
      
      if zoomToRegion {
        self.mapNavController?.showRegionExposed(containing: newAnnotations, currentLocation: coordinate)
      }
      
      self.feedCollectionNodeController.resetCollectionNode(with: stories) {
        if scrollAndSelectStory {
          self.mapNavController?.select(annotation: newAnnotations[0], animated: true)
        }
      }
      callback?()
    }
  }
  
  
  private func updateDiscoverView(onStories stories: [FoodieStory]) {
    var newAnnotations = [StoryMapAnnotation]()
    
    for story in stories {
      guard let venue = story.venue, let location = venue.location, venue.isDataAvailable else {
        CCLog.assert("No Title, Venue or Location to Story. Skipping Story")
        return
      }
      
      let annotation = StoryMapAnnotation(title: venue.name ?? "",
                                          story: story,
                                          coordinate: CLLocationCoordinate2D(latitude: location.latitude,
                                                                             longitude: location.longitude))
      newAnnotations.append(annotation)
    }
    
    DispatchQueue.main.async {
      self.mapNavController?.add(annotations: newAnnotations)
      self.storyAnnotations.append(contentsOf: newAnnotations)
    }
  }
  
  
  private func searchButtonsHidden(is hide: Bool) {
    searchButton.isHidden = hide
    carouselMapView.isHidden = hide
    
    if hide {
      allStoriesButton.isHidden = hide
    } else {
      if let user = FoodieUser.current, user.isRegistered, user.roleLevel >= FoodieRole.Level.moderator.rawValue {
        allStoriesButton.isHidden = hide
      }
    }
  }
  
  
  private func appearanceForAllUI(alphaValue: CGFloat, animated: Bool,
                                  duration: TimeInterval = FoodieGlobal.Constants.DefaultTransitionAnimationDuration) {
    appearanceForTopUI(alphaValue: alphaValue, animated: animated, duration: duration)
    appearanceForFeedUI(alphaValue: alphaValue, animated: animated, duration: duration)
  }
    
  
  private func appearanceForTopUI(alphaValue: CGFloat, animated: Bool,
                                  duration: TimeInterval = FoodieGlobal.Constants.DefaultTransitionAnimationDuration) {
    if animated {
      UIView.animate(withDuration: duration, animations: {
        self.searchStack.alpha = alphaValue
        self.middleStack.alpha = alphaValue
        self.draftButton.alpha = alphaValue
        self.carouselMapView.alpha = alphaValue
        self.currentLocationButton.alpha = alphaValue
        self.topGradientView.alpha = alphaValue
        self.backButton.alpha = alphaValue
      })
    } else {
      self.searchStack.alpha = alphaValue
      self.middleStack.alpha = alphaValue
      self.draftButton.alpha = alphaValue
      self.carouselMapView.alpha = alphaValue
      self.currentLocationButton.alpha = alphaValue
      self.topGradientView.alpha = alphaValue
      self.backButton.alpha = alphaValue
    }
  }

  
  private func appearanceForFeedUI(alphaValue: CGFloat, animated: Bool,
                                   duration: TimeInterval = FoodieGlobal.Constants.DefaultTransitionAnimationDuration) {
    if animated {
      UIView.animate(withDuration: duration, animations: {
        self.cameraButton.alpha = alphaValue
        self.profileButton.alpha = alphaValue
        self.feedBackgroundView.alpha = alphaValue
        self.feedContainerView.alpha = alphaValue
        self.noStoriesCarouselView.alpha = alphaValue
        self.noStoriesMosaicView.alpha = alphaValue
      })
    } else {
      self.cameraButton.alpha = alphaValue
      self.profileButton.alpha = alphaValue
      self.feedBackgroundView.alpha = alphaValue
      self.feedContainerView.alpha = alphaValue
      self.noStoriesCarouselView.alpha = alphaValue
      self.noStoriesMosaicView.alpha = alphaValue
    }
  }

  // MARK: - Private Instance Functions
  func showProfileView(user: FoodieUser? = nil, venue: FoodieVenue? = nil) {

    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "ProfileViewController") as? ProfileViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of ProfileViewController Class!!")
      }
      return
    }

    self.appearanceForAllUI(alphaValue: 0.0, animated: true, duration: Constants.UIDisappearanceDuration)

    if user != nil {
      viewController.user = user
    }

    if venue != nil {
      viewController.venue = venue
    }

    viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    self.pushPresent(viewController, animated: true)
  }

  func displayDeepLinkContent(displayDelay: Double = FoodieGlobal.Constants.DefaultDeepLinkWaitDelay){
    if let userId = DeepLink.global.deepLinkUserId {
      // check appdelegate if deeplink is used
      FoodieUser.getUserFor(userId: userId, withBlock: { (user, error) in
        if error != nil {
          CCLog.verbose("An error occured when looking up username: \(error!)")
          return
        }

        guard let user:FoodieUser = user as? FoodieUser else {
          CCLog.verbose("Failed to unwrap the user")
          return
        }
        UIApplication.shared.beginIgnoringInteractionEvents()
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDelay) {
           UIApplication.shared.endIgnoringInteractionEvents()
          self.showProfileView(user: user)

          if DeepLink.global.deepLinkStoryId == nil && DeepLink.global.deepLinkVenueId == nil{
            DeepLink.clearDeepLinkInfo()
          }
        }
      })
    }

    if let venueId = DeepLink.global.deepLinkVenueId {
      FoodieVenue.getVenueFor(venueId: venueId, withBlock: { (venue, error) in
        if error != nil {
          CCLog.verbose("An error occured when looking up username: \(error!)")
          return
        }

        guard let venue:FoodieVenue = venue as? FoodieVenue else {
          CCLog.verbose("Failed to unwrap the venue")
          return
        }
        UIApplication.shared.beginIgnoringInteractionEvents()
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDelay) {
          UIApplication.shared.endIgnoringInteractionEvents()
          self.showProfileView(venue: venue)

          if DeepLink.global.deepLinkStoryId == nil && DeepLink.global.deepLinkVenueId == nil{
            DeepLink.clearDeepLinkInfo()
          }
        }
      })
    }
  }
  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.accessibilityIdentifier = "discoverView"

    NotificationCenter.default.addObserver(self, selector: #selector(self.updateFeed(_:)), name: NSNotification.Name(rawValue: FoodieGlobal.RefreshFeedNotification.NotificationId), object: nil)

    // Setup the Feed Node Controller first
    let nodeController = FeedCollectionNodeController(with: .carousel, allowLayoutChange: true, adjustScrollViewInset: false)
    nodeController.roundMosaicTop = true
    addChildViewController(nodeController)
    feedContainerView.addSubview(nodeController.view)
    nodeController.view.frame = feedContainerView.bounds
    nodeController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    nodeController.didMove(toParentViewController: self)
    feedCollectionNodeController = nodeController
    feedContainerView.isHidden = true

    // Setup placeholder text for the Search text field
    guard let searchBarFont = UIFont(name: Constants.SearchBarFontName, size: Constants.SearchBarFontSize) else {
      CCLog.fatal("Cannot create UIFont with name \(Constants.SearchBarFontName)")
    }
    let placeholderString = searchField.currentTitle  //.placeholder
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .left
    
    let shadow = NSShadow()
    shadow.shadowOffset = CGSize(width: 0.0, height: 1.0)
    shadow.shadowColor = UIColor.black.withAlphaComponent(Constants.SearchBarTextShadowAlpha)
    shadow.shadowBlurRadius = 1.0
    
    let attributedText = NSAttributedString(string: placeholderString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                                                       attributes: [.font : searchBarFont,
                                                                    .foregroundColor : UIColor.white,
                                                                    .paragraphStyle : paragraphStyle,
                                                                    .shadow : shadow])
    searchField.setAttributedTitle(attributedText, for: .normal)
    searchField.setTitle(Constants.SearchBarTitle, for: .normal)

    // Setup Background Gradient Views
    let feedBackgroundBlackLevel = UIColor.black.withAlphaComponent(Constants.FeedBackgroundBlackAlpha)
    feedGradientNode = GradientNode(startingAt: CGPoint(x: 0.5, y: 1.0),
                                        endingAt: CGPoint(x: 0.5, y: 0.0),
                                        with: [feedBackgroundBlackLevel, .clear])
    feedGradientNode.isOpaque = false
    feedBackgroundView.addSubnode(feedGradientNode)

    // If current story is nil, double check and see if there are any in Local Datastore
    if FoodieStory.currentStory == nil {
      
      if let currentUser = FoodieUser.current {
        FoodieQuery.getFirstStory(byAuthor: currentUser, from: .draft) { (object, error) in
          
          if let error = error {
            FoodieObject.deleteAll(from: .draft) { deleteError in
              if let deleteError = deleteError {
                CCLog.warning("Delete All resulted in Error - \(deleteError.localizedDescription)")
              }
              AlertDialog.present(from: self, title: "Draft Resume Error", message: "Failed to resume story under draft. ='(  Problem has been logged. Please restart app for auto error report to be submitted.") { _ in
                CCLog.assert("Getting Draft Story resulted in Error. Clearing Draft Pin and Directory - \(error.localizedDescription)")
              }
            }
            return
          }
          
          guard let story = object as? FoodieStory else {
            CCLog.info("No Story found from Draft")
            return
          }

          if(!story.isEditStory) {

            let uniqueId = story.getUniqueIdentifier()

            _ = story.retrieveDigest(from: .local, type: .draft) { error in
              if let retrieveError = error  {
                self.processDraftError(error: retrieveError, id: uniqueId)
                return
              }
            }

            guard let moments = story.moments else {
              self.processDraftError(error: ErrorCode.nilMoments, id: uniqueId)
              return
            }

            for moment in moments {
              _ = moment.retrieveRecursive(from: .local, type: .draft, forceAnyways: false, for: nil) { error in
                
                if let error = error {
                  AlertDialog.present(from: self, title: "Draft Resume Error",
                                      message: "1 or more Moments have failed recovery. The Story should be preserved, but some Moments and associated Media might be lost. ='(") { _ in
                    CCLog.warning("Moment with id: \(moment.getUniqueIdentifier()) encountered an error when retrieving from draft \(error.localizedDescription)")
                  }
                  story.moments!.remove(at: (moments.index(of: moment)!))
                }
              }
            }

            FoodieStory.setCurrentStory(to: story)

            DispatchQueue.main.async {
              self.draftButton.isHidden = false
            }

          } else {
            // remove all traces of draft if previous story was an edit 
            FoodieObject.deleteAll(from: .draft) { error in
              if let deleteError = error {
                CCLog.warning("Delete All resulted in Error - \(deleteError.localizedDescription)")
              }
            }
          }
        }
      }
    }
  }

  func processDraftError(error retrieveError: Error, id storyId: String) {
    FoodieObject.deleteAll(from: .draft) { error in
      if let deleteError = error {
        CCLog.warning("Delete All resulted in Error - \(deleteError.localizedDescription)")
      }
      AlertDialog.present(from: self, title: "Draft Resume Error", message: "Failed to resume story under draft. Sorry ='(  Problem has been logged. Please restart app for auto error report to be submitted.") { action in
        CCLog.warning("Retrieve Recursive on Draft Story \(storyId) resulted in error. Clearing Draft Pin and Directory - \(retrieveError.localizedDescription)")
      }
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    var topGradientBlack: UIColor
    
    // Layout changed, so set Exposed Rect accordingly
    switch feedCollectionNodeController.layoutType {
    case .carousel:
      mapNavController?.setExposedRect(with: carouselMapView)
      topGradientBlack = UIColor.black.withAlphaComponent(Constants.TopGradientCarouselBlackAlpha)
      
    case .mosaic:
      mapNavController?.setExposedRect(with: mosaicMapView)
      topGradientBlack = UIColor.black.withAlphaComponent(Constants.TopGradientMosaicBlackAlpha)
    }
    
    // Setup Background Gradient Views
    let topGradient = GradientNode(startingAt: CGPoint(x: 0.5, y: 0.0),
                                   endingAt: CGPoint(x: 0.5, y: 1.0),
                                   with: [topGradientBlack, .clear])
    topGradient.isOpaque = false
    topGradient.frame = topGradientView.bounds
    
    if let topGradientNode = topGradientNode {
      topGradientNode.removeFromSupernode()
    }
    topGradientView.addSubnode(topGradient)
    topGradientNode = topGradient
    
    self.feedGradientNode.frame = self.feedBackgroundView.bounds
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    FoodieFetch.global.cancelAll()
    feedCollectionNodeController.delegate = self
    
    guard let mapController = navigationController as? MapNavController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("No Map Navigation Controller. Cannot Proceed")
      }
      return
    }
    
    mapNavController = mapController
    mapController.mapDelegate = self
    
    if let touchForwardingView = touchForwardingView {
      touchForwardingView.passthroughViews = [mapController.mapView]
      touchForwardingView.touchBlock = {
        self.searchField?.resignFirstResponder()
      }
    }
    
    if forceRequery {
      forceRequery = false

      guard let storyQuery = storyQuery else {
        CCLog.debug("storyQuery is nil")
        return
      }

      // requery
      storyQuery.initStoryQueryAndSearch { (stories, error) in
        self.unwrapQueryRefreshDiscoveryView(stories: stories, query: storyQuery, error: error)
      }
    }
    
    else if autoFilterSearch {
      autoFilterSearch = false
      searchWithFilter(searchButton)
    }
      
    // Resume from last map region
    else if let mapState = lastMapState {

      mapController.resumeMapState(mapState, animated: true)
      mapController.removeAllAnnotations()
      
      if storyAnnotations.count > 0 {
        mapController.add(annotations: storyAnnotations)
      }
      
      if let annotationIndex = lastSelectedAnnotationIndex {
        let annotationToSelect = storyAnnotations[annotationIndex]
        scrollSelect = true
        mapController.select(annotation: annotationToSelect, animated: true)
      }
      

    }
    
    // First time on the map. Try to get the location, and get an initial query if successful
    else {
      LocationWatch.global.get { location, error in
        if let error = error {
          AlertDialog.present(from: self, title: "Location Error", message: error.localizedDescription) { _ in
            CCLog.warning("LocationWatch.get() returned error - \(error.localizedDescription)")
          }
          mapController.showDefaultRegionExposed(animated: true)
          mapController.startTracking()
          return
        }
        
        guard let location = location else {
          AlertDialog.present(from: self, title: "Location Error", message: "Obtained invalid location information") { _ in
            CCLog.warning("LocationWatch.get() returned locaiton = nil")
          }
          mapController.showDefaultRegionExposed(animated: true)
          mapController.startTracking()
          return
        }

        self.currentLocation = location

        // Move the map to the initial location as a fallback incase the query fails
        DispatchQueue.main.async { mapController.showCurrentRegionExposed(animated: true) }
        ActivitySpinner.globalApply()
        
        // Do an Initial Search near the Current Location
        FoodieQuery.queryInitStories(at: location.coordinate, minStories: Constants.InitQueryMinStories) { (stories, query, error) in
          ActivitySpinner.globalRemove()
          self.unwrapQueryRefreshDiscoveryView(stories: stories, query: query, error: error, currentLocation: location.coordinate)
        }
        
//        let region = MKCoordinateRegionMakeWithDistance(location.coordinate, mapController.defaultMapWidth, mapController.defaultMapWidth)
//        self.performQuery(at: region.toMapRect()) { stories, query, error in
//          self.unwrapQueryRefreshDiscoveryView(stories: stories, query: query, error: error)
//        }
      }
    }
    
    // Don't bother showing the Draft Button if there's no Draft
    draftButton.isHidden = FoodieStory.currentStory == nil
    
    // Don't allow user to go to the Camera and thus Story Entry unless they are logged-in with E-mail verified
    cameraButton.isHidden = true
    cameraButton.isEnabled = false
    logoutButton.isHidden = false
    profileButton.isHidden = true
    
    // But we should refresh the user before determining for good
    if let user = FoodieUser.current, user.isRegistered {
      
      logoutButton.isHidden = true
      profileButton.isHidden = false
      cameraButton.isHidden = false
      
      user.checkIfEmailVerified { verified, error in
        if let error = error {
          
          switch error {
          case FoodieUser.ErrorCode.checkVerificationNoProperty:
            break  // This is normal if a user have just Signed-up
            
          case FoodieUser.ErrorCode.invalidSessionToken:
            AlertDialog.present(from: self, title: "Session Error", message: "Session Token is deemed invalid. Please re-login and try again") { _ in
              CCLog.warning("Session Token Invalid. Loggin User Out")
              LogOutDismiss.logOutAndDismiss(from: self)
            }
            return
            
          default:
            AlertDialog.present(from: self, title: "User Update Error", message: "Problem retrieving the most updated user profile. Some user attributes might be outdated") { _ in
              CCLog.warning("Failed retrieving the user object - \(error.localizedDescription)")
            }
          }

        } else if verified {
          DispatchQueue.main.async {
            self.cameraButton.isEnabled = true
          }
        }
      }
    }
    
    if self.feedCollectionNodeController.layoutType == .carousel {
      appearanceForTopUI(alphaValue: 1.0, animated: true)
    } else {
      UIView.animate(withDuration: FoodieGlobal.Constants.DefaultTransitionAnimationDuration, animations: {
        self.topGradientView.alpha = 1.0
        self.backButton.alpha = 1.0
      })
    }
    appearanceForFeedUI(alphaValue: 1.0, animated: true)

    // display universal search result
    if let result = searchResult {

      let keyword = searchField.currentTitle ?? ""
      let currentUserName = FoodieUser.current?.username ?? "nil"

      guard let type = result.cellType else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("CellType is nil from result")
        }
        return
      }

      switch type {

        case .location:
          var locationName = result.title.string
          if !result.detail.string.isEmpty {
            locationName = locationName +  ", " + result.detail.string
          }

          guard let mapNavController = self.mapNavController else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
              CCLog.fatal("No Map Nav Controller")
            }
            return
          }

          let clRegion = CLCircularRegion(center: mapNavController.exposedRegion.center,
                                          radius: mapNavController.exposedRegion.longitudinalMeters/2,
                                          identifier: "currentCLRegion")
          let geocoder = CLGeocoder()

          geocoder.geocodeAddressString(locationName, in: clRegion) { (placemarks, error) in

            if let error = error {
              AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
                CCLog.fatal("Geocoder returned with error: \(error.localizedDescription)")
              }
            }

            guard let placemarks = placemarks else {
              AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
                CCLog.fatal("Placemarks returned by geocoder is nil")
              }
              return
            }

            guard let location = placemarks[0].location else {
              AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
                CCLog.fatal("Location is nil")
              }
              return
            }

            Analytics.logUniversalSearchResult(username: currentUserName, keyword: keyword, location: locationName, longitude: location.coordinate.longitude, latitude: location.coordinate.latitude)

            var region: MKCoordinateRegion!
            var maxRadius: Double = 4.0

            // The coordinate in placemarks.region is highly inaccurate. So use the location coordinate when possible.
            if let coordinate = placemarks[0].location?.coordinate, let clRegion = placemarks[0].region as? CLCircularRegion {
              // Determine region via placemark.locaiton.coordinate if possible
              region = MKCoordinateRegionMakeWithDistance(coordinate, 2*clRegion.radius, 2*clRegion.radius)
              maxRadius = clRegion.radius / 1000 // convert meters to km

            } else if let coordinate = placemarks[0].location?.coordinate {
              // Determine region via placemark.location.coordinate and default max delta if clRegion is not available
              region = MKCoordinateRegionMakeWithDistance(coordinate, mapNavController.defaultMapWidth, mapNavController.defaultMapWidth)

            } else if let clRegion = placemarks[0].region as? CLCircularRegion {
              // Determine region via placemarks.region as fall back
              region = MKCoordinateRegionMakeWithDistance(clRegion.center, 2*clRegion.radius, 2*clRegion.radius)
              maxRadius = clRegion.radius / 1000 // convert meters to km
            } else {
              CCLog.assert("Placemark contained no location")
            }

            if maxRadius < 1 {
              maxRadius = 1
            }

            mapNavController.showRegionExposed(region, animated: true)
            FoodieQuery.queryInitStories(at: location.coordinate, minStories: 3, maxRadius: maxRadius){ (stories, query, error) in

              if (stories ?? []).count == 0 {
                self.searchButtonsHidden(is: false)
              } else {
                self.unwrapQueryRefreshDiscoveryView(stories: stories, query: query, error: error, currentLocation: location.coordinate)
              }
            }
          }
        break

        case .category:
          guard let category = result.category else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
              CCLog.assert("Category is nil")
            }
            return
          }

          var filter: FoodieFilter
          if let discoveryFilter = self.discoverFilter {
            filter = discoveryFilter
          } else {
            filter = FoodieFilter()
          }

          filter.selectedMealTypes.removeAll()
          filter.selectedCategories.removeAll()
          FoodieCategory.setAllSelection(to: .unselected)

          guard let foursquareId = category.foursquareCategoryID else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
              CCLog.fatal("FoursquareCategory ID is missing")
            }
            return
          }

          if FoodieCategory.list.index(forKey: foursquareId) != nil {
            FoodieCategory.list[foursquareId]!.setSelectionRecursive(to: .selected)

            for (_ ,category) in FoodieCategory.list {
              if category.selected == .selected {
                filter.selectedCategories.append(category)
              }
            }

          } else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
              CCLog.fatal("The foodiecategory with foursquareid: \(foursquareId) is missing from the FoodieCategory list")
            }
            return
          }

          Analytics.logUniversalSearchResult(username: currentUserName, keyword: keyword, categoryIDs: filter.selectedCategories.map( { $0.foursquareCategoryID ?? "" }))

          filterCompleteReturn(filter, true)
          searchWithFilter(searchButton)
        break

        case .meal:
          guard let meal = result.meal else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
              CCLog.assert("Meal is nil")
            }
            return
          }
          var filter: FoodieFilter
          if let discoveryFilter = self.discoverFilter {
            filter = discoveryFilter
          } else {
            filter = FoodieFilter()
          }

          filter.selectedCategories.removeAll()
          filter.selectedMealTypes.removeAll()
          filter.selectedMealTypes.append(meal)

          Analytics.logUniversalSearchResult(username: currentUserName, keyword: keyword, mealTypes: filter.selectedMealTypes.map( { $0.rawValue }))

          filterCompleteReturn(filter, true)
          searchWithFilter(searchButton)
        break

       case .story:
         guard let story = result.story else {
             AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
             CCLog.assert("Story is nil")
           }
           return
         }

         guard let user:FoodieUser = story.author else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("Foodiestory's author is nil")
          }
          return
         }

         Analytics.logUniversalSearchResult(username: currentUserName, keyword: keyword, storyID: story.objectId ?? "", title: story.title ?? "")

         // show story as in it was a deepLink
         DeepLink.global.deepLinkUserId = user.objectId
         DeepLink.global.deepLinkStoryId = story.objectId

         UIApplication.shared.beginIgnoringInteractionEvents()
         DispatchQueue.main.asyncAfter(deadline: .now() +  FoodieGlobal.Constants.DefaultDeepLinkWaitDelay) {
          UIApplication.shared.endIgnoringInteractionEvents()
          self.showProfileView(user: user)

          if DeepLink.global.deepLinkStoryId == nil && DeepLink.global.deepLinkVenueId == nil{
            DeepLink.clearDeepLinkInfo()
          }
         }
       break

       case .user:
         guard let user = result.user else {
             AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
             CCLog.assert("User is nil")
           }
           return
         }

         Analytics.logUniversalSearchResult(username: currentUserName, keyword: keyword, authorID: user.objectId ?? "", authorUserName: user.username ?? "", authorFullName: user.fullName ?? "")
         self.showProfileView(user: user)
       break

       case .venue:
         guard let venue = result.venue else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
              CCLog.assert("Venue is nil")
            }
            return
         }
         Analytics.logUniversalSearchResult(username: currentUserName, keyword: keyword, venueID: venue.objectId ?? "", venueName: venue.name ?? "")
         self.showProfileView(venue: venue)
       break
       }

      // clear the result after display
      self.searchResult = nil
    }
  }
  
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  
  override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
    return .fade
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Let's disconnect the FeedCollectionNode's events before disappearing
    feedCollectionNodeController.delegate = nil
    
    // Keep track of what the location is before we disappear
    if let mapNavController = mapNavController {
      // Save the Map Region to resume when we get back to this view next time around
      lastMapState = mapNavController.currentMapState
      if let selectedAnnotation = mapNavController.selectedAnnotation,
        let annotationIndex = storyAnnotations.index(where: { $0 === selectedAnnotation }) {
        lastSelectedAnnotationIndex = annotationIndex
      } else {
        lastSelectedAnnotationIndex = nil
      }
      
      // Release the mapNavController
      mapNavController.stopTracking()
      
      if mapNavController.mapDelegate === self {
        mapNavController.mapDelegate = nil
      }
      
      self.mapNavController = nil
    }
  }
}

extension DiscoverViewController: FeedCollectionNodeDelegate {
  
  func collectionNodeLayoutChanged(to layoutType: FeedCollectionNodeController.LayoutType) {
    
    switch layoutType {
    case .mosaic:
      
      // Hide top buttons
      appearanceForTopUI(alphaValue: 0.0, animated: true)
      
      topGradientCarouselConstraint.isActive = false
      feedBackgroundCarouselConstraint.isActive = false
      topGradientMosaicConstraint.isActive = true
      feedBackgroundMosaicConstraint.isActive = true
      
      touchForwardingMosaicConstraint.isActive = true
      touchForwardingCarouselConstraint.isActive = false
      touchForwardingHeightConstraint.isActive = false
      
      view.updateConstraintsIfNeeded()
      topGradientView.layoutIfNeeded()
      feedBackgroundView.layoutIfNeeded()
      touchForwardingView?.layoutIfNeeded()
      
      UIView.animate(withDuration: FoodieGlobal.Constants.DefaultTransitionAnimationDuration, animations: {
        self.topGradientView.alpha = 1.0
        self.backButton.alpha = 1.0
        self.backButton.isHidden = false
      })
      
      if let highlightedStoryIndex = highlightedStoryIndex {
        DispatchQueue.main.asyncAfter(deadline: .now() + FoodieGlobal.Constants.DefaultTransitionAnimationDuration/2) {
          self.feedCollectionNodeController.scrollTo(storyIndex: highlightedStoryIndex)
          self.collectionNodeDidStopScrolling()
        }
      }
      
    case .carousel:

      feedCollectionNodeController.clearSelectionFrame()
      mosaicLayoutChangePanRecognizer.isEnabled = true
      backButton.isHidden = true
      
      // Should we show top buttons?
      appearanceForTopUI(alphaValue: 1.0, animated: true)
      
      topGradientMosaicConstraint.isActive = false
      feedBackgroundMosaicConstraint.isActive = false
      topGradientCarouselConstraint.isActive = true
      feedBackgroundCarouselConstraint.isActive = true
      
      touchForwardingMosaicConstraint.isActive = false
      touchForwardingCarouselConstraint.isActive = true
      touchForwardingHeightConstraint.isActive = true
      
      view.updateConstraintsIfNeeded()
      topGradientView.layoutIfNeeded()
      feedBackgroundView.layoutIfNeeded()
      touchForwardingView?.layoutIfNeeded()
      
      DispatchQueue.main.asyncAfter(deadline: .now() + FoodieGlobal.Constants.DefaultTransitionAnimationDuration/2) {
        if self.storyAnnotations.count > 0 {
          self.mapNavController?.showRegionExposed(containing: self.storyAnnotations)
        }
        
        if let highlightedStoryIndex = self.highlightedStoryIndex {
          self.feedCollectionNodeController.scrollTo(storyIndex: highlightedStoryIndex)
        }
      }
    }
  }
  
  
  func collectionNodeDidStopScrolling() {
    
    if let storyIndex = self.feedCollectionNodeController.highlightedStoryIndex, storyIndex >= 0, storyIndex < storyArray.count {
      self.highlightedStoryIndex = storyIndex
      
      for annotation in self.storyAnnotations {
        if annotation.story === self.storyArray[storyIndex] {
          self.lastSelectedAnnotationIndex = self.storyAnnotations.index(where: {$0 === annotation})
          
          switch feedCollectionNodeController.layoutType {
          case .mosaic:
            let mapWidth = MapNavController.Constants.DefaultMinMapWidth
            let mosaicMapAspectRatio = mosaicMapView.bounds.width/mosaicMapView.bounds.height
            let mapHeight = mapWidth/CLLocationDistance(mosaicMapAspectRatio)
            let region = MKCoordinateRegionMakeWithDistance(annotation.coordinate, mapHeight/2, mapWidth/2)  // divided by 2 is hand tuned
            mapNavController?.showRegionExposed(region, animated: true)
            feedCollectionNodeController.showSelectionFrameAround(storyIndex: storyIndex)
            
          case .carousel:
            // TODO: Does the exposed map already show the annotation? Only zoom to all annotations if not already shown
            if let mapController = mapNavController {
              if mapController.isAnnotationExposed(annotation) {
                
                // Is annotation already currently in exposed map? If so only change the map if the current map view is bigger than needed
                if self.storyAnnotations.count > 0 {
                  mapController.showRegionExposed(containing: self.storyAnnotations, onlyIfCurrentTooBig: true)
                }
              } else {
                
                // If annotation is not shown, just go and show all the annotations
                if self.storyAnnotations.count > 0 {
                  mapController.showRegionExposed(containing: self.storyAnnotations)
                }
              }
            }
            searchButtonsHidden(is: true)
          }
          
          if let mapController = mapNavController,  annotation != mapController.selectedAnnotation as? StoryMapAnnotation {
            scrollSelect = true
            mapNavController?.select(annotation: annotation, animated: true)
          }
        }
      }
    }
      
    // Do Prefetching? In reality doing this slows down the whole app. And assets don't seem to be ready any quicker.... If not slower all together.....
    let storiesIndexes = self.feedCollectionNodeController.getStoryIndexesVisible(forOver: Constants.PercentageOfStoryVisibleToStartPrefetch)
    if storiesIndexes.count > 0 {
      var storiesShouldPrefetch = [FoodieStory]()
        
      for storyIndex in storiesIndexes {
        if storyIndex >= 0, storyIndex < self.storyArray.count {
          storiesShouldPrefetch.append(self.storyArray[storyIndex])
        }
      }
        
      if storiesShouldPrefetch.count > 0 {
        FoodieFetch.global.cancelAllBut(storiesShouldPrefetch)
      }
    }
  }
  
  
  func collectionNodeNeedsNextDataPage(for context: AnyObject?) {
    
    guard let query = storyQuery else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
        CCLog.assert("Expected there to be a pre-existing Query")
        self.searchWithFilter(self.searchButton)
      }
      return
    }
    
    CCLog.info("CollectionNodeNeedsNextDataPage")
    
    query.getNextStories(for: FoodieGlobal.Constants.StoryFeedPaginationCount) { stories, error in
      
      if let error = error {
        AlertDialog.present(from: self, title: "Pagination Error", message: error.localizedDescription) { _ in
          CCLog.warning("query.getNextStories resulted in error - \(error.localizedDescription)")
        }
        return
      }
      
      guard let stories = stories, stories.count > 0 else {
        CCLog.warning("No addtional Stories returned. Just set isLastPage and return")
        self.feedCollectionNodeController.updateDataPage(withStory: [], for: context, isLastPage: true)
        return
      }
      
      let previousCount = self.storyArray.count
      let newCount = previousCount + min(stories.count, FoodieGlobal.Constants.StoryFeedPaginationCount)
      let newIndexes = Array(previousCount...newCount-1)
      let isLastPage = stories.count < FoodieGlobal.Constants.StoryFeedPaginationCount
      
      self.storyArray.append(contentsOf: stories)
      self.feedCollectionNodeController.storyArray = self.storyArray
      self.feedCollectionNodeController.updateDataPage(withStory: newIndexes, for: context, isLastPage: isLastPage)
      self.updateDiscoverView(onStories: stories)
    }
  }
}


extension DiscoverViewController: MapNavControllerDelegate {
  
  func mapNavController(_ mapNavController: MapNavController, didSelect annotation: MKAnnotation) {
    
    if scrollSelect {
      scrollSelect = false
    }
      
    else if let storyAnnotation = annotation as? StoryMapAnnotation {
      for index in 0..<storyArray.count {
        if storyAnnotation.story === storyArray[index] {
          feedCollectionNodeController.scrollTo(storyIndex: index)
          break
        }
      }
    }
  }
  
  
  func mapNavControllerWasMovedByUser(_ mapNavController: MapNavController) {
    mapNavController.stopTracking()
    
    if feedCollectionNodeController.layoutType == .carousel {
      searchButtonsHidden(is: false)
    }
  }
}


extension DiscoverViewController: CameraReturnDelegate {
  func captureComplete(markedupMoments: [FoodieMoment], suggestedStory: FoodieStory?) {
    DispatchQueue.main.async {  // UI Work. We don't know which thread we might be in, so guarentee execute in Main thread
      self.dismiss(animated: true) {  // This dismiss is for the CameraViewController to call on
        
        let storyboard = UIStoryboard(name: "Compose", bundle: nil)
        guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryEntryViewController") as? StoryEntryViewController else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("ViewController initiated not of StoryEntryViewController Class!!")
          }
          return
        }
        var workingStory: FoodieStory?
        
        if let story = suggestedStory {
          workingStory = story
        } else if let story = FoodieStory.currentStory {
          workingStory = story
        } else {
          workingStory = FoodieStory()
        }
        
        viewController.workingStory = workingStory!
        viewController.returnedMoments = markedupMoments
        self.appearanceForAllUI(alphaValue: 0.0, animated: true, duration: Constants.UIDisappearanceDuration)
        viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
        self.pushPresent(viewController, animated: true)  // This pushPresent is from the DiscoverViewController to present the Entry VC
      }
    }
  }
}

extension DiscoverViewController: FiltersViewReturnDelegate {
  func filterCompleteReturn(_ filter: FoodieFilter, _ performSearch: Bool) {
    discoverFilter = filter
    
    if discoverFilter!.isDefault {
      filterButton.setImage(UIImage(named: "Discover-FilterButton-Off"), for: .normal)
    } else {
      filterButton.setImage(UIImage(named: "Discover-FilterButton-On"), for: .normal)
    }
    
    if performSearch {
      autoFilterSearch = true
    } else {
      searchButtonsHidden(is: false)
    }
  }
}

extension DiscoverViewController: SearchResultDisplayDelegate {
  func showSearchResult(result: SearchResult, keyword: String) {
    self.searchResult = result
    self.searchField.setTitle(keyword, for: .normal)
  }

  func clearSearchKeyWord() {
    self.searchField.setTitle(Constants.SearchBarTitle, for: .normal)
  }
}
