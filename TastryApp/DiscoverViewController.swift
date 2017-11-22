//
//  DiscoverViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-03-20.
//  Copyright © 2017 Tastry. All rights reserved.
//

import AsyncDisplayKit
import CoreLocation

class DiscoverViewController: OverlayViewController {

  // MARK: - Error Types
  enum ErrorCode: LocalizedError {
    
    case mapQueryExceededMaxLat
    case queryNilStory
    
    var errorDescription: String? {
      switch self {
      case .mapQueryExceededMaxLat:
        return NSLocalizedString("Exceeded allowed maximum number of degrees latitude for map query", comment: "Error description for a Map View Controller Query")
      case .queryNilStory:
        return NSLocalizedString("Create Story Query & Search returned no errors but nil Story Array", comment: "Error description for a Map View Controller Query")
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
    static let PullTranslationForChange: CGFloat = 50.0  // In Points
    static let PercentageOfStoryVisibleToStartPrefetch: CGFloat = 0.7
    static let BackgroundBlackAlpha: CGFloat = 0.7
    static let SearchBackgroundBlackAlpha: CGFloat = 0.5
    static let FeedBackgroundBlackAlpha: CGFloat = 0.7
    static let SearchBarFontName = FoodieFont.Raleway.SemiBold
    static let SearchBarFontSize: CGFloat = 15.0
    static let SearchBarTextShadowAlpha: CGFloat = 0.25
    static let SearchBarPlaceholderColor = UIColor.lightGray
  }

  

  // MARK: - Private Instance Variables
  private var feedCollectionNodeController: FeedCollectionNodeController!
  private var mapNavController: MapNavController?
  
  private var lastMapRegion: MKCoordinateRegion?
  private var lastMapWasTracking: Bool = false
  private var lastSelectedAnnotationIndex: Int?
  private var highlightedStoryIndex: Int?
  private var mosaicMapWidth: CLLocationDistance?
  private var initialLayout = true
  
  private var storyQuery: FoodieQuery?
  private var storyArray = [FoodieStory]()
  private var storyAnnotations = [StoryMapAnnotation]()
  
  private var searchGradientNode: GradientNode!
  private var feedGradientNode: GradientNode!
  
  
  // MARK: - IBOutlets
  
  @IBOutlet weak var mosaicLayoutChangePanRecognizer: UIPanGestureRecognizer!
  @IBOutlet weak var carouselLayoutChangeTapRecognizer: UITapGestureRecognizer!
  
  @IBOutlet weak var locationField: UITextField!
  @IBOutlet weak var draftButton: UIButton!
  @IBOutlet weak var currentLocationButton: UIButton!
  @IBOutlet weak var cameraButton: UIButton!
  @IBOutlet weak var logoutButton: UIButton!
  @IBOutlet weak var profileButton: UIButton!
  @IBOutlet weak var searchButton: UIButton!
  @IBOutlet weak var allStoriesButton: UIButton!
  
  @IBOutlet weak var touchForwardingView: TouchForwardingView? {
    didSet {
      if let touchForwardingView = touchForwardingView, let mapNavController = navigationController as? MapNavController {
        touchForwardingView.passthroughViews = [mapNavController.mapView]
        touchForwardingView.touchBlock = {
          self.locationField?.resignFirstResponder()
        }
      }
    }
  }
  
  @IBOutlet weak var searchBackgroundView: UIView!
  @IBOutlet weak var feedContainerView: UIView!
  @IBOutlet weak var mosaicMapView: UIView!
  @IBOutlet weak var carouselMapView: UIView!
  @IBOutlet weak var feedBackgroundView: UIView!
  
  @IBOutlet weak var searchStack: UIStackView!
  @IBOutlet weak var middleStack: UIStackView!
  
  @IBOutlet weak var noStoriesMosaicView: UIImageView!
  @IBOutlet weak var noStoriesCarouselView: UIView!
  
  @IBOutlet var searchBackgroundMosaicConstraint: NSLayoutConstraint!
  @IBOutlet var searchBackgroundCarouselConstraint: NSLayoutConstraint!
  
  @IBOutlet var feedBackgroundCarouselConstraint: NSLayoutConstraint!
  @IBOutlet var feedBackgroundMosaicConstraint: NSLayoutConstraint!
  
  
  
  // MARK: - IBActions
  
  @IBAction func launchDraftStory(_ sender: Any) {
    // This is used for viewing the draft story to be used with update story later
    // Hide the button as needed, due to problems with empty draft story and saving an empty story is problematic
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryCompositionViewController") as? StoryCompositionViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of StoryCompositionViewController Class!!")
      }
      return
    }

