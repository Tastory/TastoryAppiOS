//
//  StoryEntryViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-03-26.
//  Copyright © 2017 Tastry. All rights reserved.
//
//

import UIKit
import MapKit
import CoreLocation
import SafariServices


protocol PreviewControlDelegate: class {
  func enablePreviewButton(_ isEnabled: Bool)
}


protocol RestoreStoryDelegate: class {
  func updateStory(_ story: FoodieStory)
}


class StoryEntryViewController: OverlayViewController, UIGestureRecognizerDelegate {
  
  // MARK: - Private Static Constants
  
  private struct Constants {
    static let VenueMapWidth: CLLocationDistance = 300 // 300m
    
    static let MaxTitleLength: Int = 50
    static let MaxSwipeMessageLength: Int = 15
    
    static let StackShadowOffset = FoodieGlobal.Constants.DefaultUIShadowOffset
    static let StackShadowRadius = FoodieGlobal.Constants.DefaultUIShadowRadius
    static let StackShadowOpacity = FoodieGlobal.Constants.DefaultUIShadowOpacity
    
    static let BackgroundGradientBlackAlpha: CGFloat = 0.3
    static let UIDisappearanceDuration = FoodieGlobal.Constants.DefaultUIDisappearanceDuration
  }
  


  // MARK: - Private Instance Constants
  
  private var activitySpinner: ActivitySpinner!  // Set by ViewDidLoad
  private var mapNavController: MapNavController?
  
  
  
  // MARK: - Public Instance Variable
  
  var workingStory: FoodieStory?
  var returnedMoments: [FoodieMoment] = []
  var markupMoment: FoodieMoment? = nil
  weak var restoreStoryDelegate: RestoreStoryDelegate?
  
  
  
  // MARK: - Private Instance Variables
  
  private var momentViewController = MomentCollectionViewController()
  private var isInitialLayout = true
  

  
  // MARK: - IBOutlets
  
  @IBOutlet weak var mapExposedView: UIView!
  @IBOutlet weak var topGradientBackground: TouchForwardingView!
  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var momentCellView: UIView!
  @IBOutlet weak var titleIcon: UIButton!
  @IBOutlet weak var titleTextField: UITextField?
  @IBOutlet weak var titleLengthLabel: UILabel?
  @IBOutlet weak var venueIcon: UIButton!
  @IBOutlet weak var venueButton: UIButton?
  @IBOutlet weak var linkIcon: UIButton!
  @IBOutlet weak var linkTextField: UITextField?
  @IBOutlet weak var openLinkButton: UIButton!
  @IBOutlet weak var swipeIcon: UIButton!
  @IBOutlet weak var swipeTextField: UITextField?
  @IBOutlet weak var swipeLengthLabel: UILabel?
  @IBOutlet weak var previewButton: UIButton!
  @IBOutlet weak var discardButton: UIButton!
  @IBOutlet weak var savePostButton: UIButton!
  @IBOutlet weak var tagsTextView: UITextViewWithPlaceholder? {
    didSet {
      tagsTextView?.placeholder = "Tags (Placeholder)"
      tagsTextView?.font = UIFont(name: "Raleway-Regular", size: 14.0)
      tagsTextView?.isEditable = false
    }
  }

  

