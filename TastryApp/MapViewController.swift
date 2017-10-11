//
//  MapViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-03-20.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation


class MapViewController: TransitableViewController {

  // MARK: Error Types Definition
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
  }

  

  // MARK: - Instance Variables
  fileprivate var currentMapDelta = Constants.DefaultMaxDelta
  fileprivate var locationWatcher: LocationWatch.Context?
  fileprivate var lastLocation: CLLocationCoordinate2D? = nil
  fileprivate var lastMapDelta: CLLocationDegrees? = nil
  fileprivate var searchCategory: FoodieCategory?
  fileprivate var storyQuery: FoodieQuery?
  fileprivate var storyArray = [FoodieStory]()
  
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var mapView: MKMapView!
  @IBOutlet weak var panGestureRecognizer: UIPanGestureRecognizer!
  @IBOutlet weak var pinchGestureRecognizer: UIPinchGestureRecognizer!
  @IBOutlet weak var doubleTapGestureRecognizer: UITapGestureRecognizer!
  @IBOutlet weak var singleTapGestureRecognizer: UITapGestureRecognizer!
  @IBOutlet weak var buttonStackView: UIStackView!
  @IBOutlet weak var locationField: UITextField!
  @IBOutlet weak var categoryField: UITextField!
  @IBOutlet weak var draftButton: UIButton!
  @IBOutlet weak var cameraButton: UIButton!
  @IBOutlet weak var logoutButton: UIButton!
  @IBOutlet weak var profileButton: UIButton!
  @IBOutlet weak var allStoriesButton: UIButton!
  
  
  
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
    default:
      break
    }
  }
  
  
  @IBAction func launchDraftStory(_ sender: Any) {
    // This is used for viewing the draft story to be used with update story later
    // Hid the button due to problems with empty draft story and saving an empty story is problematic
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryCompositionViewController") as? StoryCompositionViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of StoryCompositionViewController Class!!")
      }
      return
    }

    if(FoodieStory.currentStory == nil)
    {
      viewController.workingStory =  FoodieStory.newCurrent()
    }
    else
    {
      viewController.workingStory = FoodieStory.currentStory
    }
    
    viewController.setTransition(presentTowards: .left, dismissTowards: .right, dismissIsDraggable: true, dragDirectionIsFixed: true)
    self.present(viewController, animated: true)
  }
  
  
  @IBAction func launchCamera(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "CameraViewController") as? CameraViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of CameraViewController Class!!")
      }
      return
    }
    viewController.cameraReturnDelegate = self
    self.present(viewController, animated: true)
  }
  
  
  
  @IBAction func currentLocationReturn(_ sender: UIButton) {

    // Clear the text field while at it
    locationField?.text = ""
    
    // Clear last location, we want the map to find the current location if the view resumes
    lastLocation = nil
    lastMapDelta = nil

    // Base the span of the new mapView on what the mapView span currently is
    if let mapView = mapView { currentMapDelta = mapView.region.span.latitudeDelta }
    
    // Take the lesser of current or default max latitude degrees
    currentMapDelta = min(currentMapDelta, Constants.DefaultMaxDelta)

    // Take the greater of current or default min latitude degrees
    currentMapDelta = max(currentMapDelta, Constants.DefaultMinDelta)

    // Start updating location again
    locationWatcher?.resume()
  }
  
  
  @IBAction func searchWithFilter(_ sender: UIButton) {
    
    // Kill all Pre-fetches
    FoodiePrefetch.global.removeAllPrefetchWork()
    
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
      
      self.displayAnnotations(onStories: stories)
    }
  }
  
  
  @IBAction func showFeed(_ sender: UIButton) {
    performQuery { stories, error in
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
      
      guard let query = self.storyQuery else {
        AlertDialog.present(from: self, title: "Story Query Error", message: "Story Query did not produce a Query") { action in
          CCLog.assert("Story Query resulted in storyQuery = nil")
        }
        return
      }
      
      self.displayAnnotations(onStories: stories)
      self.launchFeed(withStoryArray: stories, withStoryQuery: query)
    }
  }
  
  
  @IBAction func allStories(_ sender: UIButton) {
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
      
      guard let query = self.storyQuery else {
        AlertDialog.present(from: self, title: "Story Query Error", message: "Story Query did not produce a Query") { action in
          CCLog.assert("Story Query resulted in storyQuery = nil")
        }
        return
      }
      
      self.displayAnnotations(onStories: stories)
      self.launchFeed(withStoryArray: stories, withStoryQuery: query)
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
    viewController.setTransition(presentTowards: .left, dismissTowards: .right, dismissIsDraggable: true, dragDirectionIsFixed: true)
    self.present(viewController, animated: true)
  }
  
  
  
  // MARK: - Class Private Functions
  
  // Generic error dialog box to the user on internal errors
  fileprivate func internalErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "TastryApp",
                                              titleComment: "Alert diaglogue title when a Map View internal error occured",
                                              message: "An internal error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Map View internal error occured",
                                              preferredStyle: .alert)
    
      alertController.addAlertAction(title: "OK", comment: "Button in alert dialog box for generic MapView errors", style: .cancel)
      self.present(alertController, animated: true, completion: nil)
    }
  }


  // Error dialog box to the user on location errors
  fileprivate func locationErrorDialog(message: String, comment: String) {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "TastryApp",
                                              titleComment: "Alert diaglogue title when a Map View location error occured",
                                              message: message,
                                              messageComment: comment,
                                              preferredStyle: .alert)
      
      alertController.addAlertAction(title: "OK", comment: "Button in alert dialog box for location related Map View errors", style: .cancel)
      self.present(alertController, animated: true, completion: nil)
    }
  }


  fileprivate func queryErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "TastryApp",
                                              titleComment: "Alert diaglogue title when a Map View query error occurred",
                                              message: "A query error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Map View query error occurred",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for generic Map View errors",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  
  fileprivate func locationPermissionDeniedDialog() {
    if self.presentedViewController == nil {
      // Permission was denied before. Ask for permission again
      guard let url = URL(string: UIApplicationOpenSettingsURLString) else {
        CCLog.assert("UIApplicationOPenSettignsURLString ia an invalid URL String???")
        internalErrorDialog()
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
  
  
  fileprivate func performQuery(onAllUsers: Bool = false, at mapRect: MKMapRect? = nil, withBlock callback: FoodieQuery.StoriesErrorBlock?) {
    
    var searchMapRect = MKMapRect()
    
    if mapRect == nil {
      guard let visibleMapRect = mapView?.visibleMapRect else {
        locationErrorDialog(message: "Invalid Map View. Search Location Undefined", comment: "Alert dialog message when mapView is nil when user attempted to perform Search")
        CCLog.assert("Search w/ Filter cannot be performed when mapView = nil")
        return
      }
      searchMapRect = visibleMapRect
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

    let blurSpinner = BlurSpinWait()
    blurSpinner.apply(to: self.view, blurStyle: .dark, spinnerStyle: .whiteLarge)
    
    // Actually do the Query
    storyQuery!.initStoryQueryAndSearch { (stories, error) in
      
      blurSpinner.remove()
      
      if let err = error {
        self.queryErrorDialog()
        CCLog.assert("Create Story Query & Search failed with error: \(err.localizedDescription)")
        callback?(nil, err)
        return
      }
      
      guard let storyArray = stories else {
        self.queryErrorDialog()
        CCLog.assert("Create Story Query & Search returned with nil Story Array")
        callback?(nil, ErrorCode.queryNilStory)
        return
      }
      
      self.storyArray = storyArray
      callback?(storyArray, nil)
    }
  }
  
  
  fileprivate func displayAnnotations(onStories stories: [FoodieStory]) {

    DispatchQueue.main.async {
      self.mapView.removeAnnotations(self.mapView.annotations)
    }
    
    for story in stories {
      story.retrieveDigest(from: .both, type: .cache) { error in
        if let error = error {
          AlertDialog.present(from: self, title: "Story Retrieve Error", message: "Failed to retrieve Story Digest - \(error.localizedDescription)") { action in
            CCLog.assert("Failed to retrieve Story Digest via story.retrieveDigest. Error - \(error.localizedDescription)")
          }
          return
        }
      
        if let venue = story.venue, venue.isDataAvailable == false {
          CCLog.fatal("Venue \(venue.getUniqueIdentifier()) returned with no Data Available")
        }
        
        guard let title = story.title, let venue = story.venue, let location = venue.location else {
          CCLog.warning("No Title, Venue or Location to Story. Skipping Story")
          return
        }
        
        DispatchQueue.main.async {
          let annotation = StoryMapAnnotation(title: title,
                                              story: story,
                                              coordinate: CLLocationCoordinate2D(latitude: location.latitude,
                                                                                 longitude: location.longitude))
          self.mapView.addAnnotation(annotation)
        }
      }
    }
  }
  
  
  fileprivate func launchFeed(withStoryArray stories: [FoodieStory], withStoryQuery query: FoodieQuery) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "DiscoverFeedViewController") as? DiscoverFeedViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of DiscoverFeedViewController Class!!")
      }
      return
    }
    viewController.storyQuery = query
    viewController.storyArray = stories
    viewController.setTransition(presentTowards: .left, dismissTowards: .right, dismissIsDraggable: true, dragDirectionIsFixed: true)
    self.present(viewController, animated: true)
  }
  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Initialize Location Watch manager
    LocationWatch.initializeGlobal()
    
    // Do any additional setup after loading the view.
    mapView?.delegate = self
    panGestureRecognizer?.delegate = self
    pinchGestureRecognizer?.delegate = self
    doubleTapGestureRecognizer?.delegate = self
    singleTapGestureRecognizer?.delegate = self
    locationField?.delegate = self
    categoryField?.delegate = self
    
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
           
          story.retrieveRecursive(from: .local, type: .draft, forceAnyways: false) { error in
            
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
    mapView?.setRegion(region, animated: false)
  }
  
  
  private func startLocationWatcher() {
    // Start/Restart the Location Watcher
    locationWatcher = LocationWatch.global.start(butPaused: (lastLocation != nil)) { (location, error) in
      if let error = error {
        self.locationErrorDialog(message: "LocationWatch returned error - \(error.localizedDescription)", comment: "Alert Dialogue Message")
        CCLog.warning("LocationWatch returned error - \(error.localizedDescription)")
        return
      }
      
      if let location = location {
        let region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: self.currentMapDelta, longitudeDelta: self.currentMapDelta))
        DispatchQueue.main.async { self.mapView?.setRegion(region, animated: true) }
      }
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Kill all Pre-fetches
    FoodiePrefetch.global.removeAllPrefetchWork()
    
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
        DispatchQueue.main.async { self.mapView?.setRegion(region, animated: true) }
        
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
          self.displayAnnotations(onStories: stories)
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
  
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    // Don't even know when we'll be back. Let the GPS stop if no one else is using it
    locationWatcher?.stop()
    
    // Keep track of what the location is before we disappear
    lastLocation = mapView?.centerCoordinate
    lastMapDelta = mapView?.region.span.latitudeDelta
  }
}


