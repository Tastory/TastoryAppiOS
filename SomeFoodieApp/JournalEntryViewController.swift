//
//  JournalEntryViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-26.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//
//  This is a reusable Journal Entry View Controller
//  Input  - journalUnderEdit: Journal that this View Controller should be working on
//           newOrEdit: Is this a local Journal that's being drafted, or an existing Journal that's being edited?
//  Output - Save or Discard will have different action depending on if this is Drafting or Editing mode
//

import UIKit
import MapKit
import CoreLocation


class JournalEntryViewController: UITableViewController {
  
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
  var workingJournal: FoodieJournal?
  var returnedMoment: FoodieMoment?
  
  
  // MARK: - Private Instance Variables
  fileprivate var placeholderLabel = UILabel()
  fileprivate var momentViewController = MomentCollectionViewController()
  fileprivate var markupMoment: FoodieMoment? = nil

  fileprivate var isSaveInProgress = false
  fileprivate var triggerSaveJournal = false
  fileprivate var saveStateMutex = pthread_mutex_t()
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var titleTextField: UITextField?
  @IBOutlet weak var venueButton: UIButton?
  
  @IBOutlet weak var linkTextField: UITextField?
  @IBOutlet weak var tagsTextView: UITextView?
  
  
  // MARK: - IBActions
  @IBAction func venueClicked(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "VenueTableViewController") as! VenueTableViewController
    viewController.delegate = self
    viewController.suggestedVenue = workingJournal?.venue
    