  // MARK: - IBActions
  @IBAction func venueClicked(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "VenueTableViewController") as? VenueTableViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of VenueTableViewController Class!!")
      }
      return
    }
    viewController.delegate = self
    viewController.suggestedVenue = workingStory?.venue
    
    // Average the locations of the Moments to create a location suggestion on where to search for a Venue
    viewController.suggestedLocation = averageLocationOfMoments()
    viewController.setSlideTransition(presentTowards: .left, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func previewLink(_ sender: UIButton) {
    CCLog.info("User tapped Link Preview")
    
    if let linkText = linkTextField?.text, let url = URL(string: URL.addHttpIfNeeded(to: linkText)) {
      CCLog.info("Opening Safari View for \(url)")
      let safariViewController = SFSafariViewController(url: url)
      safariViewController.modalPresentationStyle = .overFullScreen
      self.present(safariViewController, animated: true, completion: nil)
    }
  }
  
  
  @IBAction func previewStory(_ sender: Any) {
    view.endEditing(true) // Dismiss Keyboard here, as Keyboard Dismiss Notification can crash JotViewController
    
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryViewController") as! StoryViewController
    viewController.viewingStory = workingStory
    viewController.draftPreview = true
    viewController.setSlideTransition(presentTowards: .up, withGapSize: FoodieGlobal.Constants.DefaultSlideVCGapSize, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }

  
  @IBAction func discardStory(_ sender: UIButton) {
    askDiscardAndDismiss()
  }

  
  @IBAction func postStory(_ sender: UIButton) {
    guard let story = workingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("No Working Story when user pressed Post Story")
    }
    
    guard let currentUser = FoodieUser.current else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("No Current User Logged In")
    }
    
    guard let moments = story.moments, !moments.isEmpty else {
      AlertDialog.present(from: self, title: "Story has No Moments", message: "Add some Moments to make this an interesting Story!")
      return
    }
    
    CCLog.info("User pressed 'Post Story'")
    
    // There might be fields current in edit. Grab those values also
    if let titleText = titleTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines), titleText != "" {
      titleTextField?.text = titleText
      story.title = titleText
    }
    
    if let linkText = linkTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines), linkText != "" {
      let validHttpText = URL.addHttpIfNeeded(to: linkText)
      linkTextField?.text = validHttpText
      story.storyURL = validHttpText
    }
    
    if let swipeText = swipeTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines), swipeText != "" {
      swipeTextField?.text = swipeText
      story.swipeMessage = swipeText
    }
    
    guard let title = story.title, title != "", story.venue != nil else {
      AlertDialog.present(from: self, title: "Required Fields Empty", message: "The Title and Venue are essential to a Story!")
      return
    }
    
    view.endEditing(true)
    activitySpinner.apply()
    
    
    // This will cause a save to both Local Cache and Server
    _ = story.saveWhole(to: .both, type: .cache) { error in
      
      if let error = error {
        self.activitySpinner.remove()
        CCLog.warning("Save Story to Server Failed with Error: \(error)")
        AlertDialog.present(from: self, title: "Save Story to Server Failed", message: error.localizedDescription)
      } else {
        
        // Add this Story to the User's authored list
        currentUser.addAuthoredStory(story) { error in
          
          if let error = error {
            // Best effort remove the Story from Server & Cache in this case
            _ = story.deleteWhole(from: .both, type: .cache, withBlock: nil)
            
            self.activitySpinner.remove()
            CCLog.warning("Add Story to User List Failed with Error: \(error)")
            AlertDialog.present(from: self, title: "Add Story to User Failed", message: error.localizedDescription)
          }

          FoodieStory.cleanUpDraft() { error in
            if let error = error {
              AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                CCLog.assert("Error when cleaning up story draft- \(error.localizedDescription)")
              }
            }
          }

          if(story.isEditStory) {
            self.restoreStoryDelegate?.updateStory(story)
          }

          self.workingStory = nil
          self.activitySpinner.remove()

          // Pop-up Alert Dialog and then Dismiss
          CCLog.info("Story Posted!")
          AlertDialog.present(from: self, title: "Story Posted", message: "Thanks for telling your Story!") { [unowned self] _ in
            self.popDismiss(animated: true)
          }
        }
      }
    }
  }
  

  @IBAction func editedTitle(_ sender: UITextField) {
    guard let text = sender.text?.trimmingCharacters(in: .whitespacesAndNewlines), let story = workingStory, text != story.title, text != "" else {
      // Nothing changed, don't do anything
      return
    }
    
    CCLog.info("User edited Title of Story")
    titleTextField?.text = text
    story.title = text
    
    FoodieStory.preSave(nil, withBlock: nil)
  }
  
  
  @IBAction func editedLink(_ sender: UITextField) {
    guard let text = sender.text?.trimmingCharacters(in: .whitespacesAndNewlines), let story = workingStory, text != story.storyURL, text != "" else {
      // Nothing changed, don't do anything
      return
    }
    
    let validHttpText = URL.addHttpIfNeeded(to: text)
    linkTextField?.text = validHttpText
    story.storyURL = validHttpText
    
    CCLog.info("User edited Link of Story")
    FoodieStory.preSave(nil, withBlock: nil)
  }
  
  
  @IBAction func editedSwipe(_ sender: UITextField) {
    guard let text = sender.text?.trimmingCharacters(in: .whitespacesAndNewlines), let story = workingStory, text != story.swipeMessage, text != "" else {
      // Nothing changed, don't do anything
      return
    }
    
    CCLog.info("User edited Swipe Message of Story")
    swipeTextField?.text = text
    story.swipeMessage = text
    FoodieStory.preSave(nil, withBlock: nil)
  }
  
  
  @IBAction func backAction(_ sender: UIButton) {
    guard let story = self.workingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("No Working Story when discarding story")
    }
    
    if story.isEditStory {
      askDiscardAndDismiss()
    } else {
      popDismiss(animated: true)
    }
  }
  
  
  // MARK: - Private Instance Functions
  
  private func askDiscardAndDismiss() {
    guard let story = self.workingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("No Working Story when discarding story")
    }
    
    var discardTitle: String
    var discardMessage: String
    
    if story.isEditStory {
      discardTitle = "Discard Edit"
      discardMessage = "Are you sure you want to discard the changes to your story?"
    } else {
      discardTitle = "Discard Story"
      discardMessage = "Are you sure? Your associated image, video and edits will be gone."
    }
    
    StorySelector.showStoryDiscardDialog(to: self, message: discardMessage, title: discardTitle) {
      self.activitySpinner.apply()
      FoodieStory.cleanUpDraft() { error in
        if let error = error {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
            self.activitySpinner.remove()
            CCLog.assert("Error when cleaning up story draft- \(error.localizedDescription)")
          }
        }
        
        if(story.isEditStory) {
          self.restoreStoryDelegate?.updateStory(story)
        }
        
        self.workingStory = nil
        
        self.popDismiss(animated: true)
        self.activitySpinner.remove()
      }
    }
  }
  
  
  private func averageLocationOfMoments() -> CLLocation? {
    
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
      return CLLocation(latitude: latitude/Double(numValidCoordinates),
                        longitude: longitude/Double(numValidCoordinates))
    } else {
      return nil
    }
  }

  
  private func updateStoryEntryMap(with region: MKCoordinateRegion, venueName: String? = nil) {
    DispatchQueue.main.async {
      guard let story = self.workingStory else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
        CCLog.fatal("No Working Story for Story Entry")
      }
      
      self.mapNavController?.removeAllAnnotations()
      self.mapNavController?.showRegionExposed(region, animated: true)

      // Add back if an annotation is requested
      if let name = venueName {
        let annotation = StoryMapAnnotation(title: name, story: story, coordinate: region.center)
        self.mapNavController?.add(annotation: annotation)
        self.mapNavController?.select(annotation: annotation, animated: true)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.mapNavController?.select(annotation: annotation, animated: true) }  // This makes the Annotation title pop-up after a slight delay
      }
    }
  }


  private func appearanceForAllUI(alphaValue: CGFloat, animated: Bool,
                                  duration: TimeInterval = FoodieGlobal.Constants.DefaultTransitionAnimationDuration) {
    if animated {
      UIView.animate(withDuration: duration) {
        self.topGradientBackground.alpha = alphaValue
      }
    } else {
      topGradientBackground.alpha = alphaValue
    }
  }
  
  
  @objc private func keyboardDismiss() {
    self.view.endEditing(true)
  }
  
  
  @objc private func keyboardWillShow(_ notification: NSNotification) {
    if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
      // 20 as arbitrary value so there's some space between the text field in focus and the top of the keyboard
      scrollView.contentInset.bottom = keyboardSize.height + 20
    }
  }
  
  @objc private func keyboardWillHide(_ notification: NSNotification) {
    scrollView.contentInset.bottom = 0
  }
  
  
  
  // MARK: - View Controller Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    momentViewController = storyboard.instantiateViewController(withIdentifier: "MomentCollectionViewController") as! MomentCollectionViewController
    momentViewController.workingStory = workingStory
    momentViewController.cameraReturnDelegate = self
    momentViewController.previewControlDelegate = self
    momentViewController.containerVC = self

    addChildViewController(momentViewController)
    momentCellView.addSubview(momentViewController.view)
    momentViewController.didMove(toParentViewController: self)
    momentViewController.view.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      momentViewController.view.topAnchor.constraint(equalTo: momentCellView.topAnchor, constant: 0.0),
      momentViewController.view.bottomAnchor.constraint(equalTo: momentCellView.bottomAnchor, constant: 0.0),
      momentViewController.view.leftAnchor.constraint(equalTo: momentCellView.leftAnchor, constant: 0.0),
      momentViewController.view.rightAnchor.constraint(equalTo: momentCellView.rightAnchor, constant: 0.0),
    ])
    
    titleTextField?.delegate = self
    linkTextField?.delegate = self
    swipeTextField?.delegate = self
    
    let keyboardDismissRecognizer = UITapGestureRecognizer(target: self, action: #selector(keyboardDismiss))
    keyboardDismissRecognizer.numberOfTapsRequired = 1
    keyboardDismissRecognizer.numberOfTouchesRequired = 1
    view.addGestureRecognizer(keyboardDismissRecognizer)
    activitySpinner = ActivitySpinner(addTo: view, blurStyle: .dark, spinnerStyle: .whiteLarge)
    
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    
    // Drop Shadow at the back of the Stack View
    scrollView.layer.masksToBounds = false
    scrollView.layer.shadowColor = UIColor.black.cgColor
    scrollView.layer.shadowOffset = Constants.StackShadowOffset
    scrollView.layer.shadowRadius = Constants.StackShadowRadius
    scrollView.layer.shadowOpacity = Constants.StackShadowOpacity
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    if let workingStory = workingStory {

      // compute the insert index for the collection view
      var indexPaths: [IndexPath] = []
      var itemIndex = 1
      
      for returnedMoment in returnedMoments {
        // Let's figure out what to do with the returned Moment
        if markupMoment != nil {
          // So there is a Moment under markup. The returned Moment should match this.
          if returnedMoment === markupMoment {
            
            // save to local
            _ = returnedMoment.saveWhole(to: .local, type: .draft) { error in
              if let error = error {
                AlertDialog.standardPresent(from: self, title: .genericSaveError, message: .saveTryAgain) { _ in
                  CCLog.assert("Error saving moment into local caused by: \(error.localizedDescription)")
                }
              }
            }
          } else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain)
            CCLog.assert("returnedMoment expected to match markupMoment")
          }
        } else {
          
          if workingStory.moments != nil {
            itemIndex += (workingStory.moments!.count - 1)
            indexPaths.append(IndexPath( item: (itemIndex) , section: 0))
            itemIndex += 1
          }
          
          CCLog.verbose("ViewWillAppear Add Moment \(returnedMoment.getUniqueIdentifier)")
          workingStory.add(moment: returnedMoment)
          // If there wasn't any moments before, we got to make this the default thumbnail for the Story
          // Got to do this also when removing moments!!!
          if workingStory.moments!.count == 1 {
            // TODO: Do we need to factor out thumbnail operations?
            workingStory.thumbnailFileName = returnedMoment.thumbnailFileName
            workingStory.thumbnail = returnedMoment.thumbnail
          }
          previewButton.isEnabled = false
          FoodieStory.preSave(returnedMoment) { (error) in
            if error != nil {  // Error code should've already been printed to the Debug log from preSave()
              AlertDialog.standardPresent(from: self, title: .genericSaveError, message: .internalTryAgain)
            }
            self.previewButton.isEnabled = true
            //self.returnedMoment = nil  // We should be in a state where whom is the returned Moment should no longer matter
          }
        }
      }

      // Clear returned moments or will get messy if the view gets partial dismissed and comes back (interactable transitions)
      returnedMoments.removeAll()
      
      if(!indexPaths.isEmpty) {
        guard let collectionView = self.momentViewController.collectionView else {
          CCLog.fatal("collection view from momentViewController is nil")
        }

        // insert items only if the UIcollectionView is loaded previously
        if(!collectionView.visibleCells.isEmpty){
          collectionView.insertItems(at: indexPaths)
        }
      }

      // Update all the fields here?
      if let title = workingStory.title, title != "" {
        titleTextField?.text = title
        titleIcon?.alpha = 1.0
        titleLengthLabel?.text = String(Constants.MaxTitleLength - title.count)
      } else {
        titleIcon?.alpha = 0.3
        titleLengthLabel?.text = String(Constants.MaxTitleLength)
      }
      
      if let venueName = workingStory.venue?.name {
        venueButton?.setTitle(venueName, for: .normal)
        venueButton?.alpha = 1.0
        venueIcon?.alpha = 1.0
      } else {
        venueButton?.setTitle("Venue", for: .normal)
        venueButton?.alpha = 0.3
        venueIcon?.alpha = 0.3
      }
      
      if let storyURL = workingStory.storyURL, storyURL != "" {
        linkTextField?.text = storyURL
        linkIcon.alpha = 1.0
        openLinkButton.isHidden = false
      } else {
        linkIcon.alpha = 0.3
        openLinkButton.isHidden = true
      }
      
      if let swipeMessage = workingStory.swipeMessage, swipeMessage != "" {
        swipeTextField?.text = swipeMessage
        swipeIcon.alpha = 1.0
        swipeLengthLabel?.text = String(Constants.MaxSwipeMessageLength - swipeMessage.count)
      } else {
        swipeIcon.alpha = 0.3
        swipeLengthLabel?.text = String(Constants.MaxSwipeMessageLength)
      }
      
      if workingStory.isEditStory {
        discardButton?.setTitle("Discard Changes", for: .normal)
        savePostButton?.setTitle("Save", for: .normal)
      } else {
        discardButton?.setTitle("Discard", for: .normal)
        savePostButton?.setTitle("Post", for: .normal)
      }
      
      appearanceForAllUI(alphaValue: 0.0, animated: false)
    }
  }
  
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    if isInitialLayout {
      isInitialLayout = false
      
      // Setup Background Gradient Views
      let backgroundBlackAlpha = UIColor.black.withAlphaComponent(Constants.BackgroundGradientBlackAlpha)
      let topGradientNode = GradientNode(startingAt: CGPoint(x: 0.5, y: 0.0),
                                         endingAt: CGPoint(x: 0.5, y: 1.0),
                                         with: [backgroundBlackAlpha, .clear])
      topGradientNode.isOpaque = false
      topGradientNode.frame = topGradientBackground.bounds
      topGradientBackground.addSubnode(topGradientNode)
      topGradientBackground.sendSubview(toBack: topGradientNode.view)
    }
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard let mapController = navigationController as? MapNavController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("No Map Navigation Controller. Cannot Proceed")
      }
      return
    }
    
    mapNavController = mapController
    //mapController.mapDelegate = self
    mapController.setExposedRect(with: mapExposedView)
    
    if let workingStory = workingStory {
      // Lets update the map location to the top here
      // If there's a Venue, use that location first. Usually if a venue have been freshly selected, it wouldn't have been confirmed in time. So another update is done in venueSearchComplete()
      if let latitude = workingStory.venue?.location?.latitude,
        let longitude = workingStory.venue?.location?.longitude {
        
        let region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                                        Constants.VenueMapWidth, Constants.VenueMapWidth)
        updateStoryEntryMap(with: region, venueName: workingStory.venue?.name)
      }
        
        // Otherwise use the average location of the Moments
      else if let momentsLocation = averageLocationOfMoments() {
        let region = MKCoordinateRegionMakeWithDistance(momentsLocation.coordinate,
                                                        mapController.minMapWidth,
                                                        mapController.minMapWidth)
        updateStoryEntryMap(with: region, venueName: workingStory.venue?.name)
      }
        
        // Try to get a current location using the GPS
      else {
        LocationWatch.global.get { (location, error) in
          if let error = error {
            CCLog.warning("StoryEntryVC with no Venue or Moments Location. Getting location through LocationWatch also resulted in error - \(error.localizedDescription)")
            //self.updateStoryEntryMap(withCoordinate: Constants.DefaultCLCoordinate2D, span: Constants.DefaultDelta)  Just let it be a view of the entire North America I guess?
            return
          } else if let location = location {
            let region = MKCoordinateRegionMakeWithDistance(location.coordinate,
                                                            mapController.defaultMapWidth,
                                                            mapController.defaultMapWidth)
            self.updateStoryEntryMap(with: region, venueName: workingStory.venue?.name)
          }
        }
      }
    }
    
    appearanceForAllUI(alphaValue: 1.0, animated: true)
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    appearanceForAllUI(alphaValue: 0.0, animated: true, duration: Constants.UIDisappearanceDuration)
    self.mapNavController = nil
    view.endEditing(true)
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    // We should clear this so we don't assume that we still have a returned moment
    returnedMoments.removeAll()
  }
  
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  
  override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
    return .fade
  }
  
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}



