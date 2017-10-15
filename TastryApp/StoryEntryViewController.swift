//
//  StoryEntryViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-03-26.
//  Copyright © 2017 Tastry. All rights reserved.
//
//  This is a reusable Story Entry View Controller
//  Input  - storyUnderEdit: Story that this View Controller should be working on
//           newOrEdit: Is this a local Story that's being drafted, or an existing Story that's being edited?
//  Output - Save or Discard will have different action depending on if this is Drafting or Editing mode
//

import UIKit
import MapKit
import CoreLocation

protocol CameraDelegate {
  func openCamera()
}

class StoryEntryViewController: UITableViewController, UIGestureRecognizerDelegate {
  
  // MARK: - Private Static Constants
  fileprivate struct Constants {
    static let mapHeight: CGFloat = floor(UIScreen.main.bounds.height/4)
    static let momentHeight: CGFloat = floor(UIScreen.main.bounds.height/3)
    static let placeholderColor = UIColor(red: 0xC8/0xFF, green: 0xC8/0xFF, blue: 0xC8/0xFF, alpha: 1.0)
    static let defaultCLCoordinate2D = CLLocationCoordinate2D(latitude: CLLocationDegrees(49.2781372),
                                                              longitude: CLLocationDegrees(-123.1187237))  // This is set to Vancouver
    static let defaultDelta: CLLocationDegrees = 0.05
    static let suggestedDelta: CLLocationDegrees = 0.02
    static let venueDelta: CLLocationDegrees = 0.005
  }


