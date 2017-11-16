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
    static let DefaultCLCoordinate2D = CLLocationCoordinate2D(latitude: CLLocationDegrees(49.2781372),
                                                              longitude: CLLocationDegrees(-123.1187237))  // This is set to Vancouver
    static let DefaultMaxDelta: CLLocationDegrees = 0.05
    static let DefaultMinDelta: CLLocationDegrees = 0.005
    static let QueryMaxLatDelta: CLLocationDegrees = 1.0  // Approximately 111km
    
    static let PullTranslationForChange: CGFloat = 50.0
  }

  

  // MARK: - Private Instance Variables
  private let refreshQueue = DispatchQueue(label: "Discover View Refresh Queue", qos: .userInitiated)
  
  private var currentMapDelta = Constants.DefaultMaxDelta
  private var locationWatcher: LocationWatch.Context?
  private var lastLocation: CLLocationCoordinate2D? = nil
  private var lastMapDelta: CLLocationDegrees? = nil
  private var storyQuery: FoodieQuery?
  private var storyArray = [FoodieStory]()
  private var storyAnnotations = [StoryMapAnnotation]()
  private var feedCollectionNodeController: FeedCollectionNodeController!
  
  private var mapNavController: MapNavController {
    guard let mapNavController = navigationController as? MapNavController else {
      CCLog.fatal("Expected navigationController to be of type MapNavController")
    }
    return mapNavController
  }
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var panGestureRecognizer: UIPanGestureRecognizer!
  @IBOutlet weak var pinchGestureRecognizer: UIPinchGestureRecognizer!
  @IBOutlet weak var doubleTapGestureRecognizer: UITapGestureRecognizer!
  @IBOutlet weak var singleTapGestureRecognizer: UITapGestureRecognizer!
  @IBOutlet weak var mosaicLayoutChangePanRecognizer: UIPanGestureRecognizer!
  @IBOutlet weak var carouselLayoutChangeTapRecognizer: UITapGestureRecognizer!
  
  @IBOutlet weak var locationField: UITextField!
  @IBOutlet weak var draftButton: UIButton!
  @IBOutlet weak var cameraButton: UIButton!
  @IBOutlet weak var logoutButton: UIButton!
  @IBOutlet weak var profileButton: UIButton!
  @IBOutlet weak var allStoriesButton: UIButton!
  
  @IBOutlet weak var touchForwardingView: TouchForwardingView? {
    didSet {
      if let touchForwardingView = touchForwardingView, let mapNavController = navigationController as? MapNavController {
        touchForwardingView.passthroughViews = [mapNavController.mapView]
      }
    }
  }
  
  @IBOutlet weak var feedContainerView: UIView!
  @IBOutlet weak var mosaicMapView: UIView!
  @IBOutlet weak var carouselMapView: UIView!
  
  
  // MARK: - IBActions
  @IBAction func singleTapGestureDetected(_ sender: UITapGestureRecognizer) {
    // Dismiss keyboard if any gestures detected against Map
    locationField?.resignFirstResponder()
  }

  
  // Pan, Pinch, Double-Tap gestures all routed here
  @IBAction func mapGestureDetected(_ recognizer: UIGestureRecognizer) {

    // Dismiss keyboard if any gestures detected against Map
    locationField?.resignFirstResponder()

    // Stop updating location if any gestures detected against Map
    switch recognizer.state {
    case .began, .ended:
      locationWatcher?.pause()
      mapNavController.mapView.setUserTrackingMode(.none, animated: false)
    default:
      break
    }
  }
  
  
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
    viewController.cameraReturnDelegate = self
    present(viewController, animated: true)  // Use regular present for the Camera for now. Not including the camera as part of the MapNavController for now
  }
  
  
  @IBAction func currentLocationReturn(_ sender: UIButton) {

    // Clear the text field while at it
    locationField?.text = ""
    
    // Clear last location, we want the map to find the current location if the view resumes
    lastLocation = nil
    lastMapDelta = nil

    if mapNavController.mapView.userTrackingMode == .none {
      // Base the span of the new mapView on what the mapView span currently is
      currentMapDelta = mapNavController.exposedRegion.span.latitudeDelta
      
      // Take the lesser of current or default max latitude degrees
      currentMapDelta = min(currentMapDelta, Constants.DefaultMaxDelta)

      // Take the greater of current or default min latitude degrees
      currentMapDelta = max(currentMapDelta, Constants.DefaultMinDelta)

      // Start updating location again
      locationWatcher?.resume()
      mapNavController.mapView.setUserTrackingMode(.follow, animated: true)
    }
  }
  
  
  @IBAction func searchWithFilter(_ sender: UIButton) {
    
    locationWatcher?.pause()
    mapNavController.mapView.setUserTrackingMode(.none, animated: false)
    
    performQuery { stories, error in
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
      
      self.refreshDiscoverView(onStories: stories, zoomToRegion: true, scrollAndSelectStory: true)
    }
  }
  
  
  @IBAction func allStories(_ sender: UIButton) {
    
    locationWatcher?.pause()
    mapNavController.mapView.setUserTrackingMode(.none, animated: false)
    
    performQuery(onAllUsers: true) { stories, error in
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
  
  
  private func performQuery(onAllUsers: Bool = false, at mapRect: MKMapRect? = nil, withBlock callback: FoodieQuery.StoriesErrorBlock?) {
    
    var searchMapRect = MKMapRect()
    
    if mapRect == nil {
      searchMapRect = mapNavController.exposedMapRect
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
      callback?(nil, ErrorCode.mapQueryExceededMaxLat)
      return
    }
    
    storyQuery = FoodieQuery()
    storyQuery!.addLocationFilter(southWest: southWestCoordinate, northEast: northEastCoordinate)
    
    if !onAllUsers {
      // Add Filter so only Post by Users > Limited User && Posts by Yourself can be seen
      storyQuery!.addRoleFilter(min: .user, max: nil)
      
      if let currentUser = FoodieUser.current, currentUser.isRegistered {
        storyQuery!.addAuthorsFilter(users: [currentUser])
      }
    }
    
    storyQuery!.setSkip(to: 0)
    storyQuery!.setLimit(to: FoodieGlobal.Constants.StoryFeedPaginationCount)
    _ = storyQuery!.addArrangement(type: .creationTime, direction: .descending) // TODO: - Should this be user configurable? Or eventualy we need a seperate function/algorithm that determins feed order

    let activitySpinner = ActivitySpinner(addTo: view)
    activitySpinner.apply()
    
    // Actually do the Query
    storyQuery!.initStoryQueryAndSearch { (stories, error) in
      
      activitySpinner.remove()
      
      if let error = error {
        AlertDialog.present(from: self, title: "Query Failed", message: error.localizedDescription) { action in
          CCLog.assert("Create Story Query & Search failed with error: \(error.localizedDescription)")
        }
        callback?(nil, error)
        return
      }
      
      guard let storyArray = stories else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
        CCLog.fatal("Create Story Query & Search returned with nil Story Array")
      }
      
      self.storyArray = storyArray
      callback?(storyArray, nil)
    }
  }
  
  
  private func refreshDiscoverView(onStories stories: [FoodieStory], zoomToRegion: Bool, scrollAndSelectStory: Bool) {
    
    DispatchQueue.main.async {
      self.mapNavController.mapView.removeAnnotations(self.storyAnnotations)
      self.storyAnnotations = [StoryMapAnnotation]()
      
      self.refreshQueue.async {
        var outstandingStoryRetrieval = 0
        
        for story in stories {
          outstandingStoryRetrieval += 1
          
          _ = story.retrieveDigest(from: .both, type: .cache) { error in
            
            self.refreshQueue.async {
              outstandingStoryRetrieval -= 1
            
              if let error = error {
                AlertDialog.present(from: self, title: "Story Retrieve Error", message: "Failed to retrieve Story Digest - \(error.localizedDescription)") { action in
                  CCLog.warning("Failed to retrieve Story Digest via story.retrieveDigest. Error - \(error.localizedDescription)")
                }
                return
              }
            
              if let venue = story.venue, venue.isDataAvailable == false {
                CCLog.fatal("Venue \(venue.getUniqueIdentifier()) returned with no Data Available")
              }
              
              guard let venue = story.venue, let location = venue.location else {
                CCLog.warning("No Title, Venue or Location to Story. Skipping Story")
                return
              }
              
              let annotation = StoryMapAnnotation(title: venue.name ?? "",
                                                  story: story,
                                                  coordinate: CLLocationCoordinate2D(latitude: location.latitude,
                                                                                     longitude: location.longitude))
              
              self.storyAnnotations.append(annotation)
              
              if outstandingStoryRetrieval == 0 {
                DispatchQueue.main.async {
                  self.mapNavController.mapView.addAnnotations(self.storyAnnotations)
                  
                  self.feedCollectionNodeController.resetCollectionNode(with: stories, completion: {
                    
                    if zoomToRegion {
                      self.mapNavController.showRegionExposed(containing: self.storyAnnotations)
                    }
                    
                    if scrollAndSelectStory {
                      self.feedCollectionNodeController.scrollTo(storyIndex: 0)
                      self.mapNavController.mapView.selectAnnotation(self.storyAnnotations[0], animated: true)
                    }
                  })
                }
              }
            }
          }
        }
      }
    }
  }
  
  
  private func applyDefaultMapLocation() {
    // Provide a default Map Region incase Location Update is slow or user denies authorization
    let startMapLocation: CLLocationCoordinate2D = lastLocation ?? Constants.DefaultCLCoordinate2D
    let startMapDelta: CLLocationDegrees = lastMapDelta ?? Constants.DefaultMaxDelta
    let region = MKCoordinateRegion(center: startMapLocation,
                                    span: MKCoordinateSpan(latitudeDelta: startMapDelta, longitudeDelta: startMapDelta))
    mapNavController.setRegionExposed(region, animated: true)
  }
  
  
  private func startLocationWatcher() {
    // Start/Restart the Location Watcher
    locationWatcher = LocationWatch.global.start(butPaused: (lastLocation != nil)) { (location, error) in
      if let error = error {
        CCLog.warning("LocationWatch returned error - \(error.localizedDescription)")
        return
      }
      
      if let location = location {
        let region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: self.currentMapDelta, longitudeDelta: self.currentMapDelta))
        DispatchQueue.main.async { self.mapNavController.setRegionExposed(region, animated: true) }
      }
    }
  }
  
  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if let touchForwardingView = touchForwardingView {
      touchForwardingView.passthroughViews = [mapNavController.mapView]
    }
    
    let nodeController = FeedCollectionNodeController(with: .carousel, allowLayoutChange: true, adjustScrollViewInset: false)
    addChildViewController(nodeController)
    feedContainerView.addSubview(nodeController.view)
    nodeController.view.frame = feedContainerView.bounds
    nodeController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    nodeController.didMove(toParentViewController: self)
    feedCollectionNodeController = nodeController
    nodeController.delegate = self
    
    carouselLayoutChangeTapRecognizer.isEnabled = false
    
    // Initialize Location Watch manager
    LocationWatch.initializeGlobal()
    
    // Do any additional setup after loading the view.
    panGestureRecognizer?.delegate = self
    pinchGestureRecognizer?.delegate = self
    doubleTapGestureRecognizer?.delegate = self
    singleTapGestureRecognizer?.delegate = self
    locationField?.delegate = self
    
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
            _ = story.retrieveRecursive(from: .local, type: .draft, forceAnyways: false) { error in

              if let retrieveError = error {
                FoodieObject.deleteAll(from: .draft) { error in
                  if let deleteError = error {
                    CCLog.warning("Delete All resulted in Error - \(deleteError.localizedDescription)")
                  }
                  AlertDialog.present(from: self, title: "Draft Resume Error", message: "Failed to resume story under draft. Sorry ='(  Problem has been logged. Please restart app for auto error report to be submitted.") { action in
                    CCLog.assert("Retrieve Recursive on Draft Story \(story.getUniqueIdentifier()) resulted in error. Clearing Draft Pin and Directory - \(retrieveError.localizedDescription)")
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

  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
 
    // There should already be pins on the map, do nothing
    if storyQuery != nil {
      self.startLocationWatcher()
    }
    
    // No pins on the map, but this is not the first time. Just go to last location
    else if lastLocation != nil {
      applyDefaultMapLocation()
      self.startLocationWatcher()
    }
    
    // First time on the map. Try to get the location, and get an initial query if successful
    else {
      LocationWatch.global.get { location, error in
        if let error = error {
          AlertDialog.present(from: self, title: "Location Error", message: error.localizedDescription) { _ in
            CCLog.warning("LocationWatch.get() returned error - \(error.localizedDescription)")
          }
          self.applyDefaultMapLocation()
          self.startLocationWatcher()
          return
        }
        
        guard let location = location else {
          AlertDialog.present(from: self, title: "Location Error", message: "Obtained invalid location information") { _ in
            CCLog.warning("LocationWatch.get() returned locaiton = nil")
          }
          self.applyDefaultMapLocation()
          self.startLocationWatcher()
          return
        }
        
        // Move the map to the initial location
        let region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: self.currentMapDelta, longitudeDelta: self.currentMapDelta))
        DispatchQueue.main.async { self.mapNavController.setRegionExposed(region, animated: true) }
        
        // Do an Initial Search near the Current Location
        self.performQuery(at: region.toMapRect()) { stories, error in
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
          self.refreshDiscoverView(onStories: stories, zoomToRegion: false, scrollAndSelectStory: true)
        }
        
        self.startLocationWatcher()
      }
    }
    
    // Don't bother showing the Draft Button if there's no Draft
    draftButton.isHidden = FoodieStory.currentStory == nil
    
    // Don't allow user to go to the Camera and thus Story composition unless they are logged-in with E-mail verified
    cameraButton.isHidden = true
    logoutButton.isHidden = false
    profileButton.isHidden = true
    allStoriesButton.isHidden = true
    
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
            
            if user.roleLevel >= FoodieRole.Level.moderator.rawValue {
              self.allStoriesButton.isHidden = false
            }
          }
        }
      }
    }
  }

  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    switch feedCollectionNodeController.layoutType {
    case .carousel:
      mapNavController.setExposedRect(with: carouselMapView)
      
    case .mosaic:
      mapNavController.setExposedRect(with: mosaicMapView)
    }
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    FoodieFetch.global.cancelAll()
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    // Don't even know when we'll be back. Let the GPS stop if no one else is using it
    locationWatcher?.stop()
    mapNavController.mapView.setUserTrackingMode(.none, animated: false)
    
    // Keep track of what the location is before we disappear
    lastLocation = mapNavController.exposedRegion.center
    lastMapDelta = mapNavController.exposedRegion.span.latitudeDelta
  }
}