// MARK: - Text Fields' Delegate
extension StoryEntryViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
  
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    guard let text = textField.text else { return true }
    let newLength = text.utf16.count + string.utf16.count - range.length
    
    if textField === titleTextField {
      var remainingLength = Constants.MaxTitleLength - newLength
      if remainingLength == -1 { remainingLength = 0 }
      titleLengthLabel?.text = String(remainingLength)
      
      if newLength > 0 {
        titleIcon.alpha = 1.0
      } else {
        titleIcon.alpha = 0.3
      }
      return newLength <= Constants.MaxTitleLength // Bool
    }
    else if textField === linkTextField {
      if newLength > 0 {
        openLinkButton.isHidden = false
        linkIcon.alpha = 1.0
      } else {
        openLinkButton.isHidden = true
        linkIcon.alpha = 0.3
      }
      return true
    }
    else if textField === swipeTextField {
      var remainingLength = Constants.MaxSwipeMessageLength - newLength
      if remainingLength == -1 { remainingLength = 0 }
      swipeLengthLabel?.text = String(remainingLength)
      
      if newLength > 0 {
        swipeIcon.alpha = 1.0
      } else {
        swipeIcon.alpha = 0.3
      }
      return newLength <= Constants.MaxSwipeMessageLength
    } else {
      return true
    }
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
              self.venueButton?.alpha = 1.0
              self.venueIcon?.alpha = 1.0
            }
          }
          
          // Update the map again here
          if let latitude = venueToUpdate.location?.latitude, let longitude = venueToUpdate.location?.longitude {
            
            let region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                                            Constants.VenueMapWidth, Constants.VenueMapWidth)
            self.updateStoryEntryMap(with: region, venueName: venueToUpdate.name)
          }
          
          // Pre-save only the Story to Local only
          FoodieStory.preSave(nil) { (error) in
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
    returnedMoments = markedupMoments
    markupMoment = nil
    dismiss(animated: true)
  }
}



extension StoryEntryViewController: PreviewControlDelegate {
  func enablePreviewButton(_ isEnabled: Bool) {
    DispatchQueue.main.async {
      self.previewButton.isEnabled = isEnabled
      self.savePostButton.isEnabled = isEnabled
    }
  }
}



extension StoryEntryViewController: MarkupReturnDelegate {
  func markupComplete(markedupMoments: [FoodieMoment], suggestedStory: FoodieStory?) {
    self.returnedMoments = markedupMoments
    
    if(markedupMoments.count > 0) {
      self.markupMoment = markedupMoments.first
    }
    dismiss(animated: true, completion: nil)  // This dismiss is for the MarkupVC to call, not for the Story Entry VC
  }
}


