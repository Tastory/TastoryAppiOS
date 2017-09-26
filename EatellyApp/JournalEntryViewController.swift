//
//  JournalEntryViewController.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-03-26.
//  Copyright © 2017 Eatelly. All rights reserved.
//
//  This is a reusable Journal Entry View Controller
//  Input  - journalUnderEdit: Journal that this View Controller should be working on
//           newOrEdit: Is this a local Journal that's being drafted, or an existing Journal that's being edited?
//  Output - Save or Discard will have different action depending on if this is Drafting or Editing mode
//

import UIKit
import MapKit
import CoreLocation
import Jot


class JournalEntryViewController: UITableViewController, UIGestureRecognizerDelegate {
  
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
  fileprivate let activityView = UIActivityIndicatorView(activityIndicatorStyle: .gray)
  fileprivate var lastEditedMomentIdx: Int = -1
  
  // MARK: - IBOutlets
  @IBOutlet weak var titleTextField: UITextField?
  @IBOutlet weak var venueButton: UIButton?
  @IBOutlet weak var authorTextField: UITextField!
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
  
  @IBAction func testSaveJournal(_ sender: UIButton) {

    guard let journal = workingJournal else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("No Working Journal when user pressed Post Story")
    }
    
    guard journal.title != nil && journal.venue != nil else {
      AlertDialog.present(from: self, title: "Required Fields Empty", message: "The Title and Venue are essential to a Story!")
      return
    }
    
    guard let moments = journal.moments, !moments.isEmpty else {
      AlertDialog.present(from: self, title: "Story has No Moments", message: "Add some Moments to make this an interesting Story!")
      return
    }
    
    CCLog.info("User pressed 'Post Story'")
    
    // Block out user inputs until save completes - aka. No more Pre Saves are possible. Yay!
    UIApplication.shared.beginIgnoringInteractionEvents()
    activityView.center = self.view.center
    activityView.startAnimating()
    view.addSubview(activityView)

