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
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var titleTextField: UITextField?
  @IBOutlet weak var venueTextField: UITextField?
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
  @IBAction func testSaveJournal(_ sender: Any) {
    
    workingJournal?.title = titleTextField?.text
    workingJournal?.journalURL = linkTextField?.text
    workingJournal?.saveRecursive(to: .local) { (success, error) in
      if success {
        DebugPrint.verbose("Journal Save to Local Completed!")
        
        self.workingJournal?.saveRecursive(to: .server) { [weak self] (success, error) in
          if success {
            DebugPrint.verbose("Journal Save to Server Completed!")
            self?.saveCompleteDialog()
          } else if let error = error {
            DebugPrint.verbose("Journal Save to Server Failed with Error: \(error)")
          } else {
            DebugPrint.fatal("Journal Save to Server Failed without Error")
          }
        }
        
      } else if let error = error {
        DebugPrint.verbose("Journal Save to Local Failed with Error: \(error)")
      } else {
        DebugPrint.fatal("Journal Save to Local Failed without Error")
      }
    }
  }
  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let journalUnwrapped = workingJournal else {
      DebugPrint.fatal("workingJournal = nil")
    }
    
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
      
      // This is a new Moment. Let's add it to the Journal!
      journalUnwrapped.add(moment: returnedMoment!)
      
      // If there wasn't any moments before, we got to make this the default thumbnail for the Journal
      // Got to do this also when removing moments!!!
      if journalUnwrapped.moments!.count == 1 {
        // TODO: Do we need to factor out thumbnail operations?
        journalUnwrapped.thumbnailFileName = returnedMoment!.thumbnailFileName
        journalUnwrapped.thumbnailObj = returnedMoment!.thumbnailObj
      }
    }
    
    // TODO: How to visually convey status of Moments to user??
    
    // Setup the View, Moment VC, Text Fields, Keyboards, etc.
    sectionOneView.addSubview(mapView)
    
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    momentViewController = storyboard.instantiateViewController(withIdentifier: "MomentCollectionViewController") as! MomentCollectionViewController
    momentViewController.workingJournal = journalUnwrapped
    momentViewController.momentHeight = Constants.momentHeight
    
    self.addChildViewController(momentViewController)
    momentViewController.didMove(toParentViewController: self)
          
    titleTextField?.delegate = self
    venueTextField?.delegate = self
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
    
    titleTextField?.text = journalUnwrapped.title
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    // Start pre-upload operations, and other background trickeries
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
  
  
  private func saveCompleteDialog() {
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
