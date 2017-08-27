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
import Parse


class JournalEntryViewController: UITableViewController {
  
  // MARK: - Private Static Constants
  fileprivate struct Constants {
    static let mapHeight: CGFloat = floor(UIScreen.main.bounds.height/4)
    static let momentHeight: CGFloat = floor(UIScreen.main.bounds.height/3)
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
  @IBOutlet weak var tagsTextView: UITextView? {
    didSet {
      placeholderLabel = UILabel(frame: CGRect(x: 5, y: 7, width: 49, height: 19))
      placeholderLabel.text = "Tags" // TODO: Localization
      placeholderLabel.textColor = UIColor(red: 0xC8/0xFF, green: 0xC8/0xFF, blue: 0xC8/0xFF, alpha: 1.0)
      placeholderLabel.font = UIFont.systemFont(ofSize: 14)
      placeholderLabel.isHidden = !tagsTextView!.text.isEmpty
      tagsTextView?.addSubview(placeholderLabel)
    }
  }
  
  
  // MARK: - IBActions
  @IBAction func venueClicked(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "VenueTableViewController") as! VenueTableViewController
    viewController.delegate = self
    viewController.suggestedVenue = workingJournal?.venue
    
    // Average the locations of the Moments to create a location suggestion on where to search for a Venue
    if let moments = workingJournal?.moments {
      viewController.suggestedLocation = averageLocationOf(moments: moments)
    }
    self.present(viewController, animated: true)
  }
  
