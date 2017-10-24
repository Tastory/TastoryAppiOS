//
//  MarkupViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-03-26.
//  Copyright © 2017 Tastry. All rights reserved.
//
//  This is a reusable (Image/Video) Markup View Controller created based on the Swifty Cam - https://github.com/Awalz/SwiftyCam
//  Input  - photoToMarkup:    Photo to be Marked-up. Either this or videoToMarkupURL should be set, not both
//         - videoToMarkupURL: URL of the video to be Marked-up. Either this or photoToMarkup shoudl be set, not both
//  Output - Will save marked-up Moment to user selected Story, set Current Story if needed before popping itself and the 
//           Camera View Controller from the View Controller stack. If StoryEntryViewController is not already what's remaining
//           on the stack, will set relevant StoryEntryViewController inputs and push it onto the View Controller stack
//

import UIKit
import ImageIO
import CoreLocation
import AVFoundation
import Jot


protocol MarkupReturnDelegate {
  func markupComplete(markedupMoments: [FoodieMoment], suggestedStory: FoodieStory?)
}


class MarkupViewController: TransitableViewController {
  
  // MARK: - Constants
  struct Constants {
    static let SizeSliderMaxFont: Float = 64.0
    static let SizeSliderMinFont: Float = 10.0
    static let SizeSliderDefaultFont: Float = 36.0
  }
  
  let FontChoiceArray: [String] = [
    "BoldSystemFont",
    "BodoniSvtyTwoOSITCTT-Book",
    "Futura-Medium",
    "Noteworthy-Bold"
  ]
  
  
  // MARK: - Public Instance Variables
  var editMomentObj: FoodieMoment?
  var fontArrayIndex = 0
  var mediaObj: FoodieMedia?
  var mediaLocation: CLLocation?
  var markupReturnDelegate: MarkupReturnDelegate?
  var addToExistingStoryOnly = false

  // MARK: - Private Instance Variables
  fileprivate var avPlayer: AVQueuePlayer?
  fileprivate var avPlayerLayer: AVPlayerLayer?
  fileprivate var avPlayerItem: AVPlayerItem?
  fileprivate var avPlayerLooper: AVPlayerLooper?
  
  fileprivate var videoView: UIView?
  fileprivate var photoView: UIImageView?
  
  fileprivate var thumbnailObject: FoodieMedia?
  fileprivate var mediaObject: FoodieMedia!

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
    var momentObj: FoodieMoment

    // reuse moment for edits
    if(editMomentObj != nil) {
      momentObj = editMomentObj!
    } else {
      momentObj = FoodieMoment(foodieMedia: mediaObject) // viewDidLoad should have resolved the issue with mediaObj == nil by now)
    }

    momentObj.set(location: mediaLocation)
    momentObj.playSound = soundOn

    momentObj.clearMarkups()
    // Serialize the Jot Markup into Foodie Markups
    if let jotDictionary = jotViewController.serialize() {

      if let jotLabels = jotDictionary[kLabels] as? [NSDictionary] {
        var index = 1
        for jotLabel in jotLabels {
          CCLog.verbose("Jot Label #\(index) serialized")
          
          let markup = FoodieMarkup()
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
        
        let markup = FoodieMarkup()
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

    // Keep in mind there are 2 scenarios here. 
    // 1. We are working on the Current Draft Story
    // 2. We are editing on some random Story
    
    // Implementing Scenario 1 for now. Scenario TBD
    // What this is trying to do is to display a selection dialog on whether to add to the Current Story, or Save to a new one
    if let story = FoodieStory.currentStory {
      if(addToExistingStoryOnly) {
        // skip the selection of adding to current or not
        self.cleanupAndReturn(markedUpMoments: [momentObj], suggestedStory: story)
      }
      else {
        StorySelector.displayStorySelection(
          to: self,
          newStoryHandler: { UIAlertAction -> Void in

            StorySelector.showStoryDiscardDialog(to: self) {
              FoodieStory.cleanUpDraft() { error in
                if let error = error  {
                  AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
                    CCLog.assert("Error when cleaning up story draft- \(error.localizedDescription)")
                  }
                }
                self.cleanupAndReturn(markedUpMoments: [momentObj], suggestedStory: FoodieStory.newCurrent())
              }
            }
        },
          addToCurrentHandler: { UIAlertAction -> Void in self.cleanupAndReturn(markedUpMoments: [momentObj], suggestedStory: story) }
        )
      }
    }
    else {
      // Just return a new Current Story
      self.cleanupAndReturn(markedUpMoments: [momentObj], suggestedStory: FoodieStory.newCurrent())
    }
    
    // TODO: - Scenario 2 - We are editing an existing Story, not the Current Draft Story
  }

  
  // MARK - Public Instance Functions
  func cleanupAndReturn(markedUpMoments: [FoodieMoment], suggestedStory: FoodieStory ){
    // Stop if there might be video looping
    self.avPlayer?.pause()  // TODO: - Do we need to free the avPlayer memory or something?
    
    // Returned Markedup-Moment back to Presenting View Controller
    guard let delegate = self.markupReturnDelegate else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("Unexpected. markupReturnDelegate became nil. Unable to proceed")
    }
    delegate.markupComplete(markedupMoments: markedUpMoments, suggestedStory: suggestedStory)
  }

