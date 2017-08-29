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
  

  @IBAction func EditedTitle(_ sender: Any) {
    workingJournal?.title = titleTextField?.text
    saveJournalToLocal()
  }

  @IBAction func EditedLink(_ sender: Any) {
    workingJournal?.journalURL = linkTextField?.text
    saveJournalToLocal()
  }


  // MARK: - IBActions
  @IBAction func venueClicked(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "VenueTableViewController") as! VenueTableViewController
    self.present(viewController, animated: true)
  }
  
  
  @IBAction func testSaveJournal(_ sender: Any) {

    //TODO add spinner 
    UIApplication.shared.beginIgnoringInteractionEvents()
    
    workingJournal?.title = titleTextField?.text
    workingJournal?.journalURL = linkTextField?.text

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

  func saveJournalToLocal() {
    if let journal = workingJournal {
      journal.foodieObject.markModified()
      //
      FoodieJournal.unpinAllObjectsInBackground(withName: "workingJournal")
      journal.saveRecursive(to: .local, withName: "workingJournal",withBlock: nil)
    }
  }

  
  func saveJournalToServer(){

    triggerSaveJournal = false

    // journal is already saved to local
    self.workingJournal?.saveRecursive(to: .server) {(success, error) in
    //workingJournal?.setGeoPoint(latitude: 49.2778211, longitude: -123.1089668)
      if success {
        DebugPrint.verbose("Journal Save to Server Completed!")

        FoodieJournal.unpinAllObjectsInBackground(withName: "workingJournal")
        self.workingJournal = nil
        FoodieJournal.setJournal(journal: nil)
        self.saveCompleteDialog(handler: {(UIAlertAction) -> Void in
          self.vcDismiss()
        })
      } else if let error = error {
        DebugPrint.verbose("Journal Save to Server Failed with Error: \(error)")
      } else {
        DebugPrint.fatal("Journal Save to Server Failed without Error")
      }
      UIApplication.shared.endIgnoringInteractionEvents()
    }

  }
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if let journalUnwrapped = workingJournal {
      // TODO: Do we need to download the Journal itself first? How can we tell?

      titleTextField?.text = journalUnwrapped.title
      linkTextField?.text = journalUnwrapped.journalURL

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
  
  func initializeJournalController() {
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
  private func internalErrorDialog() {
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
  
  
  private func saveCompleteDialog(handler: ((UIAlertAction) -> Void)? = nil) {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "SomeFoodieApp",
                                              titleComment: "Alert diaglogue title when a Journal Entry view completes test save",
                                              message: "Journal Entry Save Completed!",
                                              messageComment: "Alert dialog message when a Journal Entry view completes test save",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for completing a test save",
                                     style: .default,
                                     handler: handler)
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