  // MARK: - Private Instance Constants
  fileprivate let sectionOneView = UIView()
  fileprivate let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: Constants.mapHeight))


  // MARK: - Public Instance Variable
  var workingStory: FoodieStory?
  var returnedMoments: [FoodieMoment] = []
  var markupMoment: FoodieMoment? = nil
  var containerVC: MarkupReturnDelegate?
  
  // MARK: - Private Instance Variables
  fileprivate var placeholderLabel = UILabel()
  fileprivate var momentViewController = MomentCollectionViewController()
  fileprivate var selectedViewCell: MomentCollectionViewCell?

  // MARK: - IBOutlets
  @IBOutlet weak var titleTextField: UITextField?
  @IBOutlet weak var venueButton: UIButton?
  @IBOutlet weak var linkTextField: UITextField?
  @IBOutlet weak var tagsTextView: UITextView?


  // MARK: - IBActions
  @IBAction func venueClicked(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "VenueTableViewController") as? VenueTableViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of VenueTableViewController Class!!")
      }
      return
    }
    viewController.delegate = self
    viewController.suggestedVenue = workingStory?.venue
    
    // Average the locations of the Moments to create a location suggestion on where to search for a Venue
    viewController.suggestedLocation = averageLocationOfMoments()
    viewController.setTransition(presentTowards: .left, dismissTowards: .right, dismissIsDraggable: true, dragDirectionIsFixed: true)
    self.present(viewController, animated: true)
  }
  
  @IBAction func previewStory(_ sender: Any) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryViewController") as! StoryViewController
    viewController.viewingStory = workingStory
    self.present(viewController, animated: true)
  }

  @IBAction func testSaveStory(_ sender: UIButton) {

    guard let story = workingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("No Working Story when user pressed Post Story")
    }
    
    guard let currentUser = FoodieUser.current else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("No Current User Logged In")
    }
    
    guard let title = story.title, title != "", story.venue != nil else {
      AlertDialog.present(from: self, title: "Required Fields Empty", message: "The Title and Venue are essential to a Story!")
      return
    }
    
    guard let moments = story.moments, !moments.isEmpty else {
      AlertDialog.present(from: self, title: "Story has No Moments", message: "Add some Moments to make this an interesting Story!")
      return
    }
    
    CCLog.info("User pressed 'Post Story'")
    
    view.endEditing(true)
    let blurSpinner = BlurSpinWait()
    blurSpinner.apply(to: self.view, blurStyle: .dark, spinnerStyle: .whiteLarge)

    // This will cause a save to both Local Cache and Server
    story.saveRecursive(to: .both, type: .cache) { error in
      
      if let error = error {
        blurSpinner.remove()
        CCLog.warning("Save Story to Server Failed with Error: \(error)")
        AlertDialog.present(from: self, title: "Save Story to Server Failed", message: error.localizedDescription)
      } else {
        
        // Add this Story to the User's authored list
        currentUser.addAuthoredStory(story) { error in
          
          if let error = error {
            // Best effort remove the Story from Server & Cache in this case
            story.deleteRecursive(from: .both, type: .cache, withBlock: nil)
            
            blurSpinner.remove()
            CCLog.warning("Add Story to User List Failed with Error: \(error)")
            AlertDialog.present(from: self, title: "Add Story to User Failed", message: error.localizedDescription)
          }
        
          // Now removing it from Draft - only if upload to server is a total success
          story.deleteRecursive(from: .local, type: .draft) { error in
            if let error = error {
              CCLog.warning("Deleting Story from Local Draft Failed with Error: \(error)")
            }
            
            FoodieStory.removeCurrent()
            self.workingStory = nil
            blurSpinner.remove()
            
            // Pop-up Alert Dialog and then Dismiss
            CCLog.info("Story Posted!")
            AlertDialog.present(from: self, title: "Story Posted", message: "Thanks for telling your Story!") { _ in
              self.vcDismiss()
            }
          }
        }
      }
    }
  }
  

  @IBAction func editedTitle(_ sender: UITextField) {
    guard let text = sender.text, let story = workingStory, text != story.title else {
      // Nothing changed, don't do anything
      return
    }
    
    CCLog.info("User edited Title of Story")
    story.title = text
    preSave(nil, withBlock: nil)
  }
  
  
  @IBAction func editedLink(_ sender: UITextField) {
    guard let text = sender.text, let story = workingStory, text != story.storyURL, text != "" else {
      // Nothing changed, don't do anything
      return
    }
    
    var validHttpText = text
    let lowercaseText = text.lowercased()
    
    if !lowercaseText.hasPrefix("http://") && !lowercaseText.hasPrefix("https://") {
      validHttpText = "http://" + text
      linkTextField?.text = validHttpText
    }
    
    CCLog.info("User edited Link of Story")
    story.storyURL = validHttpText
    preSave(nil, withBlock: nil)
  }
  
  
  // MARK: - Private Instance Functions
  fileprivate func averageLocationOfMoments() -> CLLocation? {
    
    var numValidCoordinates = 0
    var sumLatitude: Double?
    var sumLongitude: Double?
    
    guard let moments = workingStory?.moments, !moments.isEmpty else {
      return nil
    }
    
    for moment in moments {
      if let location = moment.location {
        sumLatitude = location.latitude + (sumLatitude ?? 0)
        sumLongitude = location.longitude + (sumLongitude ?? 0)
        numValidCoordinates += 1
      }
    }
    
    if numValidCoordinates != 0, let latitude = sumLatitude, let longitude = sumLongitude {
      return CLLocation.init(latitude: latitude/Double(numValidCoordinates),
                             longitude: longitude/Double(numValidCoordinates))
    } else {
      return nil
    }
  }

  fileprivate func updateStoryEntryMap(withCoordinate coordinate: CLLocationCoordinate2D, span: CLLocationDegrees, venueName: String? = nil) {
    let region = MKCoordinateRegion(center: coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
    DispatchQueue.main.async {
      self.mapView.setRegion(region, animated: true)
      
      // Remove all annotations each time
      self.mapView.removeAnnotations(self.mapView.annotations)
      
      // Add back if an annotation is requested
      if let name = venueName {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = name
        self.mapView.addAnnotation(annotation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.mapView.selectAnnotation(annotation, animated: true) }  // This makes the Annotation title pop-up after a slight delay
      }
    }
  }
  
  
  fileprivate func preSave(_ object: FoodieObjectDelegate?, withBlock callback: SimpleErrorBlock?) {
    
    CCLog.debug("Pre-Save Operation Started")
    
    guard let story = workingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("No Working Story on Pre Save")
    }
    
    // Save Story to Local
    story.saveDigest(to: .local, type: .draft) { error in
      
      if let error = error {
        CCLog.warning("Story pre-save to Local resulted in error - \(error.localizedDescription)")
        callback?(error)
        return
      }
      CCLog.debug("Completed pre-saving Story to Local")
      
      guard let object = object else {
        CCLog.debug("No Foodie Object supplied on preSave(), skipping Object Server save")
        callback?(nil)
        return
      }
      
      object.saveRecursive(to: .both, type: .draft) { error in
        
        if let error = error {
          CCLog.warning("\(object.foodieObjectType()) pre-save to local & server resulted in error - \(error.localizedDescription)")
          callback?(error)
          return
        }
        
        CCLog.debug("Completed Pre-Saving \(object.foodieObjectType()) to Server")
        callback?(nil)
      }
    }
  }


  // MARK: - Public Instace Functions
  @objc func editMoment(_ sender: UIGestureRecognizer)
  {
    let point = sender.location(in: momentViewController.collectionView)

    guard let indexPath = momentViewController.collectionView!.indexPathForItem(at: point) else {
      // invalid index path selected just return
      return
    }

    guard let momentArray = workingStory?.moments else {
      CCLog.fatal("No moments in current working story.")
    }

    guard let markupReturnVC = containerVC else {
      CCLog.fatal("Story Entry VC does not have a Container VC")
    }
    
    
    if(indexPath.row >= momentArray.count)
    {
      AlertDialog.present(from: self, title: "TastryApp", message: "Error displaying media. Please try again") { action in
        CCLog.fatal("Moment selection is out of bound")
      }
    }

    let moment = momentArray[indexPath.row]
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as? MarkupViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of MarkupViewController Class!!")
      }
      return
    }
    viewController.markupReturnDelegate = markupReturnVC

    guard let mediaObj = moment.mediaObj else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Nil media object in moment")
      }
      return
    }

    viewController.mediaObj = mediaObj
    viewController.editMomentObj = moment
    viewController.addToExistingStoryOnly = true
    viewController.setTransition(presentTowards: .up, dismissTowards: .down, dismissIsDraggable: false)
    self.present(viewController, animated: true)
    
  }

  @objc func keyboardDismiss() {
    self.view.endEditing(true)
  }

  @objc func reorderMoment(_ gesture: UILongPressGestureRecognizer) {

    guard let collectionView = momentViewController.collectionView else {
      CCLog.assert("Error unwrapping the collectionView from moment view controller is nil")
      return
    }

    switch(gesture.state) {

    case UIGestureRecognizerState.began:
      guard let selectedIndexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView)) else {
        break
      }
      collectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
      selectedViewCell = collectionView.cellForItem(at: selectedIndexPath) as? MomentCollectionViewCell

      guard let selectedCell = selectedViewCell else {
        CCLog.assert("Can't get momentCollectionViewCell from collection view")
        return
      }

      selectedCell.wobble()
    case UIGestureRecognizerState.changed:
      collectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
    case UIGestureRecognizerState.ended:
      collectionView.endInteractiveMovement()

      if(selectedViewCell != nil) {
        selectedViewCell!.stopWobble()

        guard let story = workingStory else {
          CCLog.assert("workingStory is nil")
          return
        }

        // Pre-save the Story now that it's changed
        story.saveDigest(to: .local, type: .draft) { error in
          if let error = error {
            AlertDialog.present(from: self, title: "Pre-Save Failed!", message: "Problem saving Story to Local Draft! Quitting or backgrounding the app might cause lost of the current Story under Draft!") { action in
              CCLog.assert("Pre-Saving Story to Draft Local Store Failed - \(error.localizedDescription)")
            }
          }
        }
      }

    default:
      collectionView.cancelInteractiveMovement()
    }
  }

  @objc func setThumbnail(_ sender: UIGestureRecognizer) {

    let point = sender.location(in: momentViewController.collectionView)

    guard let indexPath = momentViewController.collectionView!.indexPathForItem(at: point) else {
      // invalid index path selected just return
      return
    }
    momentViewController.setThumbnail(indexPath)

    // save journal
    preSave(nil) { (error) in
      if error != nil {  // preSave should have logged the error, so skipping that here.
        AlertDialog.standardPresent(from: self, title: .genericSaveError, message: .saveTryAgain)
        return
      }
    }

  }

  @objc func vcDismiss() {
    // TODO: Data Passback through delegate?
    dismiss(animated: true, completion: nil)
  }

  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Setup the View, Moment VC, Text Fields, Keyboards, etc.
    mapView.showsUserLocation = true
    sectionOneView.addSubview(mapView)
    
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    momentViewController = storyboard.instantiateViewController(withIdentifier: "MomentCollectionViewController") as! MomentCollectionViewController
    momentViewController.workingStory = workingStory
    momentViewController.momentHeight = Constants.momentHeight
    momentViewController.cameraReturnDelegate = self

    guard let collectionView = momentViewController.collectionView else {
      CCLog.fatal("collection view from momentViewController is nil")
    }

    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(setThumbnail(_:)))
    tapRecognizer.numberOfTapsRequired = 1
    collectionView.addGestureRecognizer(tapRecognizer)

    let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(editMoment(_:)))
    doubleTapRecognizer.numberOfTapsRequired = 2
    collectionView.addGestureRecognizer(doubleTapRecognizer)

    tapRecognizer.require(toFail: doubleTapRecognizer)

    let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(reorderMoment(_:)))
    collectionView.addGestureRecognizer(longPressGesture)

    self.addChildViewController(momentViewController)
    momentViewController.didMove(toParentViewController: self)
    
    titleTextField?.delegate = self
    linkTextField?.delegate = self
    tagsTextView?.delegate = self
    
    let keyboardDismissRecognizer = UITapGestureRecognizer(target: self, action: #selector(keyboardDismiss))
    keyboardDismissRecognizer.numberOfTapsRequired = 1
    keyboardDismissRecognizer.numberOfTouchesRequired = 1
    tableView.addGestureRecognizer(keyboardDismissRecognizer)
    
    let previousSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(vcDismiss))
    previousSwipeRecognizer.direction = .right
    previousSwipeRecognizer.numberOfTouchesRequired = 1
    tableView.addGestureRecognizer(previousSwipeRecognizer)

    // TODO: Do we need to download the Story itself first? How can we tell?
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    if let workingStory = workingStory {
      
      // Update all the fields here?
      if let title = workingStory.title {
        titleTextField?.text = title
      }
      
      if let venueName = workingStory.venue?.name {
        venueButton?.setTitle(venueName, for: .normal)
        venueButton?.setTitleColor(.black, for: .normal)
      } else {
        venueButton?.setTitle("Venue", for: .normal)
        venueButton?.setTitleColor(Constants.placeholderColor, for: .normal)
      }
      
      if let storyURL = workingStory.storyURL, storyURL != "" {
        linkTextField?.text = storyURL
      }
      
      if let tags = workingStory.tags, !tags.isEmpty {
        // TODO: Deal with tags here?
      } else {
        placeholderLabel = UILabel(frame: CGRect(x: 0, y: 7, width: 50, height: 20))
        placeholderLabel.text = "Tags" // TODO: Localization
        placeholderLabel.textColor = Constants.placeholderColor
        placeholderLabel.font = UIFont.systemFont(ofSize: 14.5)
        placeholderLabel.isHidden = !tagsTextView!.text.isEmpty
        tagsTextView?.addSubview(placeholderLabel)  // Remember to remove on the way out. There might be real Tags next time in the TextView
      }

      // Lets update the map location to the top here
      // If there's a Venue, use that location first. Usually if a venue have been freshly selected, it wouldn't have been confirmed in time. So another update is done in venueSearchComplete()
      if let latitude = workingStory.venue?.location?.latitude,
        let longitude = workingStory.venue?.location?.longitude {
        updateStoryEntryMap(withCoordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), span: Constants.venueDelta, venueName: workingStory.venue?.name)
      }
      
      // Otherwise use the average location of the Moments
      else if let momentsLocation = averageLocationOfMoments() {
        updateStoryEntryMap(withCoordinate: momentsLocation.coordinate, span: Constants.suggestedDelta)
      }
      
      // Try to get a current location using the GPS
      else {
        LocationWatch.global.get { (location, error) in
          if let error = error {
            CCLog.warning("StoryEntryVC with no Venue or Moments Location. Getting location through LocationWatch also resulted in error - \(error.localizedDescription)")
            //self.updateStoryEntryMap(withCoordinate: Constants.defaultCLCoordinate2D, span: Constants.defaultDelta)  Just let it be a view of the entire North America I guess?
            return
          } else if let location = location {
            self.updateStoryEntryMap(withCoordinate: location.coordinate, span: Constants.suggestedDelta)
          }
        }
      }

      for returnedMoment in returnedMoments {
        // Let's figure out what to do with the returned Moment
        if markupMoment != nil {
          // So there is a Moment under markup. The returned Moment should match this.
          if returnedMoment === markupMoment {

            // save to local
            returnedMoment.saveRecursive(to: .local, type: .draft) { error in
              if let error = error {
                AlertDialog.standardPresent(from: self, title: .genericSaveError, message: .saveTryAgain) { action in
                  CCLog.assert("Error saving moment into local caused by: \(error.localizedDescription)")
                }
              }
            }
          } else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain)
            CCLog.assert("returnedMoment expected to match markupMoment")
          }
        } else {

          // This is a new Moment. Let's add it to the Story!
          workingStory.add(moment: returnedMoment)

          // If there wasn't any moments before, we got to make this the default thumbnail for the Story
          // Got to do this also when removing moments!!!
          if workingStory.moments!.count == 1 {
            // TODO: Do we need to factor out thumbnail operations?
            workingStory.thumbnailFileName = returnedMoment.thumbnailFileName
            workingStory.thumbnailObj = returnedMoment.thumbnailObj
          }

          preSave(returnedMoment) { (error) in
            if error != nil {  // Error code should've already been printed to the Debug log from preSave()
              AlertDialog.standardPresent(from: self, title: .genericSaveError, message: .internalTryAgain)
            }
            //self.returnedMoment = nil  // We should be in a state where whom is the returned Moment should no longer matter
          }
        }
      }
    }
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    view.endEditing(true)
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    // This is for removing the fake Placeholder text from the Tags TextView
    placeholderLabel.removeFromSuperview()
    
    // We should clear this so we don't assume that we still have a returned moment
    returnedMoments.removeAll()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("didReceiveMemoryWarning")
  }
  
}