extension DiscoverViewController: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
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
    
    guard let location = textField.text else {
      // No text in location field
      return true
    }

    let clRegion = CLCircularRegion(center: mapNavController.exposedRegion.center,
                                    radius: mapNavController.exposedRegion.span.height*Double(FoodieGlobal.Constants.DefaultMomentAspectRatio)/2,
                                    identifier: "currentCLRegion")  // TODO: 16:9 assumption is not good enough
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

      // Move map to region as indicated by CLPlacemark
      self.locationWatcher?.pause()
      self.mapNavController.mapView.setUserTrackingMode(.none, animated: false)
      
      var region: MKCoordinateRegion?

      // The coordinate in palcemarks.region is highly inaccurate. So use the location coordinate when possible.
      if let coordinate = placemarks[0].location?.coordinate, let clRegion = placemarks[0].region as? CLCircularRegion {
        // Determine region via placemark.locaiton.coordinate if possible
        region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(height: clRegion.radius*2*1.39))  // 1.39 is between square and 16:9 // TODO: 16:9 assumption is not good enough

      } else if let coordinate = placemarks[0].location?.coordinate {
        // Determine region via placemark.location.coordinate and default max delta if clRegion is not available
        region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: Constants.DefaultMaxDelta, longitudeDelta: Constants.DefaultMaxDelta))

      } else if let clRegion = placemarks[0].region as? CLCircularRegion {
        // Determine region via placemarks.region as fall back
        region = MKCoordinateRegion(center: clRegion.center, span: MKCoordinateSpan(height: clRegion.radius*2))

      } else {
        CCLog.assert("Placemark contained no location")

        // There actually isn't a valid location in the placemark...
        textField.text = "No Results Found"
        textField.textColor = UIColor.red
        return
      }

      if let region = region {
        self.mapNavController.setRegionExposed(region, animated: true)
      }
    }

    // Get rid of the keybaord
    textField.resignFirstResponder()
    return true
  }


  func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    if textField === locationField {
      // Set the text field color back to black once user starts editing. Might have been set to Red for errors.
      textField.textColor = UIColor.black
      return true

    } else {
      CCLog.assert("Unexpected call of textFieldShoudlBeginEditing on textField \(textField.placeholder ?? "")")
      return false
    }
  }
}



