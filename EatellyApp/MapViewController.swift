//
//  MapViewController.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-03-20.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation


class MapViewController: UIViewController {

  // MARK: - Class Constants
  fileprivate struct Constants {
    static let defaultCLCoordinate2D = CLLocationCoordinate2D(latitude: CLLocationDegrees(49.2781372),
                                                              longitude: CLLocationDegrees(-123.1187237))  // This is set to Vancouver
    static let defaultMaxDelta: CLLocationDegrees = 0.05
    static let defaultMinDelta: CLLocationDegrees = 0.005
  }


  // MARK: - Instance Variables
  fileprivate var currentMapDelta = Constants.defaultMaxDelta
  fileprivate var locationWatcher: LocationWatch.Context?
  fileprivate var lastLocation: CLLocationCoordinate2D? = nil
  fileprivate var lastMapDelta: CLLocationDegrees? = nil
  fileprivate var searchCategory: FoodieCategory?
  fileprivate var storyQuery: FoodieQuery?
  fileprivate var storyArray = [FoodieJournal]()
  
  
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
  
  
  
  @IBAction func launchDraftJournal(_ sender: Any) {
    // This is used for viewing the draft journal to be used with update journal later
    // Hid the button due to problems with empty draft journal and saving an empty journal is problematic
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "JournalEntryViewController") as! JournalEntryViewController