extension MapViewController: UIGestureRecognizerDelegate {

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}


extension MapViewController: UITextFieldDelegate {

  // TODO: textFieldShouldReturn, implement Dynamic Filter Querying with another Geocoder
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {

    if textField === categoryField {
      return true
    }
    
    // DEBUG: Forces a Crash!!!!!
    if let text = textField.text {
      if text == "CrashRightNow" {
        CCLog.fatal("CrashRightNow Force Crash Triggered!!!")
      }
    }
    
    guard let location = textField.text, let region = mapView?.region else {
      // No text in location field, or no map view all together?
      return true
    }

    let clRegion = CLCircularRegion(center: region.center,
                                    radius: region.span.height/1.78/2,
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
        if !((text.lowercased() == location.lowercased()) && (text.characters.count == 2)){
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
        self.mapView?.setRegion(region, animated: true)
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
      
    } else if textField == categoryField {
      
      let storyboard = UIStoryboard(name: "Main", bundle: nil)
      guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "CategoryTableViewController") as? CategoryTableViewController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.fatal("ViewController initiated not of CategoryTableViewController Class!!")
        }
        return false
      }
      viewController.delegate = self
      viewController.setTransition(presentTowards: .up, dismissTowards: .down, dismissIsDraggable: true, dragDirectionIsFixed: true)
      self.present(viewController, animated: true)
      return false
      
    } else {
      CCLog.assert("Unexpected call of textFieldShoudlBeginEditing on textField \(textField.placeholder ?? "")")
      return false
    }
  }
}