    if FoodieStory.currentStory == nil {
      viewController.workingStory =  FoodieStory.newCurrent()
    } else {
      viewController.workingStory = FoodieStory.currentStory
    }
    
    appearanceForAllUI(alphaValue: 0.0, animated: true)
    viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func launchCamera(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "CameraViewController") as? CameraViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of CameraViewController Class!!")
      }
      return
    }
    
    appearanceForAllUI(alphaValue: 0.0, animated: true)
    
    viewController.cameraReturnDelegate = self
    present(viewController, animated: true)  // Use regular present for the Camera for now. Not including the camera as part of the MapNavController for now
  }
  
  
  @IBAction func currentLocationReturn(_ sender: UIButton) {
    // Clear the text field while at it
    locationField?.text = ""
    mapNavController?.showCurrentRegionExposed(animated: true)
  }
  
  
  @IBAction func searchWithFilter(_ sender: UIButton) {
    
    performQuery { stories, query, error in
      if let error = error {
        if let error = error as? ErrorCode, error == .mapQueryExceededMaxLat {
          AlertDialog.present(from: self, title: "Search Area Too Large", message: "The maximum search distance for a side is 100km. Please reduce the range and try again")
        } else {
          AlertDialog.present(from: self, title: "Story Query Error", message: error.localizedDescription) { action in
            CCLog.assert("Story Query resulted in Error - \(error.localizedDescription)")
          }
        }
        return
      }
      
      guard let stories = stories else {
        AlertDialog.present(from: self, title: "Story Query Error", message: "Story Query did not produce Stories") { action in
          CCLog.assert("Story Query resulted in nil")
        }
        return
      }
      
      self.storyQuery = query
      self.storyArray = stories
      self.searchButton.isHidden = true
      self.allStoriesButton.isHidden = true
      self.refreshDiscoverView(onStories: stories, zoomToRegion: true, scrollAndSelectStory: true)
    }
  }
  
  
  @IBAction func allStories(_ sender: UIButton) {
    
    performQuery(onAllUsers: true) { stories, query, error in
      if let error = error {
        if let error = error as? ErrorCode, error == .mapQueryExceededMaxLat {
          AlertDialog.present(from: self, title: "Search Area Too Large", message: "Max search distance for a side is 100km. Please reduce the range and try again")
        } else {
          AlertDialog.present(from: self, title: "Story Query Error", message: error.localizedDescription) { action in
            CCLog.assert("Story Query resulted in Error - \(error.localizedDescription)")
          }
        }
        return
      }
      
      guard let stories = stories else {
        AlertDialog.present(from: self, title: "Story Query Error", message: "Story Query did not produce Stories") { action in
          CCLog.assert("Story Query resulted in storyArray = nil")
        }
        return
      }
      
      self.storyQuery = query
      self.storyArray = stories
      self.searchButton.isHidden = true
      self.allStoriesButton.isHidden = true
      self.refreshDiscoverView(onStories: stories, zoomToRegion: true, scrollAndSelectStory: true)
    }
  }
  
  
  @IBAction func logOutAction(_ sender: UIButton) {
    LogOutDismiss.askDiscardIfNeeded(from: self)
  }
  
  
  @IBAction func profileAction(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "ProfileViewController") as? ProfileViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of ProfileViewController Class!!")
      }
      return
    }
    
    appearanceForAllUI(alphaValue: 0.0, animated: true)
    
    viewController.user = FoodieUser.current
    viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
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
          touchForwardingView?.isHidden = true
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
  
  
  @IBAction func carouselLayoutChangeAction(_ tapGesture: UITapGestureRecognizer) {
    carouselLayoutChangeTapRecognizer.isEnabled = false
    feedCollectionNodeController.changeLayout(to: .carousel, animated: true)
  }
  
  
  
  // MARK: - Class Private Functions
  
  private func locationPermissionDeniedDialog() {
    if self.presentedViewController == nil {
      // Permission was denied before. Ask for permission again
      guard let url = URL(string: UIApplicationOpenSettingsURLString) else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.fatal("UIApplicationOPenSettignsURLString ia an invalid URL String???")
        }
        return
      }
      
      let alertController = UIAlertController(title: "Location Services Disabled",
                                              titleComment: "Alert diaglogue title when user has denied access to location services",
                                              message: "Please go to Settings > Privacy > Location Services and set this App's Location Access permission to 'While Using'",
                                              messageComment: "Alert dialog message when the user has denied access to location services",
                                              preferredStyle: .alert)
      
      alertController.addAlertAction(title: "Settings",
      comment: "Alert diaglogue button to open Settings, hoping user will enable access to Location Services",
      style: .default) { action in UIApplication.shared.open(url, options: [:]) }
      
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  
  private func performQuery(onAllUsers: Bool = false, at mapRect: MKMapRect? = nil, withBlock callback: FoodieQuery.StoriesQueryBlock?) {
    
    var searchMapRect = MKMapRect()
    
    if mapRect == nil {
      guard let mapController = mapNavController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
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
    
    if !onAllUsers {
      // Add Filter so only Post by Users > Limited User && Posts by Yourself can be seen
      query.addRoleFilter(min: .user, max: nil)
      
      if let currentUser = FoodieUser.current, currentUser.isRegistered {
        query.addAuthorsFilter(users: [currentUser])
      }
    }
    
    query.setSkip(to: 0)
    query.setLimit(to: FoodieGlobal.Constants.StoryFeedPaginationCount)
    _ = query.addArrangement(type: .creationTime, direction: .descending) // TODO: - Should this be user configurable? Or eventualy we need a seperate function/algorithm that determins feed order

    let activitySpinner = ActivitySpinner(addTo: view)
    activitySpinner.apply()
    
    // Actually do the Query
    query.initStoryQueryAndSearch { (stories, error) in
      
      activitySpinner.remove()
      
      if let error = error {
        AlertDialog.present(from: self, title: "Query Failed", message: error.localizedDescription) { action in
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
  
  
  private func refreshDiscoverView(onStories stories: [FoodieStory], zoomToRegion: Bool, scrollAndSelectStory: Bool) {
    
    var newAnnotations = [StoryMapAnnotation]()
    var outstandingStoryRetrieval = stories.count
    
    if outstandingStoryRetrieval <= 0 {
      DispatchQueue.main.async {
        self.mapNavController?.remove(annotations: self.storyAnnotations)
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
      _ = story.retrieveDigest(from: .both, type: .cache) { error in
        outstandingStoryRetrieval -= 1
        
        if let error = error {
          AlertDialog.present(from: self, title: "Story Retrieve Error", message: "Failed to retrieve Story Digest - \(error.localizedDescription)") { action in
            CCLog.warning("Failed to retrieve Story Digest via story.retrieveDigest. Error - \(error.localizedDescription)")
          }
          return
        }
      
        guard let venue = story.venue, let location = venue.location, venue.isDataAvailable else {
          CCLog.assert("No Title, Venue or Location to Story. Skipping Story")
          return
        }
        
        let annotation = StoryMapAnnotation(title: venue.name ?? "",
                                            story: story,
                                            coordinate: CLLocationCoordinate2D(latitude: location.latitude,
                                                                               longitude: location.longitude))
        newAnnotations.append(annotation)
        
        if outstandingStoryRetrieval == 0 {
          DispatchQueue.main.async {
            self.noStoriesMosaicView.isHidden = true
            self.noStoriesCarouselView.isHidden = true
            self.feedContainerView.isHidden = false
            
            self.mapNavController?.remove(annotations: self.storyAnnotations)
            self.mapNavController?.add(annotations: newAnnotations)
            self.storyAnnotations = newAnnotations
            
            if zoomToRegion {
              self.mapNavController?.showRegionExposed(containing: newAnnotations)
            }
            
            self.feedCollectionNodeController.resetCollectionNode(with: stories) {
              if scrollAndSelectStory {
                self.feedCollectionNodeController.scrollTo(storyIndex: 0)
              }
            }
          }
        }
      }
    }
  }
  
  
  private func appearanceForAllUI(alphaValue: CGFloat, animated: Bool) {
    appearanceForTopUI(alphaValue: alphaValue, animated: animated)
    appearanceForFeedUI(alphaValue: alphaValue, animated: animated)
  }
    
  
  private func appearanceForTopUI(alphaValue: CGFloat, animated: Bool) {
    if animated {
      UIView.animate(withDuration: FoodieGlobal.Constants.DefaultTransitionAnimationDuration, animations: {
        self.searchStack.alpha = alphaValue
        self.middleStack.alpha = alphaValue
        self.draftButton.alpha = alphaValue
        self.currentLocationButton.alpha = alphaValue
      })
    } else {
      self.searchStack.alpha = alphaValue
      self.middleStack.alpha = alphaValue
      self.draftButton.alpha = alphaValue
      self.currentLocationButton.alpha = alphaValue
    }
  }

  
  private func appearanceForFeedUI(alphaValue: CGFloat, animated: Bool) {
    if animated {
      UIView.animate(withDuration: FoodieGlobal.Constants.DefaultTransitionAnimationDuration, animations: {
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
  
  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Setup the Feed Node Controller first
    let nodeController = FeedCollectionNodeController(with: .carousel, allowLayoutChange: true, adjustScrollViewInset: false)
    addChildViewController(nodeController)
    feedContainerView.addSubview(nodeController.view)
    nodeController.view.frame = feedContainerView.bounds
    nodeController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    nodeController.didMove(toParentViewController: self)
    feedCollectionNodeController = nodeController
    nodeController.delegate = self
    carouselLayoutChangeTapRecognizer.isEnabled = false
    
    // Setup all the IBOutlet Delegates
    locationField?.delegate = self
    
    // Setup placeholder text for the Search text field
    guard let searchBarFont = UIFont(name: Constants.SearchBarFontName, size: Constants.SearchBarFontSize) else {
      CCLog.fatal("Cannot create UIFont with name \(Constants.SearchBarFontName)")
    }
    let placeholderString = locationField.placeholder
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .left
    
    let shadow = NSShadow()
    shadow.shadowOffset = CGSize(width: 0.0, height: 1.0)
    shadow.shadowColor = UIColor.black.withAlphaComponent(Constants.SearchBarTextShadowAlpha)
    shadow.shadowBlurRadius = 1.0
    
    let attributedPlaceholderText = NSAttributedString(string: placeholderString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                                                       attributes: [.font : searchBarFont,
                                                                    .foregroundColor : UIColor.white,
                                                                    .paragraphStyle : paragraphStyle,
                                                                    .shadow : shadow])
    
    locationField.attributedPlaceholder = attributedPlaceholderText
    locationField.defaultTextAttributes = [NSAttributedStringKey.paragraphStyle.rawValue : paragraphStyle, NSAttributedStringKey.shadow.rawValue : shadow]
    locationField.typingAttributes = [NSAttributedStringKey.font.rawValue : searchBarFont,
                                      NSAttributedStringKey.foregroundColor.rawValue : UIColor.white,
                                      NSAttributedStringKey.paragraphStyle.rawValue : paragraphStyle,
                                      NSAttributedStringKey.shadow.rawValue : shadow]
    locationField.font = searchBarFont
    locationField.textColor = .white
    
    
    // Setup Background Gradient Views
    let searchBackgroundBlackLevel = UIColor.black.withAlphaComponent(Constants.SearchBackgroundBlackAlpha)
    searchGradientNode = GradientNode(startingAt: CGPoint(x: 0.5, y: 0.0),
                                          endingAt: CGPoint(x: 0.5, y: 1.0),
                                          with: [searchBackgroundBlackLevel, .clear])
    searchGradientNode.isOpaque = false
    searchBackgroundView.addSubnode(searchGradientNode)
    
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
              AlertDialog.present(from: self, title: "Draft Resume Error", message: "Failed to resume story under draft. Sorry ='(  Problem has been logged. Please restart app for auto error report to be submitted.") { action in
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
            story.retrieveRecursive(from: .local, type: .draft, forceAnyways: false, for: nil) { error in

              if let retrieveError = error {
                FoodieObject.deleteAll(from: .draft) { error in
                  if let deleteError = error {
                    CCLog.warning("Delete All resulted in Error - \(deleteError.localizedDescription)")
                  }
                  AlertDialog.present(from: self, title: "Draft Resume Error", message: "Failed to resume story under draft. Sorry ='(  Problem has been logged. Please restart app for auto error report to be submitted.") { action in
                    CCLog.warning("Retrieve Recursive on Draft Story \(story.getUniqueIdentifier()) resulted in error. Clearing Draft Pin and Directory - \(retrieveError.localizedDescription)")
                  }
                }
                return
              }

              FoodieStory.setCurrentStory(to: story)

              DispatchQueue.main.async {
                self.draftButton.isHidden = false
              }
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

  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    searchGradientNode.frame = searchBackgroundView.bounds
    feedGradientNode.frame = feedBackgroundView.bounds

    
    // Layout changed, so set Exposed Rect accordingly
    switch feedCollectionNodeController.layoutType {
    case .carousel:
      mapNavController?.setExposedRect(with: carouselMapView)
      
    case .mosaic:
      mapNavController?.setExposedRect(with: mosaicMapView)
    }
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
 
    FoodieFetch.global.cancelAll()
    
    guard let mapController = navigationController as? MapNavController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("No Map Navigation Controller. Cannot Proceed")
      }
      return
    }
    
    mapNavController = mapController
    mapController.mapDelegate = self
    
    if let touchForwardingView = touchForwardingView {
      touchForwardingView.passthroughViews = [mapController.mapView]
      touchForwardingView.touchBlock = {
        self.locationField?.resignFirstResponder()
      }
    }
    
    // Resume from last map region
    if let mapRegion = lastMapRegion {
      mapController.showRegionExposed(mapRegion, animated: true)
      
      if lastMapWasTracking {
        mapController.startTracking()
      }
      
      if let annotationIndex = lastSelectedAnnotationIndex {
        let annotationToSelect = storyAnnotations[annotationIndex]
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
        
        // Move the map to the initial location as a fallback incase the query fails
        DispatchQueue.main.async { mapController.showCurrentRegionExposed(animated: true) }

        let region = MKCoordinateRegionMakeWithDistance(location.coordinate, mapController.defaultMapWidth, mapController.defaultMapWidth)
        
        // Do an Initial Search near the Current Location
        self.performQuery(at: region.toMapRect()) { stories, query, error in
          if let error = error {
            if let error = error as? ErrorCode, error == .mapQueryExceededMaxLat {
              AlertDialog.present(from: self, title: "Search Area Too Large", message: "The maximum search distance for a side is 100km. Please reduce the range and try again")
            } else {
              AlertDialog.present(from: self, title: "Story Query Error", message: error.localizedDescription) { action in
                CCLog.assert("Story Query resulted in Error - \(error.localizedDescription)")
              }
            }
            return
          }
          
          guard let stories = stories else {
            AlertDialog.present(from: self, title: "Story Query Error", message: "Story Query did not produce Stories") { action in
              CCLog.assert("Story Query resulted in nil")
            }
            return
          }
          
          self.storyQuery = query
          self.storyArray = stories
          self.refreshDiscoverView(onStories: stories, zoomToRegion: true, scrollAndSelectStory: true)
        }
      }
    }
    
    // Don't bother showing the Draft Button if there's no Draft
    draftButton.isHidden = FoodieStory.currentStory == nil
    
    // Don't allow user to go to the Camera and thus Story composition unless they are logged-in with E-mail verified
    cameraButton.isHidden = true
    logoutButton.isHidden = false
    profileButton.isHidden = true
    
    // But we should refresh the user before determining for good
    if let user = FoodieUser.current, user.isRegistered {
      
      logoutButton.isHidden = true
      profileButton.isHidden = false
      
      user.checkIfEmailVerified { verified, error in
        if let error = error {
          
          switch error {
          case FoodieUser.ErrorCode.checkVerificationNoProperty:
            break  // This is normal if a user have just Signed-up
          default:
            AlertDialog.present(from: self, title: "User Update Error", message: "Problem retrieving the most updated user profile. Some user attributes might be outdated") { action in
              CCLog.warning("Failed retrieving the user object - \(error.localizedDescription)")
            }
          }

        } else if verified {
          DispatchQueue.main.async {
            self.cameraButton.isHidden = false
          }
        }
      }
    }
    
    if self.feedCollectionNodeController.layoutType == .carousel {
      appearanceForTopUI(alphaValue: 1.0, animated: true)
    }
    appearanceForFeedUI(alphaValue: 1.0, animated: true)
    setNeedsStatusBarAppearanceUpdate()
  }
  
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  
  override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
    return .fade
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Keep track of what the location is before we disappear
    if let mapNavController = mapNavController {
      // Save the Map Region to resume when we get back to this view next time around
      lastMapRegion = mapNavController.exposedRegion
      lastMapWasTracking = mapNavController.isTracking
      if let selectedAnnotation = mapNavController.selectedAnnotation,
        let annotationIndex = storyAnnotations.index(where: { $0 === selectedAnnotation }) {
        lastSelectedAnnotationIndex = annotationIndex
      } else {
        lastSelectedAnnotationIndex = nil
      }
      
      // Release the mapNavController
      mapNavController.stopTracking()
      mapNavController.mapDelegate = nil
      self.mapNavController = nil
    }
  }
}



extension DiscoverViewController: UITextFieldDelegate {

  // TODO: textFieldShouldReturn, implement Dynamic Filter Querying with another Geocoder
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    
    // DEBUG: Forces a Crash!!!!!
    if let text = textField.text {
      if text == "CrashRightNow" {
        CCLog.fatal("CrashRightNow Force Crash Triggered!!!")
      }
    }
    
    guard let mapNavController = mapNavController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("No Map Nav Controller")
      }
      return true
    }
    
    guard let location = textField.text else {
      // No text in location field
      return true
    }
    
    let clRegion = CLCircularRegion(center: mapNavController.exposedRegion.center,
                                    radius: mapNavController.exposedRegion.longitudinalMeters/2,
                                    identifier: "currentCLRegion")
    let geocoder = CLGeocoder()

    geocoder.geocodeAddressString(location, in: clRegion) { (placemarks, error) in

      if let error = error as? CLError {
        switch error.code {
        case .geocodeFoundNoResult:
          textField.text = "No Results Found"
          textField.textColor = UIColor.red
          return

        default:
          CCLog.assert("geocodeAddressString Error Handle, CLError Code - \(error)")
        }
      }

      guard let placemarks = placemarks else {

        CCLog.info("User Error - No Placemark found from location entered into text field by User")

        // No valid placemarks returned
        textField.text = "No Results Found"
        textField.textColor = UIColor.red
        return
      }

      // Create String to be shown back to User in the locationField
      var textArray = [String]()

      if let text = placemarks[0].name {
        textArray.append(text)
      }

      // Remove 'thoroughfare' if there is already a 'name'
      // eg. Don't need Grouse Mountain at Nancy Green Way. Just Grouse Mountain is enough.
      if let text = placemarks[0].thoroughfare, placemarks[0].name == nil {
        if !textArray.contains(text) { textArray.append(text) }
      }

      if let text = placemarks[0].locality {
        if !textArray.contains(text) { textArray.append(text) }
      }

      if let text = placemarks[0].administrativeArea {

        // If this is a province/state code, remove this. 'name' usually takes care of this.
        if !((text.lowercased() == location.lowercased()) && (text.count == 2)){
          if !textArray.contains(text) { textArray.append(text) }
        }
      }

      // Don't show country if there is already a name/thoroughfare, and there is city and state information also
      // Exception is if the name and the city is the same, beacause only 1 of the 2 will be shown
      if let text = placemarks[0].country, !((placemarks[0].name != nil || placemarks[0].thoroughfare != nil) &&
                                             (placemarks[0].name != placemarks[0].locality) &&
                                            placemarks[0].locality != nil && placemarks[0].administrativeArea != nil) {
        if !textArray.contains(text) { textArray.append(text) }
      }

      // Place String into locationField formatted with commas
      textField.text = textArray[0]
      var index = 1

      while index < textArray.count {
        textField.text = textField.text! + ", " + textArray[index]
        index = index + 1
      }

      var region: MKCoordinateRegion!

      // The coordinate in placemarks.region is highly inaccurate. So use the location coordinate when possible.
      if let coordinate = placemarks[0].location?.coordinate, let clRegion = placemarks[0].region as? CLCircularRegion {
        // Determine region via placemark.locaiton.coordinate if possible
        region = MKCoordinateRegionMakeWithDistance(coordinate, 2*clRegion.radius, 2*clRegion.radius)

      } else if let coordinate = placemarks[0].location?.coordinate {
        // Determine region via placemark.location.coordinate and default max delta if clRegion is not available
        region = MKCoordinateRegionMakeWithDistance(coordinate, mapNavController.defaultMapWidth, mapNavController.defaultMapWidth)

      } else if let clRegion = placemarks[0].region as? CLCircularRegion {
        // Determine region via placemarks.region as fall back
        region = MKCoordinateRegionMakeWithDistance(clRegion.center, 2*clRegion.radius, 2*clRegion.radius)

      } else {
        CCLog.assert("Placemark contained no location")

        // There actually isn't a valid location in the placemark...
        textField.text = "No Results Found"
        textField.textColor = UIColor.red
        return
      }

      mapNavController.showRegionExposed(region, animated: true)
    }

    // Get rid of the keybaord
    textField.resignFirstResponder()
    return true
  }


  func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    if textField === locationField {
      // Set the text field color back to black once user starts editing. Might have been set to Red for errors.
      textField.textColor = UIColor.white
      
      guard let searchBarFont = UIFont(name: Constants.SearchBarFontName, size: Constants.SearchBarFontSize) else {
        CCLog.fatal("Cannot create UIFont with name \(Constants.SearchBarFontName)")
      }
      let placeholderString = textField.placeholder
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.alignment = .left
      
      let shadow = NSShadow()
      shadow.shadowOffset = CGSize(width: 0.0, height: 1.0)
      shadow.shadowColor = UIColor.black.withAlphaComponent(Constants.SearchBarTextShadowAlpha)
      shadow.shadowBlurRadius = 1.0
      
      let attributedPlaceholderText = NSAttributedString(string: placeholderString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                                                         attributes: [.font : searchBarFont,
                                                                      .foregroundColor : Constants.SearchBarPlaceholderColor,
                                                                      .paragraphStyle : paragraphStyle,
                                                                      .shadow : shadow])
      
      textField.attributedPlaceholder = attributedPlaceholderText
      return true

    } else {
      CCLog.assert("Unexpected call of textFieldShoudlBeginEditing on textField \(textField.placeholder ?? "")")
      return false
    }
  }
  
  func textFieldDidEndEditing(_ textField: UITextField) {
    guard let searchBarFont = UIFont(name: Constants.SearchBarFontName, size: Constants.SearchBarFontSize) else {
      CCLog.fatal("Cannot create UIFont with name \(Constants.SearchBarFontName)")
    }
    let placeholderString = textField.placeholder
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .left
    
    let shadow = NSShadow()
    shadow.shadowOffset = CGSize(width: 0.0, height: 1.0)
    shadow.shadowColor = UIColor.black.withAlphaComponent(Constants.SearchBarTextShadowAlpha)
    shadow.shadowBlurRadius = 1.0
    
    let attributedPlaceholderText = NSAttributedString(string: placeholderString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                                                       attributes: [.font : searchBarFont,
                                                                    .foregroundColor : UIColor.white,
                                                                    .paragraphStyle : paragraphStyle,
                                                                    .shadow : shadow])
    
    textField.attributedPlaceholder = attributedPlaceholderText
  }
}



extension DiscoverViewController: FeedCollectionNodeDelegate {
  
  func collectionNodeLayoutChanged(to layoutType: FeedCollectionNodeController.LayoutType) {
    
    switch layoutType {
    case .mosaic:
      mosaicMapWidth = mapNavController?.boundedMapWidth()
      mapNavController?.setExposedRect(with: mosaicMapView)
      carouselLayoutChangeTapRecognizer.isEnabled = true
      view.insertSubview(mosaicMapView, aboveSubview: touchForwardingView!)
      
      // Hide top buttons
      appearanceForTopUI(alphaValue: 0.0, animated: true)
      
      UIView.animate(withDuration: FoodieGlobal.Constants.DefaultTransitionAnimationDuration, animations: {
        self.searchBackgroundCarouselConstraint.isActive = false
        self.feedBackgroundCarouselConstraint.isActive = false
        self.searchBackgroundMosaicConstraint.isActive = true
        self.feedBackgroundMosaicConstraint.isActive = true
      })
      
      if let highlightedStoryIndex = highlightedStoryIndex {
        feedCollectionNodeController.scrollTo(storyIndex: highlightedStoryIndex)
      }
      
    case .carousel:
      if let touchForwardingView = touchForwardingView {
        touchForwardingView.isHidden = false
      }
      mapNavController?.setExposedRect(with: carouselMapView)
      mosaicLayoutChangePanRecognizer.isEnabled = true
      mapNavController?.showRegionExposed(containing: storyAnnotations)
      view.insertSubview(touchForwardingView!, aboveSubview: mosaicMapView)
      
      // Should we show top buttons?
      appearanceForTopUI(alphaValue: 1.0, animated: true)
      
      UIView.animate(withDuration: FoodieGlobal.Constants.DefaultTransitionAnimationDuration, animations: {
        self.searchBackgroundMosaicConstraint.isActive = false
        self.feedBackgroundMosaicConstraint.isActive = false
        self.searchBackgroundCarouselConstraint.isActive = true
        self.feedBackgroundCarouselConstraint.isActive = true
      })
      
      if let highlightedStoryIndex = highlightedStoryIndex {
        feedCollectionNodeController.scrollTo(storyIndex: highlightedStoryIndex)
      }
    }
  }
  
  
  func collectionNodeDidStopScrolling() {
    if let storyIndex = self.feedCollectionNodeController.highlightedStoryIndex, storyIndex < storyArray.count {
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
            self.lastMapRegion = region
            
            mapNavController?.showRegionExposed(region, animated: true)
            
          case .carousel:
            // TODO: Does the exposed map already show the annotation? Only zoom to all annotations if not already shown
            mapNavController?.showRegionExposed(containing: self.storyAnnotations)
            allStoriesButton.isHidden = true
            searchButton.isHidden = true
          }
          mapNavController?.select(annotation: annotation, animated: true)
        }
      }
    }
      
    // Do Prefetching? In reality doing this slows down the whole app. And assets don't seem to be ready any quicker.... If not slower all together.....
    let storiesIndexes = self.feedCollectionNodeController.getStoryIndexesVisible(forOver: Constants.PercentageOfStoryVisibleToStartPrefetch)
    if storiesIndexes.count > 0 {
      let storiesShouldPrefetch = storiesIndexes.map { self.storyArray[$0] }
      FoodieFetch.global.cancelAllBut(storiesShouldPrefetch)
    }
  }
}