extension DiscoverViewController: FeedCollectionNodeDelegate {
  
  func collectionNodeLayoutChanged(to layoutType: FeedCollectionNodeController.LayoutType) {
    switch layoutType {
    case .mosaic:
      mapNavController.setExposedRect(with: mosaicMapView)
      carouselLayoutChangeTapRecognizer.isEnabled = true
      view.insertSubview(mosaicMapView, aboveSubview: touchForwardingView!)
      
      
    case .carousel:
      if let touchForwardingView = touchForwardingView {
        touchForwardingView.isHidden = false
      }
      mapNavController.setExposedRect(with: carouselMapView)
      mosaicLayoutChangePanRecognizer.isEnabled = true
      mapNavController.showRegionExposed(containing: storyAnnotations)
      view.insertSubview(touchForwardingView!, aboveSubview: mosaicMapView)
    }
  }
  
  
  func collectionNodeDidEndDecelerating() {
    if feedCollectionNodeController.layoutType == .carousel {
      if let storyIndex = feedCollectionNodeController.highlightedStoryIndex {
        for annotation in mapNavController.mapView.annotations {
          if let storyAnnotation = annotation as? StoryMapAnnotation, storyAnnotation.story === storyArray[storyIndex] {
            mapNavController.selectInExposedRect(annotation: storyAnnotation)
          }
        }
      }
    }
  }
  
  
  func collectionNodeScrollViewDidEndDragging() {
    if feedCollectionNodeController.layoutType == .mosaic {
      if let storyIndex = feedCollectionNodeController.highlightedStoryIndex {
        for annotation in mapNavController.mapView.annotations {
          if let storyAnnotation = annotation as? StoryMapAnnotation, storyAnnotation.story === storyArray[storyIndex] {
            mapNavController.selectInExposedRect(annotation: storyAnnotation)
          }
        }
      }
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
      
      self.dismiss(animated: true) {  // This dismiss is for the CameraViewController to call on
        viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
        self.pushPresent(viewController, animated: true)  // This pushPresent is from the DiscoverViewController to present the Composition VC
      }
    }
  }
}
