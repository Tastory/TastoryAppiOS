//
//  MarkupViewController.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-03-26.
//  Copyright © 2017 Eatelly. All rights reserved.
//
//  This is a reusable (Image/Video) Markup View Controller created based on the Swifty Cam - https://github.com/Awalz/SwiftyCam
//  Input  - photoToMarkup:    Photo to be Marked-up. Either this or videoToMarkupURL should be set, not both
//         - videoToMarkupURL: URL of the video to be Marked-up. Either this or photoToMarkup shoudl be set, not both
//  Output - Will save marked-up Moment to user selected Journal, set Current Journal if needed before popping itself and the 
//           Camera View Controller from the View Controller stack. If JournalEntryViewController is not already what's remaining
//           on the stack, will set relevant JournalEntryViewController inputs and push it onto the View Controller stack
//

import UIKit
import ImageIO
import CoreLocation
import AVFoundation
import Jot


protocol MarkupReturnDelegate {
  func markupComplete(markedupMoment: FoodieMoment, suggestedJournal: FoodieJournal?)
}


class MarkupViewController: UIViewController {
  
  // MARK: - Constants
  struct Constants {
    static let SizeSliderMaxFont: Float = 128.0
    static let SizeSliderMinFont: Float = 12.0
    static let SizeSliderDefaultFont: Float = 48.0
  }
  
  let FontChoiceArray: [String] = [
    "BoldSystemFont",
    "BodoniSvtyTwoOSITCTT-Book",
    "Futura-Medium",
    "Noteworthy-Bold"
  ]
  
  
  // MARK: - Public Instance Variables
  var fontArrayIndex = 0
  var mediaObj: FoodieMedia?
  var mediaLocation: CLLocation?
  var markupReturnDelegate: MarkupReturnDelegate?

  
  // MARK: - Private Instance Variables
  fileprivate var avPlayer: AVQueuePlayer?
  fileprivate var avPlayerLayer: AVPlayerLayer?
  fileprivate var avPlayerItem: AVPlayerItem?
  fileprivate var avPlayerLooper: AVPlayerLooper?
  
  fileprivate var videoView: UIView?
  fileprivate var photoView: UIImageView?
  
  fileprivate var thumbnailObject: FoodieMedia?
  fileprivate var mediaObject: FoodieMedia!
  
  fileprivate var mediaWidth: Int?
  fileprivate var mediaAspectRatio: Double?
  
  fileprivate var soundOn = true
  
  fileprivate let jotViewController = JotViewController()
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var saveButton: UIButton?
  @IBOutlet weak var exitButton: ExitButton?
  @IBOutlet weak var textButton: UIButton!
  @IBOutlet weak var drawButton: UIButton!
  @IBOutlet weak var foodButton: UIButton!
  @IBOutlet weak var bgndButton: UIButton!
  @IBOutlet weak var alignButton: UIButton!
  @IBOutlet weak var deleteButton: UIButton!
  @IBOutlet weak var undoButton: UIButton!
  @IBOutlet weak var soundButton: UIButton!
  @IBOutlet weak var colorSlider: UISlider!
  @IBOutlet weak var sizeSlider: UISlider!
  
  
  // MARK: - IBActions
  @IBAction func exitButtonAction(_ sender: UIButton) {
    dismiss(animated: true, completion: nil)
  }
  
  @IBAction func textButtonAction(_ sender: UIButton) {
    if jotViewController.state != .editingText {
      jotViewController.state = .editingText
      undoButton.isHidden = true
    } else {
      jotViewController.font = getNextFont(size: jotViewController.fontSize)
      CCLog.verbose("New Font Selected: \(jotViewController.font.fontName)")
    }
  }

  
  @IBAction func drawButtonAction(_ sender: UIButton) {
    if jotViewController.state == .text {
      
      view.endEditing(true)
      
      jotViewController.state = JotViewState.drawing
      deleteButton.isHidden = true
      bgndButton.isHidden = true
      alignButton.isHidden = true
      undoButton.isHidden = false
    }
  }
  
  @IBAction func bgndButtonAction(_ sender: UIButton) {
    var whiteValue = jotViewController.whiteValue
    var alphaValue = jotViewController.alphaValue
    
    view.endEditing(true)
    jotViewController.state = .text
    
    if whiteValue == 0.0, alphaValue == 0.0 {
      whiteValue = 0.0
      alphaValue = 0.3
    } else if whiteValue == 0.0, alphaValue == 0.3 {
      whiteValue = 1.0
      alphaValue = 0.3
    } else if whiteValue == 1.0, alphaValue == 0.3 {
      whiteValue = 0.0
      alphaValue = 0.0
    }
    
    jotViewController.whiteValue = whiteValue
    jotViewController.alphaValue = alphaValue
  }
  