// MARK: - Table View Data Source
extension StoryEntryViewController {
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    switch section {
    case 0:
      return sectionOneView
    case 1:
      return momentViewController.collectionView! as UIView
    default:
      return nil
    }
  }
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    switch section {
    case 0:
      return Constants.mapHeight
    case 1:
      return Constants.momentHeight
    default:
      return 0
    }
  }
  
  override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return 1
  }
}


// MARK: - Scroll View Delegate
extension StoryEntryViewController {
  
  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let currentOffset = scrollView.contentOffset.y
    let height = Constants.mapHeight - currentOffset
    
    if height <= 10 {
      // CCLog.verbose("Height tried to be < 10")
      mapView.isHidden = true
    } else {
      mapView.isHidden = false
      mapView.frame = CGRect(x: 0, y: currentOffset, width: self.view.bounds.width, height: height)
    }
  }
}


// MARK: - Tags TextView Delegate
extension StoryEntryViewController: UITextViewDelegate {
  func textViewDidChange(_ textView: UITextView) {
    placeholderLabel.isHidden = !textView.text.isEmpty
  }
}


// MARK: - Text Fields' Delegate
extension StoryEntryViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}


// MARK: - Venue Table Return Delegate
extension StoryEntryViewController: VenueTableReturnDelegate {
  func venueSearchComplete(venue: FoodieVenue) {
    
    guard let _ = workingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("No Working Story after Venue Search Completes")
    }
    