extension MapViewController: CameraReturnDelegate {
  func captureComplete(markedupMoment: FoodieMoment, suggestedStory: FoodieStory?) {
    DispatchQueue.main.async {  // UI Work. We don't know which thread we might be in, so guarentee execute in Main thread
      let storyboard = UIStoryboard(name: "Main", bundle: nil)
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
      viewController.returnedMoment = markedupMoment
      
      self.dismiss(animated: true) { /*[unowned self] in*/
        viewController.setTransition(presentTowards: .left, dismissTowards: .right, dismissIsDraggable: true, dragDirectionIsFixed: true)
        self.present(viewController, animated: true)
      }
    }
  }
}


extension MapViewController: CategoryTableReturnDelegate {
  func categorySearchComplete(category: FoodieCategory?) {
    if let category = category {
      searchCategory = category
      categoryField.text = category.name ?? ""
    } else {
      searchCategory = nil
      categoryField.text = ""
    }
  }
}


extension MapViewController: MKMapViewDelegate {
  
  class StoryButton: UIButton {
    var story: FoodieStory?
  }
  
  @objc func storyCalloutTapped(sender: StoryButton) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryViewController") as? StoryViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of StoryViewController Class!!")
      }
      return
    }
    
    guard let story = sender.story else {
      AlertDialog.present(from: self, title: "Story Load Error", message: "No Story was loaded for this location! Please try another one!") { action in
        CCLog.assert("No story contained in StoryButton clicked")
      }
      return
    }
    
    viewController.viewingStory = story
    viewController.setTransition(presentTowards: .up, dismissTowards: .down, dismissIsDraggable: true, dragDirectionIsFixed: true)
    self.present(viewController, animated: true)
  }
  
  
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    guard let annotation = annotation as? StoryMapAnnotation else {
      return nil
    }
    
    let identifier = "StoryMapPin"
    var view: MKPinAnnotationView
    
    if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView {
      dequeuedView.annotation = annotation
      view = dequeuedView
    } else {
      view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      view.canShowCallout = true
    }
    
    if let thumbnail = annotation.story.thumbnailObj, let imageData = thumbnail.imageMemoryBuffer {
      
      let screenSize = UIScreen.main.bounds
      
      let calloutAccView = UIView()
      calloutAccView.translatesAutoresizingMaskIntoConstraints = false
      
      let titleLabel = UILabel()
      titleLabel.text = annotation.title
      titleLabel.font = UIFont.systemFont(ofSize: 17.0)
      titleLabel.textColor = UIColor.white
      titleLabel.textAlignment = .center
      titleLabel.numberOfLines = 3
      titleLabel.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.2)
      titleLabel.isUserInteractionEnabled = false  // This is so that all the clicks go straight thru to the button at the back
      titleLabel.translatesAutoresizingMaskIntoConstraints = false
      
      if let venueName = annotation.story.venue?.name {
        annotation.title = "@ "
        if venueName.characters.count < 22 {
          annotation.title! += venueName
        } else {
          let index = venueName.index(venueName.startIndex, offsetBy: 22)
          annotation.title! += venueName[..<index]
          annotation.title! += "..."
        }
      } else { annotation.title = " " }
      
      
      let thumbnailButton = StoryButton()
      thumbnailButton.setImage(UIImage(data: imageData), for: .normal)
      thumbnailButton.translatesAutoresizingMaskIntoConstraints = false
      thumbnailButton.story = annotation.story
      thumbnailButton.addTarget(self, action: #selector(storyCalloutTapped(sender:)), for: .touchUpInside)
      
      calloutAccView.addSubview(thumbnailButton)
      calloutAccView.addSubview(titleLabel)
      
      let views = ["titleLabel": titleLabel,
                   "thumbnailButton": thumbnailButton]
      let metrics = ["width": screenSize.width/2.0,
                     "height": screenSize.height/2.0,
                     "labelHeight": screenSize.height/10.0]
      var constraints = [NSLayoutConstraint]()
      constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|[thumbnailButton(width)]|", options: [], metrics: metrics, views: views)
      constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|[thumbnailButton(height)]|", options: [], metrics: metrics, views: views)
      constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|[titleLabel(width)]|", options: [], metrics: metrics, views: views)
      constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:[titleLabel(labelHeight)]|", options: [], metrics: metrics, views: views)
      calloutAccView.addConstraints(constraints)
      
      view.detailCalloutAccessoryView = calloutAccView

    } else {
      AlertDialog.present(from: self, title: "Story Retrieval Error", message: "No Thumbnail for Story!") { action in
        CCLog.warning("No Thumbnail for Story in Map View. Thumbnail filename - \(annotation.story.thumbnailFileName ?? "Filename Not Found")")
      }
    }
    return view
  }
  
  
  func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    guard let annotation = view.annotation as? StoryMapAnnotation else {
      CCLog.warning("No StoryMapAnnotation associated with Annotation View")
      return
    }
    let story = annotation.story
    story.contentPrefetchContext = FoodiePrefetch.global.addPrefetchWork(for: story, on: story)
  }
  
  
  func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
    guard let annotation = view.annotation as? StoryMapAnnotation, let context = annotation.story.contentPrefetchContext else {
      CCLog.warning("No PrefetchContext associated with Story, or no StoryMapAnnotation associated with Annotation View")
      return
    }
    FoodiePrefetch.global.removePrefetchWork(for: context)
  }
}