    // Average the locations of the Moments to create a location suggestion on where to search for a Venue
    viewController.suggestedLocation = averageLocationOfMoments()
    self.present(viewController, animated: true)
  }
  
  @IBAction func testSaveJournal(_ sender: Any) {

    workingJournal?.title = titleTextField?.text
    workingJournal?.journalURL = linkTextField?.text
    
    guard workingJournal?.title != nil && workingJournal?.venue != nil else {
      AlertDialog.present(from: self, title: "Required Fields Empty", message: "The Title and Venue are essential to a Story!")
      return
    }
    
    guard let moments = workingJournal?.moments, !moments.isEmpty else {
      AlertDialog.present(from: self, title: "Story has No Moments", message: "Add some Moments to make this an interesting Story!")
      return
    }
    
    //TODO add spinner 
    UIApplication.shared.beginIgnoringInteractionEvents()
    
    DebugPrint.verbose("\(String(describing: self.workingJournal?.foodieObject.operationState))")

    //making sure that the operation state didnt change between checking and setting the flag
    pthread_mutex_lock(&self.saveStateMutex)

    if(isSaveInProgress)
    {
      triggerSaveJournal = true
    }
    pthread_mutex_unlock(&self.saveStateMutex)

    if(!triggerSaveJournal)
    {
      saveJournalToServer()
    }
  }
  
  
  // MARK: - Private Instance Functions
  fileprivate func saveJournalToServer() {
    triggerSaveJournal = false

    // journal is already saved to local
    self.workingJournal?.saveRecursive(to: .server) {(success, error) in
      if success {
        DebugPrint.verbose("Journal Save Completed!")
        AlertDialog.present(from: self, title: "Journal Save Completed!", message: "")
      } else if let error = error {
        DebugPrint.verbose("Journal Save to Server Failed with Error: \(error)")
      } else {
        DebugPrint.fatal("Journal Save to Server Failed without Error")
      }
      UIApplication.shared.endIgnoringInteractionEvents()
    }
  }
  
  fileprivate func averageLocationOfMoments() -> CLLocation? {
    
    var numValidCoordinates = 0
    var sumLatitude: Double?
    var sumLongitude: Double?
    
    guard let moments = workingJournal?.moments, !moments.isEmpty else {
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
    mapView.setRegion(region, animated: true)
    
    // Remove all annotations each time
    mapView.removeAnnotations(mapView.annotations)
    
    // Add back if an annotation is requested
    if let name = venueName {
      let annotation = MKPointAnnotation()
      annotation.coordinate = coordinate
      annotation.title = name
      mapView.addAnnotation(annotation)
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.mapView.selectAnnotation(annotation, animated: true) }  // This makes the Annotation title pop-up after a slight delay
    }
  }
  
  fileprivate func preSave(_ foodieObject: FoodieObjectDelegate?, withBlock callback: ((Error?) -> Void)?) {
    
    guard let journal = workingJournal else {
      DebugPrint.assert("JournalEntryViewController has no Working Journal?")
      AlertDialog.present(from: self, title: "Internal Error", message: "Unexpected Internal Error. Please try again")
      return
    }
    
    pthread_mutex_lock(&self.saveStateMutex)
    self.isSaveInProgress = true
    pthread_mutex_unlock(&self.saveStateMutex)
    
    // Save Journal to Local
    journal.saveRecursive(to: .local, withName: "workingJournal") { (_, error) -> Void in
      
      if let error = error {
        pthread_mutex_lock(&self.saveStateMutex)
        self.isSaveInProgress = false
        pthread_mutex_unlock(&self.saveStateMutex)
        
        DebugPrint.error("Journal pre-save to Local resulted in error - \(error.localizedDescription)")
        callback?(error)
        return
      }
      
      DebugPrint.verbose("Completed pre-saving Journal to Local")
      guard let foodieObject = foodieObject else {
        DebugPrint.log("No Foodie Object supplied on preSave(), skipping Object Server save")
        callback?(nil)
        return
      }
      
      foodieObject.saveRecursive(to: .server, withName: nil) { (success, error) -> Void in
      
        pthread_mutex_lock(&self.saveStateMutex)
        self.isSaveInProgress = false
        pthread_mutex_unlock(&self.saveStateMutex)
        
        if let error = error {
          DebugPrint.error("\(foodieObject.foodieObjectType()) pre-save to Server resulted in error - \(error.localizedDescription)")
          callback?(error)
          return
        }
        
        DebugPrint.verbose("Completed pre-saving \(foodieObject.foodieObjectType()) to Server")
        // If there's pending Journal Save, do it now
        if self.triggerSaveJournal { self.saveJournalToServer() }
        callback?(nil)
      }
    }
  }
  
  
  // MARK: - Public Instace Functions
  
  func keyboardDismiss() {
    self.view.endEditing(true)
  }
  
  func vcDismiss() {
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
    momentViewController.workingJournal = workingJournal
    momentViewController.momentHeight = Constants.momentHeight
    
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
    
    // TODO: Do we need to download the Journal itself first? How can we tell?
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    if let workingJournal = workingJournal {
      
      // Update all the fields here?
      if let title = workingJournal.title {
        titleTextField?.text = title
      }
      
      if let venueName = workingJournal.venue?.name {
        venueButton?.setTitle(venueName, for: .normal)
        venueButton?.setTitleColor(.black, for: .normal)
      } else {
        venueButton?.setTitle("Venue", for: .normal)
        venueButton?.setTitleColor(Constants.placeholderColor, for: .normal)
      }

      if let storyURL = workingJournal.journalURL {
        linkTextField?.text = storyURL
      }
      
      if let tags = workingJournal.tags, !tags.isEmpty {
        // TODO: Deal with tags here?
      } else {
        placeholderLabel = UILabel(frame: CGRect(x: 5, y: 7, width: 49, height: 19))
        placeholderLabel.text = "Tags" // TODO: Localization
        placeholderLabel.textColor = Constants.placeholderColor
        placeholderLabel.font = UIFont.systemFont(ofSize: 14)
        placeholderLabel.isHidden = !tagsTextView!.text.isEmpty
        tagsTextView?.addSubview(placeholderLabel)  // Remember to remove on the way out. There might be real Tags next time in the TextView
      }

      // Lets update the map location to the top here
      // If there's a Venue, use that location first. Usually if a venue have been freshly selected, it wouldn't have been confirmed in time. So another update is done in venueSearchComplete()
      if let latitude = workingJournal.venue?.location?.latitude,
        let longitude = workingJournal.venue?.location?.longitude {
        updateStoryEntryMap(withCoordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), span: Constants.venueDelta, venueName: workingJournal.venue?.name)
      }
      
      // Otherwise use the average location of the Moments
      else if let momentsLocation = averageLocationOfMoments() {
        updateStoryEntryMap(withCoordinate: momentsLocation.coordinate, span: Constants.suggestedDelta)
      }
      
      // Try to get a current location using the GPS
      else {
        LocationWatch.global.get { (location, error) in
          if let error = error {
            DebugPrint.error("StoryEntryVC with no Venue or Moments Location. Getting location through LocationWatch also resulted in error - \(error.localizedDescription)")
            //self.updateStoryEntryMap(withCoordinate: Constants.defaultCLCoordinate2D, span: Constants.defaultDelta)  Just let it be a view of the entire North America I guess?
            return
          } else if let location = location {
            self.updateStoryEntryMap(withCoordinate: location.coordinate, span: Constants.suggestedDelta)
          }
        }
      }
      
      // Let's figure out what to do with the returned Moment
      guard let moment = returnedMoment else {
        // Nothing needs to be done. Assume no moment returned.
        return
      }
        
      if markupMoment != nil {
        // So there is a Moment under markup. The returned Moment should match this.
        if returnedMoment === markupMoment {
          
          // TODO: Gotta do a Moment Replace operation. See Foodie Object Model
          // Probably replace the Moment in Memory. Set the right flags so Pre-Upload will do the right things
          
        } else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain)
          DebugPrint.assert("returnedMoment expected to match markupMoment")
        }
      } else {
        
        // This is a new Moment. Let's add it to the Journal!
        workingJournal.add(moment: moment)
        workingJournal.foodieObject.markModified()
        
        // If there wasn't any moments before, we got to make this the default thumbnail for the Journal
        // Got to do this also when removing moments!!!
        if workingJournal.moments!.count == 1 {
          // TODO: Do we need to factor out thumbnail operations?
          workingJournal.thumbnailFileName = moment.thumbnailFileName
          workingJournal.thumbnailObj = moment.thumbnailObj
        }
        
        preSave(moment) { (error) in
          if error != nil {  // Error code should've already been printed to the Debug log from preSave()
            AlertDialog.standardPresent(from: self, title: .genericSaveError, message: .internalTryAgain)
          }
          self.returnedMoment = nil  // We should be in a state where whom is the returned Moment should no longer matter
        }
      }
      
      // TODO: How to visually convey status of Moments to user??
    }
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    // This is for removing the fake Placeholder text from the Tags TextView
    placeholderLabel.removeFromSuperview()
    
    // We should clear this so we don't assume that we still have a returned moment
    returnedMoment = nil
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    DebugPrint.log("JournalEntryViewController.didReceiveMemoryWarning")
  }
}