  @IBAction func testSaveJournal(_ sender: Any) {

    //TODO add spinner 
    UIApplication.shared.beginIgnoringInteractionEvents()
    
    workingJournal?.title = titleTextField?.text
    workingJournal?.journalURL = linkTextField?.text
    
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
        DebugPrint.verbose("Journal Save to Server Completed!")
        self.saveCompleteDialog()
      } else if let error = error {
        DebugPrint.verbose("Journal Save to Server Failed with Error: \(error)")
      } else {
        DebugPrint.fatal("Journal Save to Server Failed without Error")
      }
      UIApplication.shared.endIgnoringInteractionEvents()
    }
  }
  
  fileprivate func averageLocationOf(moments: [FoodieMoment]) -> CLLocation? {
    
    var numValidCoordinates = 0
    var sumLatitude: Double?
    var sumLongitude: Double?
    
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
  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if let journalUnwrapped = workingJournal {
      // TODO: Do we need to download the Journal itself first? How can we tell?
      
      
      // Let's figure out what to do with the returned Moment
      if returnedMoment == nil {
        // Nothing needs to be done. Assume no moment returned.
        
      } else if markupMoment != nil {
        
        // So there is a Moment under markup. The returned Moment should match this.
        if returnedMoment === markupMoment {
          
          // TODO: Gotta do a Moment Replace operation. See Foodie Object Model
          // Probably replace the Moment in Memory. Set the right flags so Pre-Upload will do the right things
          
        } else {
          internalErrorDialog()
          DebugPrint.assert("returnedMoment expected to match markupMoment")
        }
      } else {

        // TODO refactor out to journal
        // This is a new Moment. Let's add it to the Journal!
        journalUnwrapped.add(moment: returnedMoment!)
        journalUnwrapped.foodieObject.markModified()
        
        // If there wasn't any moments before, we got to make this the default thumbnail for the Journal
        // Got to do this also when removing moments!!!
        if journalUnwrapped.moments!.count == 1 {
          // TODO: Do we need to factor out thumbnail operations?
          journalUnwrapped.thumbnailFileName = returnedMoment!.thumbnailFileName
          journalUnwrapped.thumbnailObj = returnedMoment!.thumbnailObj
        }
        
        // only save to local when the journal is modified
        if(journalUnwrapped.foodieObject.operationState == .objectModified) {
          // save journal to local
          journalUnwrapped.saveRecursive(to: .local, withName: "workingJournal", withBlock: { (success,error)-> Void in
            if(success) {
              DebugPrint.verbose("Completed saving journal to local")
              // save recursive from journal already saved moment to .local
              // need to save to server for the moments

              pthread_mutex_lock(&self.saveStateMutex)
              self.isSaveInProgress = true
              pthread_mutex_unlock(&self.saveStateMutex)

              self.returnedMoment!.saveRecursive(to: .server, withBlock: { (success, error) -> Void in
                if(success)
                {
                  pthread_mutex_lock(&self.saveStateMutex)
                  self.isSaveInProgress = false
                  pthread_mutex_unlock(&self.saveStateMutex)
                  if(self.triggerSaveJournal)
                  {
                    self.saveJournalToServer()
                  }
                }
              })
            }
          })
        }
        else {
          // temporarily save to moments to server
          returnedMoment!.saveRecursive(to: .local, withBlock: {(success, error) -> Void in
            self.returnedMoment!.saveRecursive(to: .server, withBlock: { (success, error) -> Void in
              if(success)
              {
                pthread_mutex_lock(&self.saveStateMutex)
                self.isSaveInProgress = false
                pthread_mutex_unlock(&self.saveStateMutex)
                if(self.triggerSaveJournal)
                {
                  self.saveJournalToServer()
                }
              }
            })
          })
        }
      }
    }
    initializeJournalController()
  }
  
  
  fileprivate func initializeJournalController() {
    // TODO: How to visually convey status of Moments to user??
    
    // Setup the View, Moment VC, Text Fields, Keyboards, etc.
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
    
    titleTextField?.text = workingJournal?.title
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    // Start pre-upload operations, and other background trickeries
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    DebugPrint.log("JournalEntryViewController.didReceiveMemoryWarning")
  }
  
  
  // MARK: - Private Instance Functions
  
  // Generic error dialog box to the user on internal errors
  fileprivate func internalErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "SomeFoodieApp",
                                              titleComment: "Alert diaglogue title when a Journal Entry view internal error occured",
                                              message: "An internal error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Journal Entry view internal error occured",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for generic Journal Entry errors",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  
  fileprivate func saveCompleteDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "SomeFoodieApp",
                                              titleComment: "Alert diaglogue title when a Journal Entry view completes test save",
                                              message: "Journal Entry Save Completed!",
                                              messageComment: "Alert dialog message when a Journal Entry view completes test save",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for completing a test save",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  func keyboardDismiss() {
    self.view.endEditing(true)
  }
  
  func vcDismiss() {
    // TODO: Data Passback through delegate?
    dismiss(animated: true, completion: nil)
  }
  
  override func encodeRestorableState(with coder: NSCoder) {
//    TODO: - Issue #6 - Commenting out for now. See issue for details
//
//    if let title = titleTextField?.text {
//      workingJournal?.title = title
//    }
//    
//    if let link = linkTextField?.text {
//      workingJournal?.journalURL = link
//    }
//    
//    if let journal = workingJournal {
//      journal.foodieObject.markModified()
//      do {
//        try FoodieJournal.unpinAllObjects(withName: "workingJournal")
//      }
//      catch
//      {
//        DebugPrint.verbose("Failed to unpin workingJournal in the local data store")
//      }
//      journal.saveRecursive(to: .local, withName: "workingJournal",withBlock: nil)
//    }
//    
//    super.encodeRestorableState(with: coder)
  }
  
  override func decodeRestorableState(with coder: NSCoder) {
//    TODO: - Issue #6 - Commenting out for now. See issue for details
//
//    if let title = coder.decodeObject(forKey: "title") as? String {
//      titleTextField?.text = title
//    }
//    
//    if let link = coder.decodeObject(forKey: "link") as? String {
//      linkTextField?.text = link
//    }
//    
//    if let tags = coder.decodeObject(forKey: "tags") as? String {
//      tagsTextView?.text = tags
//    }
//    
//    super.decodeRestorableState(with: coder)
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
    
    // Update the UI first
    guard let returnedVenueName = venue.name else {
      internalErrorDialog()
      DebugPrint.assert("Returned Venue has no name")
      return
    }
    venueButton?.titleLabel?.text = returnedVenueName
    
    // Query Parse to see if the Venue already exist
    
    
    // Do a full Venue Fetch from Foursquare
//    DebugPrint.verbose("Before -")
//    DebugPrint.verbose("Price Tier: \(venue.priceTier)")
//    DebugPrint.verbose("Hour:")
//    var b4Today = 0
//    if let b4HourSegmentsByDay = venue.hours {
//      for b4HourSegments in b4HourSegmentsByDay {
//        DebugPrint.verbose("Day \(b4Today+1)")
//        for b4HourSegment in b4HourSegments {
//          if let openingHour = b4HourSegment["start"], let closingHour = b4HourSegment["end"] {
//            DebugPrint.verbose("Opening: \(openingHour)")
//            DebugPrint.verbose("Closing: \(closingHour)")
//          }
//        }
//        b4Today += 1
//      }
//    }
//    DebugPrint.verbose("After -")
    
    venue.getDetailsFromFoursquare { (_, error) in
//      if let venue = returnedVenue {
//        DebugPrint.verbose("PriceTier: \(venue.priceTier)")
//      }
      if let error = error {
        AlertDialog.present(from: self, title: "Venue Details Error", message: "Unable to obtain additional Details for Venue")
        DebugPrint.assert("Getting Venue Details from Foursquare resulted in Error - \(error.localizedDescription)")
        return
      }
      
      venue.getHoursFromFoursquare { (_, error) in
//        var today = 0
//        if let hourSegmentsByDay = venue.hours {
//        
//          for hourSegments in hourSegmentsByDay {
//            DebugPrint.verbose("Day \(today+1)")
//            for hourSegment in hourSegments {
//              if let openingHour = hourSegment["start"], let closingHour = hourSegment["end"] {
//                DebugPrint.verbose("Opening: \(openingHour)")
//                DebugPrint.verbose("Closing: \(closingHour)")
//              }
//            }
//            today += 1
//          }
//        }
        if let error = error {
          AlertDialog.present(from: self, title: "Venue Hours Detail Error", message: "Unable to obtain details regarding opening hours for Venue")
          DebugPrint.assert("Getting Venue Hours from Foursquare resulted in Error - \(error.localizedDescription)")
          return
        }
        
        // Pre-save the Venue
      }
    }

    
  }
}