  @IBAction func alignButton(_ sender: UIButton) {
    var alignment = jotViewController.textAlignment
    
    switch alignment {
    case .left:
      alignment = .center
    case .center:
      alignment = .right
    case .right:
      alignment = .left
    default:
      alignment = .left
    }
    
    jotViewController.textAlignment = alignment
  }
  
  
  @IBAction func foodButtonAction(_ sender: UIButton) {
    jotViewController.state = .editingText
    undoButton.isHidden = true
  }
  
  
  @IBAction func colorSliderChanged(_ sender: UISlider) {
    
    let sliderValue = Double(sender.value)
    let solidPct = 0.005
    let rsvdPct = 0.1
    var hueValue = 0.0
    var satValue = 0.0
    var valValue = 0.0
    var currentColor: UIColor!
    
    view.endEditing(true)
    
    // We are gonna cut up the slider. First 5% fades from white. Last 5% fades to black.
    // Gonna only allow 90% of the Hue pie, so it doesn't loop back to Red
    
    // Case so it's forced to Full White when slider is less than 0.5%
    if sliderValue < solidPct {
      valValue = 1.0
      satValue = 0.0
      hueValue = 0.0
      
    // Case for transition from White to Grey to Red
    } else if sliderValue < rsvdPct {
      valValue = (fabs(sliderValue - (rsvdPct/2)) + (rsvdPct/2)) / rsvdPct
      satValue = (sliderValue - (rsvdPct/2)) / (rsvdPct/2) // We are gonna double up so the Redness fades doubly fast
      hueValue = 0.0
      
    // Case for transition from Purple to Grey to Black
    } else if sliderValue > (1.0 - rsvdPct) {
      valValue = 1.0 - ((sliderValue - (1.0 - rsvdPct)) / rsvdPct)
      satValue = 1.0 - ((sliderValue - (1.0 - rsvdPct)) / (rsvdPct/2)) // Saturation decreases double speed
      hueValue = 1.0 - (2*rsvdPct)
      
    // Case for forcing Full Black when slider is more than 99.5%
    } else if sliderValue > (1.0 - solidPct) {
      valValue = 0.0
      satValue = 0.0
      hueValue = 1.0 - (2*rsvdPct)
      
    // Case for middle 90% of the slider
    } else {
      hueValue = sliderValue - rsvdPct
      satValue = 1.0
      valValue = 1.0
    }
    
    //print("Current Color - Slider = \(sliderValue) Hue = \(hueValue) Saturation = \(satValue) Value = \(valValue)")
    currentColor = UIColor(hue: CGFloat(hueValue), saturation: CGFloat(satValue), brightness: CGFloat(valValue), alpha: 1.0)
    
    jotViewController.drawingColor = currentColor
    jotViewController.textColor = currentColor
    
    // Change the slider track and knob color accordingly
    colorSlider.minimumTrackTintColor = currentColor
    colorSlider.thumbTintColor = currentColor
  }
  
  
  @IBAction func sizeSliderChanged(_ sender: UISlider) {
    let fontSize = CGFloat(sender.value)
    
    view.endEditing(true)
    
    jotViewController.fontSize = fontSize
  }
  
  
  @IBAction func undoButtonAction(_ sender: UIButton) {
    jotViewController.undoDrawing()
  }
  
  
  @IBAction func deleteButtonAction(_ sender: UIButton) {
    jotViewController.deleteSelectedLabel()
  }
  
  
  @IBAction func soundButtonAction(_ sender: UIButton) {
    
    if soundOn {
      avPlayer?.volume = 0.0
      soundOn = false
    } else {
      avPlayer?.volume = 1.0
      soundOn = true
    }
  }
  
  
  @IBAction func saveButtonAction(_ sender: UIButton) {
    
    // TODO: Don't let user click save (Gray it out until Thumbnail creation completed)
    
    // Initializing with Media Object also initialize foodieFileName and mediaType
    let momentObj = FoodieMoment(withState: .objectModified, foodieMedia: mediaObject) // viewDidLoad should have resolved the issue with mediaObj == nil by now)
    
    momentObj.playSound = soundOn
    
    // Setting the Thumbnail Object also initializes the thumbnailFileName
    momentObj.thumbnailObj = thumbnailObject
    
    // Serialize the Jot Markup into Foodie Markups
    if let jotDictionary = jotViewController.serialize() {

      if let jotLabels = jotDictionary[kLabels] as? [NSDictionary] {
        var index = 1
        for jotLabel in jotLabels {
          CCLog.verbose("Jot Label #\(index) serialized")
          
          let markup = FoodieMarkup(withState: .objectModified)
          markup.data = jotLabel
          markup.dataType = FoodieMarkup.dataTypes.jotLabel.rawValue
          if let jotLabelText = jotLabel[kText] as? String {
            markup.keyword = jotLabelText
          }
          
          momentObj.add(markup: markup)
          index += 1
        }
      } else {
        CCLog.verbose("No Labels in jotDictionary")
      }
      
      if let drawViewDictionary = jotDictionary[kDrawView] as? NSDictionary {
        CCLog.verbose("Jot DrawView serialized")
        
        let markup = FoodieMarkup(withState: .objectModified)
        markup.data = drawViewDictionary
        markup.dataType = FoodieMarkup.dataTypes.jotDrawView.rawValue
        markup.keyword = nil
        momentObj.add(markup: markup)
        
      } else {
        print("No DrawView in jotDictionary")
      }
    } else {
      CCLog.debug("No dictionary returned by jotViewController to serialize into Markup")
    }
    
    // Fill in the width and aspect ratio
    guard let width = mediaWidth else {
      saveErrorDialog()
      CCLog.assert("Unexpected. mediaWidth == nil")
      return
    }
    momentObj.width = width
    
    guard let aspectRatio = mediaAspectRatio else {
      saveErrorDialog()
      CCLog.assert("Unexpected. mediaAspectRatio == nil")
      return
    }
    momentObj.aspectRatio = aspectRatio

    // Keep in mind there are 2 scenarios here. 
    // 1. We are working on the Current Draft Journal
    // 2. We are editing on some random Journal
    
    // Implementing Scenario 1 for now. Scenario TBD
    // What this is trying to do is to display a selection dialog on whether to add to the Current Journal, or Save to a new one
    if let journal = FoodieJournal.currentJournal {
      displayJournalSelection(
        newJournalHandler: { UIAlertAction -> Void in self.showJournalDiscardDialog(moment: momentObj) },
        addToCurrentHandler: { UIAlertAction -> Void in self.cleanupAndReturn(markedUpMoment: momentObj, suggestedJournal: journal) }
      )
    }
    else {
      // Just return a new Current Journal
      self.cleanupAndReturn(markedUpMoment: momentObj, suggestedJournal: FoodieJournal.newCurrent())
    }
    
    // TODO: - Scenario 2 - We are editing an existing Story, not the Current Draft Story
  }

  
  // MARK - Public Instance Functions
  