// MARK: - Table View Data Source
extension JournalEntryViewController {
  
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
extension JournalEntryViewController {
  
  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let currentOffset = scrollView.contentOffset.y
    var height = Constants.mapHeight - currentOffset
    
    if height == 0 {
      DebugPrint.error("Height tried to be 0")
      height = 1
    } else {
      //DebugPrint.verbose("Height = \(height)")
    }
    
    // Need to take the ceiling as a 0 height with cause a crash
    mapView.frame = CGRect(x: 0, y: currentOffset, width: self.view.bounds.width, height: height)
  }
}


// MARK: - Tags TextView Delegate
extension JournalEntryViewController: UITextViewDelegate {
  func textViewDidChange(_ textView: UITextView) {
    placeholderLabel.isHidden = !textView.text.isEmpty
  }
}


// MARK: - Text Fields' Delegate
extension JournalEntryViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}


// MARK: - Venue Table Return Delegate
extension JournalEntryViewController: VenueTableReturnDelegate {
  func venueSearchComplete(venue: FoodieVenue) {
    
    // Query Parse to see if the Venue already exist
    let venueQuery = FoodieQuery()
    venueQuery.addFoursquareVenueIdFilter(id: venue.foursquareVenueID!)
    venueQuery.setSkip(to: 0)
    venueQuery.setLimit(to: 2)
    _ = venueQuery.addArrangement(type: .modificationTime, direction: .descending)
    
    venueQuery.initVenueQueryAndSearch { (queriedVenues, error) in
      
      if let error = error {
        AlertDialog.present(from: self, title: "Venue Error", message: "Unable to verify Venue against Eatelly database")
        DebugPrint.assert("Querying Parse for the Foursquare Venue ID resulted in Error - \(error.localizedDescription)")
        return
      }
      
      var venueToUpdate = venue
      
      if let queriedVenues = queriedVenues, !queriedVenues.isEmpty {
        if queriedVenues.count > 1 {
          DebugPrint.assert("More than 1 Venue returned from Parse for a single Foursquare Venue ID")
        }
        venueToUpdate = queriedVenues[0]
        venueToUpdate.foodieObject.markModified()
        // Do we have to fetch the rest of the Venue before we update and overwrite?
      }

      // Let's set the Journal <=> Venue relationship right away
      self.workingJournal?.venue = venueToUpdate
      
      // Do a full Venue Fetch from Foursquare
      venueToUpdate.getDetailsFromFoursquare { (_, error) in
        if let error = error {
          AlertDialog.present(from: self, title: "Venue Details Error", message: "Unable to obtain additional Details for Venue")
          DebugPrint.assert("Getting Venue Details from Foursquare resulted in Error - \(error.localizedDescription)")
          return
        }
        
        venueToUpdate.getHoursFromFoursquare { (_, error) in
          if let error = error {
            AlertDialog.present(from: self, title: "Venue Hours Detail Error", message: "Unable to obtain details regarding opening hours for Venue")
            DebugPrint.assert("Getting Venue Hours from Foursquare resulted in Error - \(error.localizedDescription)")
            return
          }
          
          // Update the UI again here
          if let name = venueToUpdate.name {
            self.venueButton?.setTitle(name, for: .normal)
            self.venueButton?.setTitleColor(.black, for: .normal)
          }
          
          // Update the map again here
          if let latitude = venueToUpdate.location?.latitude, let longitude = venueToUpdate.location?.longitude {
            self.updateStoryEntryMap(withCoordinate: CLLocationCoordinate2DMake(latitude, longitude), span: Constants.venueDelta, venueName: venueToUpdate.name)
          }
          
          // Pre-save the Venue
          self.preSave(venueToUpdate) { (error) in
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