  // MARK: - Private Instance Functions
  private func displayJotMarkups()
  {
    guard let moment = editMomentObj else {
      // if you just take a picture with the camera there will be no editMomentObj for sure
      return
    }

    if let markups = moment.markups {
      var jotDictionary = [AnyHashable: Any]()
      var labelDictionary: [NSDictionary]?

      for markup in markups {

        if !markup.isDataAvailable {
          AlertDialog.present(from: self, title: "TastryApp", message: "Error displaying media. Please try again") { action in
            CCLog.fatal("Markup not available even tho Moment deemed Loaded")
          }
        }

        guard let dataType = markup.dataType else {
          AlertDialog.present(from: self, title: "TastryApp", message: "Error displaying media. Please try again") { action in
            CCLog.assert("Unexpected markup.dataType = nil")
          }
          return
        }

        guard let markupType = FoodieMarkup.dataTypes(rawValue: dataType) else {
          AlertDialog.present(from: self, title: "TastryApp", message: "Error displaying media. Please try again") { action in
            CCLog.assert("markup.dataType did not actually translate into valid type")
          }
          return
        }

        switch markupType {

        case .jotLabel:
          guard let labelData = markup.data else {
            AlertDialog.present(from: self, title: "TastryApp", message: "Error displaying media. Please try again") { action in
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
            AlertDialog.present(from: self, title: "TastryApp", message: "Error displaying media. Please try again") { action in
              CCLog.assert("Unexpected markup.data = nil when dataType == .jotDrawView")
            }
            return
          }

          jotDictionary[kDrawView] = drawViewDictionary
        }
      }

      jotDictionary[kLabels] = labelDictionary
      jotViewController.unserialize(jotDictionary)
    }
  }

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
      let alertController = UIAlertController(title: "TastryApp",
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
      let alertController = UIAlertController(title: "TastryApp",
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
      let alertController = UIAlertController(title: "TastryApp",
                                              titleComment: "Alert diaglogue title when Markup Image view has problem saving",
                                              message: "Error saving Story. Please try again",
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
      let alertController = UIAlertController(title: "TastryApp",
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
    jotViewController.setupRatioForAspectFit(onWindowWidth: UIScreen.main.fixedCoordinateSpace.bounds.width,
                                             andHeight: UIScreen.main.fixedCoordinateSpace.bounds.height)

    addChildViewController(jotViewController)
    view.addSubview(jotViewController.view)
    view.sendSubview(toBack: jotViewController.view)
    jotViewController.didMove(toParentViewController: self)
    jotViewController.view.frame = view.bounds

    // load up jotdata 
    displayJotMarkups()
    
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
      
      imageView.contentMode = .scaleAspectFill
      imageView.image = UIImage(data: imageBuffer)
      view.addSubview(imageView)
      view.sendSubview(toBack: imageView)
      
    // Loop the video
    } else if mediaType == .video {
      
      // Make sure the Sound button is shown
      soundButton.isHidden = false
      
      guard let videoURL = (mediaObject.videoExportPlayer?.avPlayer?.currentItem?.asset as? AVURLAsset)?.url else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.fatal("Cannot get at AVURLAsset.url")
        }
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

  override func viewWillDisappear(_ animated: Bool) {
    view.endEditing(true)  // Force clear the keyboard
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