    // This will cause a save to both Local Cache and Server
    journal.saveRecursive(to: .both, type: .cache) { error in
      
      if let error = error {
        // Remove the spinner and resume user interaction
        DispatchQueue.main.async {
          self.activityView.stopAnimating()
          self.activityView.removeFromSuperview()
          UIApplication.shared.endIgnoringInteractionEvents()
          
          CCLog.warning("Save Story to Server Failed with Error: \(error)")
          AlertDialog.present(from: self, title: "Save Story to Server Failed", message: error.localizedDescription)
        }
      } else {
        
        // Now removing it from Draft - only if upload to server is a total success
        journal.deleteRecursive(from: .local, type: .draft) { error in
          FoodieJournal.removeCurrent()
          self.workingJournal = nil
          
          // Remove the spinner and resume user interaction
          DispatchQueue.main.async {
            self.activityView.stopAnimating()
            self.activityView.removeFromSuperview()
            UIApplication.shared.endIgnoringInteractionEvents()
            
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
    guard let text = sender.text, let journal = workingJournal, text != journal.title else {
      // Nothing changed, don't do anything
      return
    }
    
    CCLog.info("User edited Title of Story")
    journal.title = text
    preSave(nil, withBlock: nil)
  }
  

  @IBAction func editedAuthor(_ sender: UITextField) {
    guard let text = sender.text, let journal = workingJournal, text != journal.authorText else {
      // Nothing changed, don't do anything
      return
    }
    
    CCLog.info("User edited Author of Story")
    journal.authorText = text
    preSave(nil, withBlock: nil)
  }
  
  
  @IBAction func editedLink(_ sender: UITextField) {
    guard let text = sender.text, let journal = workingJournal, text != journal.journalURL else {
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
    journal.journalURL = validHttpText
    preSave(nil, withBlock: nil)
  }
  
  
  // MARK: - Private Instance Functions
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
  
  
  fileprivate func preSave(_ object: FoodieObjectDelegate?, withBlock callback: FoodieObject.SimpleErrorBlock?) {
    
    CCLog.debug("Pre-Save Operation Started")
    
    guard let journal = workingJournal else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("No Working Journal on Pre Save")
    }
    
    // Save Journal to Local
    journal.saveDigest(to: .local, type: .draft) { error in
      
      if let error = error {
        CCLog.warning("Journal pre-save to Local resulted in error - \(error.localizedDescription)")
        callback?(error)
        return
      }
      CCLog.debug("Completed pre-saving Journal to Local")
      
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

  func keyboardDismiss() {
    self.view.endEditing(true)
  }

  func vcDismiss() {
    // TODO: Data Passback through delegate?
    dismiss(animated: true, completion: nil)
  }

  func editMoment(_ sender: UIGestureRecognizer)
  {
     let point = sender.location(in: momentViewController.collectionView)

     if let indexPath = momentViewController.collectionView!.indexPathForItem(at: point) {
      guard let momentArray = workingJournal?.moments else {
        CCLog.fatal("No Moments but Moment Thumbnail long pressed? What?")
      }

      if(indexPath.row >= momentArray.count)
      {
        AlertDialog.present(from: self, title: "EatellyApp", message: "Error displaying media. Please try again") { action in
          CCLog.fatal("Moment selection is out of bound")
        }
      }

      let moment = momentArray[indexPath.row]
      let storyboard = UIStoryboard(name: "Main", bundle: nil)
      let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as! MarkupViewController
      viewController.markupReturnDelegate = self


      lastEditedMomentIdx = indexPath.row

      if let markups = moment.markups {
        var jotDictionary = [AnyHashable: Any]()
        var labelDictionary: [NSDictionary]?

        for markup in markups {

          if !markup.isDataAvailable {
            AlertDialog.present(from: self, title: "EatellyApp", message: "Error displaying media. Please try again") { action in
              CCLog.fatal("Markup not available even tho Moment deemed Loaded")
            }
          }

          guard let dataType = markup.dataType else {
            AlertDialog.present(from: self, title: "EatellyApp", message: "Error displaying media. Please try again") { action in
              CCLog.assert("Unexpected markup.dataType = nil")
            }
            return
          }

          guard let markupType = FoodieMarkup.dataTypes(rawValue: dataType) else {
            AlertDialog.present(from: self, title: "EatellyApp", message: "Error displaying media. Please try again") { action in
              CCLog.assert("markup.dataType did not actually translate into valid type")
            }
            return
          }

          switch markupType {

          case .jotLabel:
            guard let labelData = markup.data else {
              AlertDialog.present(from: self, title: "EatellyApp", message: "Error displaying media. Please try again") { action in
                CCLog.assert("Unexpected markup.data = nil when dataType == .jotLabel")
              }
              return
            }

            if labelDictionary == nil {
              labelDictionary = [labelData]
            } else {
              labelDictionary!.append(labelData)
            }

          case .jotDrawView:
            guard let drawViewDictionary = markup.data else {
              AlertDialog.present(from: self, title: "EatellyApp", message: "Error displaying media. Please try again") { action in
                CCLog.assert("Unexpected markup.data = nil when dataType == .jotDrawView")
              }
              return
            }

            jotDictionary[kDrawView] = drawViewDictionary
          }
        }
        
        jotDictionary[kLabels] = labelDictionary
        viewController.displayJotMarkups(dictionary: jotDictionary)

        guard let mediaObj = moment.mediaObj else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.assert("Nil media object in moment")
          }
          return
        }

        viewController.mediaObj = mediaObj
        self.present(viewController, animated: true)
      }
     }
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

    let tapRecognizer = UITapGestureRecognizer(target: self, action: "editMoment:")
    momentViewController.collectionView?.addGestureRecognizer(tapRecognizer)
 
    self.addChildViewController(momentViewController)
    momentViewController.didMove(toParentViewController: self)
    
    titleTextField?.delegate = self
    authorTextField?.delegate = self
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

      if let authorText = workingJournal.authorText {
        authorTextField?.text = authorText
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
            CCLog.warning("StoryEntryVC with no Venue or Moments Location. Getting location through LocationWatch also resulted in error - \(error.localizedDescription)")
            //self.updateStoryEntryMap(withCoordinate: Constants.defaultCLCoordinate2D, span: Constants.defaultDelta)  Just let it be a view of the entire North America I guess?
            return
          } else if let location = location {
            self.updateStoryEntryMap(withCoordinate: location.coordinate, span: Constants.suggestedDelta)
          }
        }
      }
      
      // Let's figure out what to do with the returned Moment
      if let moment = returnedMoment {
        if markupMoment != nil {
          // So there is a Moment under markup. The returned Moment should match this.
          if returnedMoment === markupMoment {
            
            // TODO: Gotta do a Moment Replace operation. See Foodie Object Model
            // Probably replace the Moment in Memory. Set the right flags so Pre-Upload will do the right things
            
          } else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain)
            CCLog.assert("returnedMoment expected to match markupMoment")
          }
        } else {
          
          // This is a new Moment. Let's add it to the Journal!
          workingJournal.add(moment: moment)
          
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
      } else {
        CCLog.debug("No Moment returned on viewWillAppear")
      }
      
    }
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    view.endEditing(true)
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
    