extension DiscoverViewController: MapNavControllerDelegate {
  
  func mapNavController(_ mapNavController: MapNavController, didSelect annotation: MKAnnotation) {
    
    if let storyAnnotation = annotation as? StoryMapAnnotation, feedCollectionNodeController.layoutType == .carousel {
      for index in 0..<storyArray.count {
        if storyAnnotation.story === storyArray[index] {
          feedCollectionNodeController.scrollTo(storyIndex: index)
          break
        }
      }
    }
  }
  
  
  func mapNavControllerWasMovedByUser(_ mapNavController: MapNavController) {
    self.mapNavController?.stopTracking()
    self.searchButton?.isHidden = false
    
    if let user = FoodieUser.current, user.isRegistered, user.roleLevel >= FoodieRole.Level.moderator.rawValue {
      self.allStoriesButton.isHidden = false
    }
  }
}


extension DiscoverViewController: CameraReturnDelegate {
  func captureComplete(markedupMoments: [FoodieMoment], suggestedStory: FoodieStory?) {
    DispatchQueue.main.async {  // UI Work. We don't know which thread we might be in, so guarentee execute in Main thread
      let storyboard = UIStoryboard(name: "Compose", bundle: nil)
      guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryCompositionViewController") as? StoryCompositionViewController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.fatal("ViewController initiated not of StoryCompositionViewController Class!!")
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
      
      self.appearanceForAllUI(alphaValue: 0.0, animated: true)
      
      self.dismiss(animated: true) {  // This dismiss is for the CameraViewController to call on
        viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
        self.pushPresent(viewController, animated: true)  // This pushPresent is from the DiscoverViewController to present the Composition VC
      }
    }
  }
}