  func displayJournalSelection( newJournalHandler: @escaping (UIAlertAction) -> Void, addToCurrentHandler: @escaping (UIAlertAction) -> Void) {
    // Display Action Sheet to ask user if they want to add this Moment to current Journal, or a new one, or Cancel
    // Create a button and associated Callback for adding the Moment to a new Journal
    let addToNewButton =
      UIAlertAction(title: "New Journal",
                    comment: "Button for adding to a New Journal in Save Moment action sheet",
                    style: .default,
                    handler: newJournalHandler)
    // Create a button with associated Callback for adding the Moment to the current Journal
    let addToCurrentButton =
      UIAlertAction(title: "Current Journal",
                    comment: "Button for adding to a Current Journal in Save Moment action sheet",
                    style: .default,
                    handler: addToCurrentHandler)

    // Finally, create the Action Sheet!
    let actionSheet = UIAlertController(title: "Add this Moment to...",
                                        titleComment: "Title for Save Moment action sheet",
                                        message: nil, messageComment: nil,
                                        preferredStyle: .actionSheet)
    actionSheet.addAction(addToNewButton)
    actionSheet.addAction(addToCurrentButton)
    actionSheet.addAlertAction(title: "Cancel",
                               comment: "Action Sheet button for Cancelling Adding a Moment in MarkupImageView",
                               style: .cancel)
    self.present(actionSheet, animated: true, completion: nil)
  }