    if(FoodieJournal.currentJournal == nil)
    {
      viewController.workingJournal =  FoodieJournal.newCurrent()
    }
    else
    {
      viewController.workingJournal = FoodieJournal.currentJournal
    }
    self.present(viewController, animated: true)
  }

  
  
  @IBAction func launchCamera(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "CameraViewController") as! CameraViewController
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
    currentMapDelta = min(currentMapDelta, Constants.defaultMaxDelta)

    // Take the greater of current or default min latitude degrees
    currentMapDelta = max(currentMapDelta, Constants.defaultMinDelta)

    // Start updating location again
    locationWatcher?.resume()
  }
  
  
  @IBAction func searchWithFilter(_ sender: UIButton) {
    
    // Kill all Pre-fetches
    FoodiePrefetch.global.removeAllPrefetchWork()
    
    performQuery { journals, error in
      if let error = error {
        AlertDialog.present(from: self, title: "Story Query Error", message: error.localizedDescription) { action in
          CCLog.assert("Story Query resulted in Error - \(error.localizedDescription)")
        }
        return
      }
      
      guard let journals = journals else {
        AlertDialog.present(from: self, title: "Story Query Error", message: "Story Query did not produce Stories") { action in
          CCLog.assert("Story Query resulted in nil")
        }
        return
      }
      
      self.displayAnnotations(onStories: journals)
    }
  }
  
  
  @IBAction func showFeed(_ sender: UIButton) {
    performQuery { journals, error in
      if let error = error {
        AlertDialog.present(from: self, title: "Story Query Error", message: error.localizedDescription) { action in
          CCLog.assert("Story Query resulted in Error - \(error.localizedDescription)")
        }
        return
      }
      
      guard let journals = journals else {
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
      
      self.launchFeed(withJournalArray: journals, withJournalQuery: query)
    }
  }
  
  
  
  // MARK: - Class Private Functions

  // Generic error dialog box to the user on internal errors
  fileprivate func internalErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "EatellyApp",
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
      let alertController = UIAlertController(title: "EatellyApp",
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
      let alertController = UIAlertController(title: "EatellyApp",
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
  
  
  fileprivate func performQuery(withBlock callback: FoodieQuery.JournalsErrorBlock?) {
    
    guard let currentMapView = mapView else {
      locationErrorDialog(message: "Invalid Map View. Search Location Undefined", comment: "Alert dialog message when mapView is nil when user attempted to perform Search")
      CCLog.assert("Search w/ Filter cannot be performed when mapView = nil")
      return
    }
    
    // Get South West corner coordinate and North East corner coordinate of the Map view
    let centerLatitude = currentMapView.region.center.latitude
    let centerLongitude = currentMapView.region.center.longitude
    let halfHeight = currentMapView.region.span.latitudeDelta/2
    let halfWidth = currentMapView.region.span.longitudeDelta/2
    let southWestCoordinate = CLLocationCoordinate2D(latitude: centerLatitude - halfHeight,
                                                     longitude: centerLongitude - halfWidth)
    let northEastCoordinate = CLLocationCoordinate2D(latitude: centerLatitude + halfHeight,
                                                     longitude: centerLongitude + halfWidth)
    
    CCLog.verbose("Query Location Rectangle SouthWest - (\(southWestCoordinate.latitude), \(southWestCoordinate.longitude)), NorthEast - (\(northEastCoordinate.latitude), \(northEastCoordinate.longitude))")
    
    storyQuery = FoodieQuery()
    storyQuery!.addLocationFilter(southWest: southWestCoordinate, northEast: northEastCoordinate)
    storyQuery!.setSkip(to: 0)
    storyQuery!.setLimit(to: FoodieGlobal.Constants.JournalFeedPaginationCount)
    _ = storyQuery!.addArrangement(type: .modificationTime, direction: .ascending) // TODO: - Should this be user configurable? Or eventualy we need a seperate function/algorithm that determins feed order

    // Put up blur view and activity spinner before performing query
    // TODO: We should factor these out so they can be used everywhere
    // See https://stackoverflow.com/questions/28785715/how-to-display-an-activity-indicator-with-text-on-ios-8-with-swift
    
    let blurEffect = UIBlurEffect(style: .light)
    let blurEffectView = UIVisualEffectView(effect: blurEffect)
    blurEffectView.frame = view.bounds
    blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(blurEffectView)
    
    let activityView = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
    activityView.center = self.view.center
    activityView.startAnimating()
    view.addSubview(activityView)
    
    // Actually do the Query
    storyQuery!.initJournalQueryAndSearch { (journals, error) in
      
      // Remove the blur view and activity spinner
      blurEffectView.removeFromSuperview()
      activityView.removeFromSuperview()
      
      if let err = error {
        self.queryErrorDialog()
        CCLog.assert("Create Journal Query & Search failed with error: \(err.localizedDescription)")
        callback?(nil, err)
        return
      }
      
      guard let journalArray = journals else {
        self.queryErrorDialog()
        CCLog.assert("Create Journal Query & Search returned with nil Journal Array")
        callback?(nil, nil)  // TODO: - Return a real error fucking
        return
      }
      
      self.storyArray = journalArray
      callback?(journalArray, nil)
    }
  }
  
  
  fileprivate func displayAnnotations(onStories stories: [FoodieJournal]) {

    DispatchQueue.main.async {
      self.mapView.removeAnnotations(self.mapView.annotations)
    }
    
    for story in stories {
      story.selfRetrieval { error in
        if let error = error {
          AlertDialog.present(from: self, title: "Story Retrieve Error", message: "Failed to retrieve Story Digest - \(error.localizedDescription)") { action in
            CCLog.assert("Failed to retrieve Story Digest via story.selfRetrieval. Error - \(error.localizedDescription)")
          }
          return
        }
      
        guard let title = story.title, let venue = story.venue, let location = venue.location else {
          CCLog.warning("No Title, Venue or Location to Story. Skipping Story")
          return
        }
        
        DispatchQueue.main.async {
          let annotation = StoryMapAnnotation(title: title,
                                              journal: story,
                                              coordinate: CLLocationCoordinate2D(latitude: location.latitude,
                                                                                 longitude: location.longitude))
          self.mapView.addAnnotation(annotation)
        }
      }
    }
  }
  
  
  fileprivate func launchFeed(withJournalArray journals: [FoodieJournal], withJournalQuery query: FoodieQuery) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "FeedCollectionViewController") as! FeedCollectionViewController
    viewController.journalQuery = query
    viewController.journalArray = journals
    viewController.restorationClass = nil
    self.present(viewController, animated: true)
  }
  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    mapView?.delegate = self
    panGestureRecognizer?.delegate = self
    pinchGestureRecognizer?.delegate = self
    doubleTapGestureRecognizer?.delegate = self
    singleTapGestureRecognizer?.delegate = self
    locationField?.delegate = self
    categoryField?.delegate = self
    
    // If current journal is nil, double check and see if there are any in Local Datastore
    if FoodieJournal.currentJournal == nil {
      
      FoodieQuery.getFirstStory(withName: FoodieGlobal.Constants.SavedDraftPinName) { (object, error) in
        
        if let error = error {
          CCLog.debug("No pinned draft Stories found in Local Datastore - \(error.localizedDescription)")
          return
        }
        
        guard let journal = object as? FoodieJournal else {
          CCLog.warning("Retrieve pinned Journal from Local Datastore is nil or not a FoodieJournal")
          return
        }
        
        journal.retrieveRecursive(forceAnyways: false) { error in
          
          if let error = error {
            CCLog.warning("Retrieve Recursive on Journal resulted in error - \(error.localizedDescription)")
            return
          }
          
          journal.foodieObject.markModified()
          FoodieJournal.setCurrentJournal(to: journal)
          self.draftButton?.isHidden = false
        }
      }
    }
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    
    // Kill all Pre-fetches
    FoodiePrefetch.global.removeAllPrefetchWork()
    
    // Provide a default Map Region incase Location Update is slow or user denies authorization
    let startMapLocation: CLLocationCoordinate2D = lastLocation ?? Constants.defaultCLCoordinate2D
    let startMapDelta: CLLocationDegrees = lastMapDelta ?? Constants.defaultMaxDelta
    
    let region = MKCoordinateRegion(center: startMapLocation,
                                    span: MKCoordinateSpan(latitudeDelta: startMapDelta, longitudeDelta: startMapDelta))
    mapView?.setRegion(region, animated: false)
    
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
    
    // Don't bother showing the Draft Button if there's no Draft
    if FoodieJournal.currentJournal == nil {
      draftButton?.isHidden = true
    } else {
      draftButton?.isHidden = false
    }
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    // Don't even know when we'll be back. Let the GPS stop if no one else is using it
    locationWatcher?.stop()
    
    // Keep track of what the location is before we disappear
    lastLocation = mapView?.centerCoordinate
    lastMapDelta = mapView?.region.span.latitudeDelta
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("MapViewController.didReceiveMemoryWarning")
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
        region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: Constants.defaultMaxDelta, longitudeDelta: Constants.defaultMaxDelta))

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
      let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "CategoryTableViewController") as! CategoryTableViewController
      viewController.delegate = self
      self.present(viewController, animated: true)
      return false
      
    } else {
      CCLog.assert("Unexpected call of textFieldShoudlBeginEditing on textField \(textField.placeholder ?? "")")
      return false
    }
  }