    // Query Parse to see if the Venue already exist
    let venueQuery = FoodieQuery()
    venueQuery.addFoursquareVenueIdFilter(id: venue.foursquareVenueID!)
    venueQuery.setSkip(to: 0)
    venueQuery.setLimit(to: 2)
    _ = venueQuery.addArrangement(type: .modificationTime, direction: .descending)
    
    venueQuery.initVenueQueryAndSearch { (queriedVenues, error) in
      
      if let error = error {
        AlertDialog.present(from: self, title: "Venue Error", message: "Unable to verify Venue against Tastry database")
        CCLog.assert("Querying Parse for the Foursquare Venue ID resulted in Error - \(error.localizedDescription)")
        return
      }
      
      var venueToUpdate = venue
      
      if let queriedVenues = queriedVenues, !queriedVenues.isEmpty {
        if queriedVenues.count > 1 {
          CCLog.assert("More than 1 Venue returned from Parse for a single Foursquare Venue ID")
        }
        venueToUpdate = queriedVenues[0]
      }

      // Let's set the Story <=> Venue relationship right away
      self.workingStory?.venue = venueToUpdate
      
      // Do a full Venue Fetch from Foursquare
      venueToUpdate.getDetailsFromFoursquare { (_, error) in
        if let error = error {
          AlertDialog.present(from: self, title: "Venue Details Error", message: "Unable to obtain additional Details for Venue")
          CCLog.assert("Getting Venue Details from Foursquare resulted in Error - \(error.localizedDescription)")
          return
        }
        
        venueToUpdate.getHoursFromFoursquare { (_, error) in
          if let error = error {
            AlertDialog.present(from: self, title: "Venue Hours Detail Error", message: "Unable to obtain details regarding opening hours for Venue")
            CCLog.assert("Getting Venue Hours from Foursquare resulted in Error - \(error.localizedDescription)")
            return
          }
          
          // Update the UI again here
          if let name = venueToUpdate.name {
            DispatchQueue.main.async {
              self.venueButton?.setTitle(name, for: .normal)
              self.venueButton?.setTitleColor(.black, for: .normal)
            }
          }
          
          // Update the map again here
          if let latitude = venueToUpdate.location?.latitude, let longitude = venueToUpdate.location?.longitude {
            self.updateStoryEntryMap(withCoordinate: CLLocationCoordinate2DMake(latitude, longitude), span: Constants.venueDelta, venueName: venueToUpdate.name)
          }
          
          // Pre-save only the Story to Local only
          self.preSave(nil) { (error) in
            if error != nil {  // preSave should have logged the error, so skipping that here.
              AlertDialog.standardPresent(from: self, title: .genericSaveError, message: .saveTryAgain)
              return
            }
          }
        }
      }
    }
  }
}



extension StoryEntryViewController: CameraReturnDelegate {
  func captureComplete(markedupMoments: [FoodieMoment], suggestedStory: FoodieStory?) {
    self.returnedMoments = markedupMoments
    self.markupMoment = nil

    dismiss(animated: true) {
      if let workingStory = self.workingStory {
        guard let collectionView = self.momentViewController.collectionView else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.fatal("collection view is nil")
          }
          return
        }
        guard let moments = workingStory.moments else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.fatal("Moments in working journal is nil")
          }
          return
        }

        // this updates the collectionView and must be done when story entry view is visible
        // NEVER run the following code when collection view is not visible. It will crash!!!!!
        collectionView.insertItems(at: [IndexPath( item: moments.count - 1, section: 0)])
      }
    }
  }
}