    CCLog.warning("JournalEntryViewController.didReceiveMemoryWarning")
  }
  
  deinit {
    CCLog.warning("JournalEntryViewController getting deinitialized")
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
    
    guard let _ = workingJournal else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("No Working Journal after Venue Search Completes")
    }
    
    // Query Parse to see if the Venue already exist
    let venueQuery = FoodieQuery()
    venueQuery.addFoursquareVenueIdFilter(id: venue.foursquareVenueID!)
    venueQuery.setSkip(to: 0)
    venueQuery.setLimit(to: 2)
    _ = venueQuery.addArrangement(type: .modificationTime, direction: .descending)
    
    venueQuery.initVenueQueryAndSearch { (queriedVenues, error) in
      
      if let error = error {
        AlertDialog.present(from: self, title: "Venue Error", message: "Unable to verify Venue against Eatelly database")
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

      // Let's set the Journal <=> Venue relationship right away
      self.workingJournal?.venue = venueToUpdate
      
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
          
          // Pre-save only the Journal to Local only
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

extension JournalEntryViewController: MarkupReturnDelegate {
  func markupComplete(markedupMoment: FoodieMoment, suggestedJournal: FoodieJournal?) {


    guard let mediaObj = markedupMoment.mediaObj else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Nil media object in moment")
      }
      return
    }

    guard let mediaFileName = mediaObj.foodieFileName else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Media file name doesn't exists")
      }
      return
    }

    guard let mediaType = mediaObj.mediaType else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Unknown media type")
      }
      return
    }

    var newFileName = FoodieFile.newPhotoFileName()
    let newMediaObj = FoodieMedia(for: newFileName, localType: .draft, mediaType: mediaType)

    if(mediaType  == .video) {
      newFileName = FoodieFile.newVideoFileName()
      newMediaObj.videoLocalBufferUrl = FoodieFile.getFileURL(for: .draft, with: newFileName)
    }

    // duplicate moment and delete moment
    FoodieFile.manager.copyFile(
      from: FoodieFile.getFileURL(for: .draft, with: mediaFileName),
      to: .draft,
      with: newFileName) { (error) in
        if (error != nil) {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.assert("Error copying moment media")
          }
        }

        // load new file location into buffer
        if(mediaType == .photo) {

          var uiimage: UIImage?

          do {
            try uiimage = UIImage(data: Data(contentsOf: FoodieFile.getFileURL(for: .draft, with: newFileName)))
          }
          catch {
            CCLog.verbose("Error info: \(error)")

            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
              CCLog.assert("Failed to load image from URL")
            }
          }

          guard let loadedImage = uiimage else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
              CCLog.assert("Failed to unwrap UIImage")
            }
            return
          }

          newMediaObj.imageMemoryBuffer = UIImageJPEGRepresentation(loadedImage, CGFloat(FoodieGlobal.Constants.JpegCompressionQuality))
        }

        // delete existing moment 

        guard let workingJournal = self.workingJournal else {
          AlertDialog.present(from: self, title: "EatellyApp", message: "Error displaying media. Please try again") { action in
            CCLog.fatal("Working journal is nil")
          }
          return
        }

        guard var momentArray = workingJournal.moments else {
          AlertDialog.present(from: self, title: "EatellyApp", message: "Error displaying media. Please try again") { action in
            CCLog.fatal("No Moments in working journal")
          }
          return
        }

        if(self.lastEditedMomentIdx >= momentArray.count || self.lastEditedMomentIdx <= 0)
        {
          AlertDialog.present(from: self, title: "EatellyApp", message: "Error displaying media. Please try again") { action in
            CCLog.fatal("Moment selection is out of bound")
          }
        }

        momentArray.remove(at: self.lastEditedMomentIdx)
        self.returnedMoment = markedupMoment
        self.markupMoment = markedupMoment

        DispatchQueue.main.async {
          self.dismiss(animated: true, completion: nil)
        }
        //momentArray.insert(markedupMoment, at: self.lastEditedMomentIdx)
    }
  }
}