//  let userInfo = notification.userInfo!
//  let keyboardHeight = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue().height
//  let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as! Double
//  let curve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as! UInt
//  let moveUp = (notification.name == UIKeyboardWillShowNotification)
}


extension MapViewController: CameraReturnDelegate {
  func captureComplete(markedupMoment: FoodieMoment, suggestedJournal: FoodieJournal?) {
    DispatchQueue.main.async {  // UI Work. We don't know which thread we might be in, so guarentee execute in Main thread
      let storyboard = UIStoryboard(name: "Main", bundle: nil)
      let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "JournalEntryViewController") as! JournalEntryViewController
      
      var workingJournal: FoodieJournal?
      
      if let journal = suggestedJournal {
        workingJournal = journal
      } else if let journal = FoodieJournal.currentJournal {
        workingJournal = journal
      } else {
        workingJournal = FoodieJournal(withState: .objectModified)
      }
      
      viewController.workingJournal = workingJournal!
      viewController.returnedMoment = markedupMoment
      
      self.dismiss(animated: true) { /*[unowned self] in*/
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
    var story: FoodieJournal?
  }
  
  func storyCalloutTapped(sender: StoryButton) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "JournalViewController") as! JournalViewController
    
    guard let story = sender.story else {
      AlertDialog.present(from: self, title: "Story Load Error", message: "No Story was loaded for this location! Please try another one!") { action in
        CCLog.assert("No story contained in StoryButton clicked")
      }
      return
    }
    
    viewController.viewingJournal = story
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
    
    if let thumbnail = annotation.journal.thumbnailObj, let imageData = thumbnail.imageMemoryBuffer {
      
      let screenSize = UIScreen.main.bounds
      
      let calloutAccView = UIView()
      calloutAccView.translatesAutoresizingMaskIntoConstraints = false
      
      let titleLabel = UILabel()
      titleLabel.text = annotation.title
      titleLabel.font = UIFont.systemFont(ofSize: 17.0)
      titleLabel.textColor = UIColor.white
      titleLabel.textAlignment = .center
      titleLabel.numberOfLines = 3
      titleLabel.backgroundColor = UIColor(colorLiteralRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.2)
      titleLabel.isUserInteractionEnabled = false  // This is so that all the clicks go straight thru to the button at the back
      titleLabel.translatesAutoresizingMaskIntoConstraints = false
      
      if let venueName = annotation.journal.venue?.name {
        annotation.title = "@ "
        if venueName.characters.count < 22 {
          annotation.title! += venueName
        } else {
          let index = venueName.index(venueName.startIndex, offsetBy: 22)
          annotation.title! += venueName.substring(to: index)
          annotation.title! += "..."
        }
      } else { annotation.title = " " }
      
      
      let thumbnailButton = StoryButton()
      thumbnailButton.setImage(UIImage(data: imageData), for: .normal)
      thumbnailButton.translatesAutoresizingMaskIntoConstraints = false
      thumbnailButton.story = annotation.journal
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
        CCLog.warning("No Thumbnail for Story in Map View. Thumbnail filename - \(annotation.journal.thumbnailFileName ?? "Filename Not Found")")
      }
    }
    return view
  }
  
  
  func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    guard let annotation = view.annotation as? StoryMapAnnotation else {
      CCLog.warning("No StoryMapAnnotation associated with Annotation View")
      return
    }
    let story = annotation.journal
    story.contentPrefetchContext = FoodiePrefetch.global.addPrefetchWork(for: story, on: story)
  }
  
  
  func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
    guard let annotation = view.annotation as? StoryMapAnnotation, let context = annotation.journal.contentPrefetchContext else {
      CCLog.warning("No PrefetchContext associated with Story, or no StoryMapAnnotation associated with Annotation View")
      return
    }
    FoodiePrefetch.global.removePrefetchWork(for: context)
  }
}