  func showJournalDiscardDialog(moment: FoodieMoment) {
    
    guard let journal = FoodieJournal.currentJournal else {
      AlertDialog.standardPresent(from: self, title: .genericDeleteError, message: .internalTryAgain)
      CCLog.fatal("Discard current Journal but no current Journal")
    }
    
    // Create a button and associated Callback for discarding the previous current Journal and make a new one
    let discardButton =
      UIKit.UIAlertAction(title: "Discard",
                          comment: "Button to discard current Journal in alert dialog box to warn user",
                          style: .destructive) { action in
                            
      // Delete all traces of this unPosted Story
      journal.deleteRecursive(from: .both, type: .draft) { error in
        if let error = error {
          CCLog.warning("Deleting Story resulted in Error - \(error.localizedDescription)")
        }
      }
      FoodieJournal.removeCurrent()
      
      // We don't add Moments here, we let the Journal Entry View decide what to do with it
      self.cleanupAndReturn(markedUpMoment: moment, suggestedJournal: FoodieJournal.newCurrent())
    }
    
    let alertController =
      UIAlertController(title: "Discard & Overwrite",
                        titleComment: "Dialog title to warn user on discard and overwrite",
                        message: "Are you sure you want to discard and overwrite the current Journal?",
                        messageComment: "Dialog message to warn user on discard and overwrite",
                        preferredStyle: .alert)
    
    alertController.addAction(discardButton)
    alertController.addAlertAction(title: "Cancel",
                                   comment: "Alert Dialog box button to cancel discarding and overwritting of current Journal",
                                   style: .cancel)

    // Present the Discard dialog box to the user
    self.present(alertController, animated: true, completion: nil)
  }

  func cleanupAndReturn(markedUpMoment: FoodieMoment, suggestedJournal: FoodieJournal ){
    // Stop if there might be video looping
    self.avPlayer?.pause()  // TODO: - Do we need to free the avPlayer memory or something?
    
    // Returned Markedup-Moment back to Presenting View Controller
    guard let delegate = self.markupReturnDelegate else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("Unexpected. markupReturnDelegate became nil. Unable to proceed")
    }
    delegate.markupComplete(markedupMoment: markedUpMoment, suggestedJournal: suggestedJournal)
  }

  
  // MARK: - Private Instance Functions
  private func getNextFont(size: CGFloat) -> UIFont {
    fontArrayIndex += 1
    if fontArrayIndex >= FontChoiceArray.count { fontArrayIndex = 0 }
    if fontArrayIndex != 0, let newFont = UIFont(name: FontChoiceArray[fontArrayIndex], size: size) {
      return newFont
    } else {
      return UIFont.boldSystemFont(ofSize: size)
    }
  }
  
  // Generic error dialog box to the user on internal errors
  func internalErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "EatellyApp",
                                              titleComment: "Alert diaglogue title when a Markup Image view internal error occured",
                                              message: "An internal error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Markup Image view internal error occured",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for generic MarkupImageView errors",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }

  // Generic error dialog box to the user when displaying photo or video
  fileprivate func displayErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "EatellyApp",
                                              titleComment: "Alert diaglogue title when Markup Image view has problem displaying photo or video",
                                              message: "Error displaying media. Please try again",
                                              messageComment: "Alert dialog message when Markup Image view has problem displaying photo or video",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for error when displaying photo or video in MarkupImageView",
                                     style: .default)

      self.present(alertController, animated: true, completion: nil)
    }
  }

  // Generic error dialog box to the user on save errors
  fileprivate func saveErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "EatellyApp",
                                              titleComment: "Alert diaglogue title when Markup Image view has problem saving",
                                              message: "Error saving Journal. Please try again",
                                              messageComment: "Alert dialog message when Markup Image view has problem saving",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for MarkupImageView save errors",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  // Generic error dialog box to the user when adding Moments
  fileprivate func addErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "EatellyApp",
                                              titleComment: "Alert diaglogue title when Markup Image view has problem adding a Moment",
                                              message: "Error adding Moment. Please try again",
                                              messageComment: "Alert dialog message when Markup Image view has problem adding a Moment",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for error when adding Moments in MarkupImageView",
                                     style: .default)
      
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Setup the UI first - Assume text mode to start
    foodButton.isHidden = true  // TODO: Unhide this later when want to implement the Food Tag Button
    undoButton.isHidden = true
    deleteButton.isHidden = false
    bgndButton.isHidden = false
    alignButton.isHidden = false
    colorSlider.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi/2))
    colorSlider.value = 0.0  // Cuz default color is white
    sizeSlider.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi/2))
    sizeSlider.minimumValue = Constants.SizeSliderMinFont
    sizeSlider.maximumValue = Constants.SizeSliderMaxFont
    sizeSlider.setValue(Constants.SizeSliderDefaultFont, animated: false)
    
    // This section setups the JotViewController with default initial values
    jotViewController.delegate = self
    jotViewController.state = JotViewState.text
    jotViewController.textColor = UIColor.black
    jotViewController.font = getNextFont(size: CGFloat(Constants.SizeSliderDefaultFont))
    jotViewController.fontSize = CGFloat(Constants.SizeSliderDefaultFont)
    jotViewController.whiteValue = 0.0
    jotViewController.alphaValue = 0.0
    jotViewController.fitOriginalFontSizeToViewWidth = true
    jotViewController.textAlignment = .left
    jotViewController.drawingColor = UIColor.cyan
    
    addChildViewController(jotViewController)
    view.addSubview(jotViewController.view)
    view.sendSubview(toBack: jotViewController.view)
    jotViewController.didMove(toParentViewController: self)
    jotViewController.view.frame = view.bounds
    
    
    // This section is for initiating the background Image or Video
    if mediaObj == nil {
      internalErrorDialog()
      CCLog.assert("Unexpected, mediaObj == nil ")
      return
    } else {
      mediaObject = mediaObj!
    }
    
    guard let mediaType = mediaObject.mediaType else {
      internalErrorDialog()
      CCLog.assert("Unexpected, mediaType == nil")
      return
    }
    
    // Display the photo
    if mediaType == .photo {
      
      // Hide the Sound button
      soundButton.isHidden = true
      
      photoView = UIImageView(frame: view.bounds)
      
      guard let imageView = photoView else {
        displayErrorDialog()
        CCLog.assert("photoView = UIImageView(frame: _) failed")
        return
      }
      
      guard let imageBuffer = mediaObject.imageMemoryBuffer else {
        displayErrorDialog()
        CCLog.assert("Unexpected, mediaObject.imageMemoryBuffer == nil")
        return
      }
      
      view.addSubview(imageView)
      view.sendSubview(toBack: imageView)
      imageView.image = UIImage(data: imageBuffer)
      
    // Loop the video
    } else if mediaType == .video {
      
      // Make sure the Sound button is shown
      soundButton.isHidden = false
      
      guard let videoURL = mediaObject.videoLocalBufferUrl else {
        displayErrorDialog()
        CCLog.assert("Unexpected, mediaObject.videoLocalBufferUrl == nil")
        return
      }

      avPlayer = AVQueuePlayer()
      avPlayer?.volume = 1.0
      soundOn = true
      avPlayer?.allowsExternalPlayback = false
      avPlayerLayer = AVPlayerLayer(player: avPlayer)
      avPlayerLayer!.frame = self.view.bounds
      avPlayerItem = AVPlayerItem(url: videoURL)
      avPlayerLooper = AVPlayerLooper(player: avPlayer!, templateItem: avPlayerItem!)
      
      videoView = UIView(frame: self.view.bounds)
      videoView!.layer.addSublayer(avPlayerLayer!)
      view.addSubview(videoView!)
      view.sendSubview(toBack: videoView!)
      avPlayer!.play() // TODO: There is some lag with a blank white screen before video starts playing...
    
    // No image nor video to work on, Fatal
    } else {
      CCLog.fatal("Both photoToMarkup and videoToMarkupURL are nil")
    }
  }
  
  
  override func viewDidAppear(_ animated: Bool) {

    // Obtain thumbnail, width and aspect ratio ahead of time once view is already loaded
    let thumbnailCgImage: CGImage!
    
    // Need to decide what image to set as thumbnail
    switch mediaObject.mediaType! {
    case .photo:
      guard let imageBuffer = mediaObject.imageMemoryBuffer else {
        internalErrorDialog()
        CCLog.assert("Unexpected, mediaObject.imageMemoryBuffer == nil")
        return
      }
      
      guard let imageSource = CGImageSourceCreateWithData(imageBuffer as CFData, nil) else {
        internalErrorDialog()
        CCLog.assert("CGImageSourceCreateWithData() failed")
        return
      }
      
      let options = [
        kCGImageSourceThumbnailMaxPixelSize as String : FoodieGlobal.Constants.ThumbnailPixels as NSNumber,
        kCGImageSourceCreateThumbnailFromImageAlways as String : true as NSNumber,
        kCGImageSourceCreateThumbnailWithTransform as String: true as NSNumber
      ]
      thumbnailCgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)  // Assuming either portrait or square
      
      // Get the width and aspect ratio while at it
      let imageCount = CGImageSourceGetCount(imageSource)
      
      if imageCount != 1 {
        internalErrorDialog()
        CCLog.assert("Image Source Count not 1")
        return
      }
      
      guard let imageProperties = (CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String : AnyObject]) else {
        internalErrorDialog()
        CCLog.assert("CGImageSourceCopyPropertiesAtIndex failed to get Dictionary of image properties")
        return
      }
      
      if let pixelWidth = imageProperties[kCGImagePropertyPixelWidth as String] as? Int {
        mediaWidth = pixelWidth
      } else {
        internalErrorDialog()
        CCLog.assert("Image property with index kCGImagePropertyPixelWidth did not return valid Integer value")
        return
      }
      
      if let pixelHeight = imageProperties[kCGImagePropertyPixelHeight as String] as? Int {
        mediaAspectRatio = Double(mediaWidth!)/Double(pixelHeight)
      } else {
        internalErrorDialog()
        CCLog.assert("Image property with index kCGImagePropertyPixelHeight did not return valid Integer value")
        return
      }
      
    case .video:      // TODO: Allow user to change timeframe in video to base Thumbnail on
      guard let videoUrl = mediaObject.videoLocalBufferUrl else {
        internalErrorDialog()
        CCLog.assert("Unexpected, videoLocalBufferUrl == nil")
        return
      }
      
      let asset = AVURLAsset(url: videoUrl)
      let imgGenerator = AVAssetImageGenerator(asset: asset)
      
      imgGenerator.maximumSize = CGSize(width: FoodieGlobal.Constants.ThumbnailPixels, height: FoodieGlobal.Constants.ThumbnailPixels)  // Assuming either portrait or square
      imgGenerator.appliesPreferredTrackTransform = true
      
      do {
        thumbnailCgImage = try imgGenerator.copyCGImage(at: CMTimeMake(0, 1), actualTime: nil)
      } catch {
        internalErrorDialog()
        CCLog.assert("AVAssetImageGenerator.copyCGImage failed with error: \(error.localizedDescription)")
        return
      }
      
      let avTracks = asset.tracks(withMediaType: AVMediaTypeVideo)
      
      if avTracks.count != 1 {
        internalErrorDialog()
        CCLog.assert("There isn't exactly 1 video track for the AVURLAsset")
        return
      }
      
      let videoSize = avTracks[0].naturalSize
      mediaWidth = Int(videoSize.width)
      mediaAspectRatio = Double(videoSize.width/videoSize.height)
      
      //CCLog.verbose("Media width: \(videoSize.width) height: \(videoSize.height). Thumbnail width: \(thumbnailCgImage.width) height: \(thumbnailCgImage.height)")
    }
    
    // Create a Thumbnail Media with file name based on the original file name of the Media
    guard let foodieFileName = mediaObject.foodieFileName else {
      internalErrorDialog()
      CCLog.assert("Unexpected. mediaObject.foodieFileName = nil")
      return
    }
    
    thumbnailObject = FoodieMedia(withState: .objectModified, for: FoodieFile.thumbnailFileName(originalFileName: foodieFileName), localType: .draft, mediaType: .photo)
    
    thumbnailObject!.imageMemoryBuffer = UIImageJPEGRepresentation(UIImage(cgImage: thumbnailCgImage), CGFloat(FoodieGlobal.Constants.JpegCompressionQuality))
    //CGImageRelease(thumbnailCgImage)
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    view.endEditing(true)  // Force clear the keyboard
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("MarkupViewController.didReceiveMemoryWarning")
  }
  
  
  override var prefersStatusBarHidden: Bool {
    return true
  }
}


extension MarkupViewController: JotViewControllerDelegate {
  
  func jotViewController(_ jotViewController: JotViewController, isEditingText isEditing: Bool) {
    deleteButton.isHidden = false
    bgndButton.isHidden = false
    alignButton.isHidden = false
    
  }
  
  func jotViewController(_ jotViewController: JotViewController!, didSelectLabel labelInfo: [AnyHashable : Any]!) {
    if jotViewController.state == .text || jotViewController.state == .editingText {
      deleteButton.isHidden = false
      bgndButton.isHidden = false
      alignButton.isHidden = false
    }
  }
}
