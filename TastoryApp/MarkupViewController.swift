//
//  MarkupViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-03-26.
//  Copyright © 2017 Tastory. All rights reserved.
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
import ColorSlider

protocol MarkupReturnDelegate: class {
  func markupComplete(markedupMoments: [FoodieMoment], suggestedStory: FoodieStory?)
}


class MarkupViewController: OverlayViewController {
  
  // MARK: - Constants
  
  struct Constants {
    static let SizeSliderMaxFont: CGFloat = 64.0
    static let SizeSliderMinFont: CGFloat = 10.0
    static let SizeSliderDefaultFont: CGFloat = 36.0
  }
  
  
  
  // MARK: - Public Static Variables
  
  static let FontChoiceArray: [String] = [
    "Noteworthy-Bold",
    "Futura-Medium",  // The 2nd in the list is actually is the first font
    "BodoniSvtyTwoOSITCTT-Bold"  //"BodoniSvtyTwoOSITCTT-Book"
  ]
  
  
  
  // MARK: - Public Instance Variables
  
  weak var markupReturnDelegate: MarkupReturnDelegate?
  var editMomentObj: FoodieMoment?
  var mediaObj: FoodieMedia?
  var mediaLocation: CLLocation?
  var addToExistingStoryOnly = false

  
  
  // MARK: - Private Instance Variables
  private var isInitialLayout = true
  
  private let jotViewController = JotViewController()
  
  private var avPlayer: AVQueuePlayer?
  private var avPlayerLooper: AVPlayerLooper?
  private var avPlayerLayer: AVPlayerLayer?
  
  private var thumbnailObject: FoodieMedia?

  private var colorSlider: ColorSlider!
  private var sizeSlider: Slider!
  
  private var soundOn = true
  private var fontArrayIndex = 0
  
  
  
  // MARK: - IBOutlets
  
  @IBOutlet weak var mediaView: UIView!
  @IBOutlet weak var exitButton: UIButton!
  @IBOutlet weak var backButton: UIButton!
  @IBOutlet weak var textButton: UIButton!
  @IBOutlet weak var drawButton: UIButton!
  @IBOutlet weak var deleteButton: UIButton!
  @IBOutlet weak var alignButton: UIButton!
  @IBOutlet weak var backgroundButton: UIButton!
  @IBOutlet weak var fontButton: UIButton!
  @IBOutlet weak var drawingIcon: UIButton!
  @IBOutlet weak var undoButton: UIButton!
  
  @IBOutlet weak var fontLargeIcon: UIButton!
  @IBOutlet weak var strokeLargeIcon: UIButton!
  @IBOutlet weak var fontSmallIcon: UIButton!
  @IBOutlet weak var strokeSmallIcon: UIButton!

  @IBOutlet weak var soundOnButton: UIButton!
  @IBOutlet weak var soundOffButton: UIButton!
  @IBOutlet weak var nextButton: UIButton!
  
  
  
  // MARK: - IBActions
  
  @IBAction func exitButtonAction(_ sender: UIButton) {
    dismiss(animated: true, completion: nil)  // This is okay as long as we never present this as part of any Navigation Controllers
  }
  
  
  @IBAction func backButtonAction(_ sender: UIButton) {
    view.endEditing(true)
    jotViewController.state = .text
    textModeMinimumUI()  // Setting the state to .text doesn't always trigger the delegate...
  }
  
  
  @IBAction func alignButtonAction(_ sender: UIButton) {
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
  
  
  @IBAction func backgroundButtonAction(_ sender: UIButton) {
    var whiteValue = jotViewController.whiteValue
    var alphaValue = jotViewController.alphaValue
    
    //jotViewController.state = .text
    
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
  
  
  @IBAction func fontButtonAction(_ sender: UIButton) {
    jotViewController.font = getNextFont(size: jotViewController.fontSize)
    CCLog.verbose("New Font Selected: \(jotViewController.font.fontName)")
  }
  
  
  
  @IBAction func textButtonAction(_ sender: UIButton) {
    jotViewController.state = .editingText
    //textEditModeMinimumUI()  // This will always trigger the delegate, so updating UI in the delegate only instead
  }

  
  @IBAction func drawButtonAction(_ sender: UIButton) {
    view.endEditing(true)
    jotViewController.state = .drawing
    drawModeMinimumUI()  // Must call this here. drawBegan only pertains to actually drawing, not the draw mode
  }
  
  
  @IBAction func undoButtonAction(_ sender: UIButton) {
    jotViewController.undoDrawing()
    if !jotViewController.canUndoDrawing() {
      undoButton.isHidden = true
    }
  }
  
  
  @IBAction func deleteButtonAction(_ sender: UIButton) {
    jotViewController.deleteSelectedLabel()
    
    // See if need
    if jotViewController.labelIsSelected() {
      deleteButton.isHidden = false
    } else {
      deleteButton.isHidden = true
    }
  }
  
  
  @IBAction func soundOnButtonAction(_ sender: UIButton) {
    soundOnButton.isHidden = true
    soundOn = true
    avPlayer?.volume = 1.0
    soundOffButton.isHidden = false
  }
  
  
  @IBAction func soundOffButtonAction(_ sender: UIButton) {
    soundOffButton.isHidden = true
    soundOn = false
    avPlayer?.volume = 0.0
    soundOnButton.isHidden = false
  }
  

  @IBAction func nextButtonAction(_ sender: UIButton) {
    
    guard let mediaObj = mediaObj else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
        CCLog.assert("Unexpected, mediaObj == nil ")
        self.dismiss(animated: true, completion: nil)
      }
      return
    }
    
    // TODO: Don't let user click save (Gray it out until Thumbnail creation completed)
    
    // Initializing with Media Object also initialize foodieFileName and mediaType
    var momentObj: FoodieMoment

    // reuse moment for edits
    if(editMomentObj != nil) {
      momentObj = editMomentObj!
    } else {
      momentObj = FoodieMoment(foodieMedia: mediaObj) // viewDidLoad should have resolved the issue with mediaObj == nil by now)
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
        ConfirmationDialog.displayStorySelection(
          to: self,
          newStoryHandler: { UIAlertAction -> Void in

            ConfirmationDialog.showStoryDiscardDialog(to: self) {
              FoodieStory.cleanUpDraft() { error in
                if let error = error  {
                  AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                    CCLog.assert("Error when cleaning up story draft- \(error.localizedDescription)")
                  }
                  return
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


  
  // MARK: - Private Instance Functions
  
  @objc private func colorSliderChanged(_ slider: ColorSlider) {
    view.endEditing(true)
    jotViewController.drawingColor = slider.color
    jotViewController.textColor = slider.color
  }
  
  
  @objc private func sizeSliderChanged(_ slider: Slider) {
    view.endEditing(true)

    let fontSize = (1-slider.progress)*(Constants.SizeSliderMaxFont-Constants.SizeSliderMinFont)+Constants.SizeSliderMinFont
    jotViewController.fontSize = fontSize
    jotViewController.drawingStrokeWidth = fontSize/2
  }
  
  
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
          AlertDialog.present(from: self, title: "Tastory", message: "Error displaying media. Please try again") { _ in
            CCLog.fatal("Markup not available even tho Moment deemed Loaded")
          }
        }

        guard let dataType = markup.dataType else {
          AlertDialog.present(from: self, title: "Tastory", message: "Error displaying media. Please try again") { _ in
            CCLog.assert("Unexpected markup.dataType = nil")
          }
          return
        }

        guard let markupType = FoodieMarkup.dataTypes(rawValue: dataType) else {
          AlertDialog.present(from: self, title: "Tastory", message: "Error displaying media. Please try again") { _ in
            CCLog.assert("markup.dataType did not actually translate into valid type")
          }
          return
        }

        switch markupType {

        case .jotLabel:
          guard let labelData = markup.data else {
            AlertDialog.present(from: self, title: "Tastory", message: "Error displaying media. Please try again") { _ in
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
            AlertDialog.present(from: self, title: "Tastory", message: "Error displaying media. Please try again") { _ in
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

  
  private func cleanupAndReturn(markedUpMoments: [FoodieMoment], suggestedStory: FoodieStory ){
    // Stop if there might be video looping
    self.avPlayer?.pause()  // TODO: - Do we need to free the avPlayer memory or something?
    
    // Returned Markedup-Moment back to Presenting View Controller
    guard let delegate = self.markupReturnDelegate else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal)
      CCLog.fatal("Unexpected. markupReturnDelegate became nil. Unable to proceed")
    }
    delegate.markupComplete(markedupMoments: markedUpMoments, suggestedStory: suggestedStory)
  }
  
  
  private func getNextFont(size: CGFloat) -> UIFont {
    fontArrayIndex += 1
    if fontArrayIndex >= MarkupViewController.FontChoiceArray.count { fontArrayIndex = 0 }
    
    if let newFont = UIFont(name: MarkupViewController.FontChoiceArray[fontArrayIndex], size: size) {
      return newFont
    } else {
      CCLog.assert("Getting font for font array index \(fontArrayIndex) failed")
      return UIFont.boldSystemFont(ofSize: size)
    }
  }
  
  
  private func textModeMinimumUI() {
    exitButton.isHidden = false
    backButton.isHidden = true
    alignButton.isHidden = true
    backgroundButton.isHidden = true
    fontButton.isHidden = true
    drawingIcon.isHidden = true
    undoButton.isHidden = true
    textButton.isHidden = false
    drawButton.isHidden = false
    nextButton.isHidden = false
    
    fontLargeIcon.isHidden = true
    fontSmallIcon.isHidden = true
    strokeLargeIcon.isHidden = true
    strokeSmallIcon.isHidden = true
    colorSlider.isHidden = true
    sizeSlider.isHidden = true
    
    if jotViewController.labelIsSelected() {
      deleteButton.isHidden = false
    } else {
      deleteButton.isHidden = true
    }
  }
  
  
  private func textEditModeMinimumUI() {
    exitButton.isHidden = true
    backButton.isHidden = false
    alignButton.isHidden = false
    backgroundButton.isHidden = false
    fontButton.isHidden = false
    drawingIcon.isHidden = true
    undoButton.isHidden = true
    textButton.isHidden = true
    drawButton.isHidden = true
    deleteButton.isHidden = true
    nextButton.isHidden = true
    
    strokeLargeIcon.isHidden = true
    strokeSmallIcon.isHidden = true
    fontLargeIcon.isHidden = false
    fontSmallIcon.isHidden = false
    colorSlider.isHidden = false
    sizeSlider.isHidden = false
  }
  
  
  private func drawModeMinimumUI() {
    exitButton.isHidden = true
    backButton.isHidden = false
    alignButton.isHidden = true
    backgroundButton.isHidden = true
    fontButton.isHidden = true
    drawingIcon.isHidden = false
    textButton.isHidden = true
    drawButton.isHidden = true
    deleteButton.isHidden = true
    nextButton.isHidden = true
    
    fontLargeIcon.isHidden = true
    fontSmallIcon.isHidden = true
    strokeLargeIcon.isHidden = false
    strokeSmallIcon.isHidden = false
    colorSlider.isHidden = false
    sizeSlider.isHidden = false
    
    if jotViewController.canUndoDrawing() {
      undoButton.isHidden = false
    } else {
      undoButton.isHidden = true
    }
  }
  
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.accessibilityIdentifier = "markupView"

    // Initialize Media
    guard let mediaObj = mediaObj else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
        CCLog.assert("Unexpected, mediaObj == nil ")
        self.dismiss(animated: true, completion: nil)
      }
      return
    }
    
    // Create AV Objects if Video
    guard let mediaType = mediaObj.mediaType else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("Unexpected, mediaType == nil")
      }
      return
    }
    
    if mediaType == .video {
      guard let videoUrl = mediaObj.localVideoUrl else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
          CCLog.assert("mediaObj.videoUrl = nil")
          self.dismiss(animated: true, completion: nil)
        }
        return
      }
      
      let avPlayerItem = AVPlayerItem(url: videoUrl)
      avPlayer = AVQueuePlayer()
      avPlayer!.allowsExternalPlayback = false
      avPlayerLooper = AVPlayerLooper(player: avPlayer!, templateItem: avPlayerItem)
      avPlayerLayer = AVPlayerLayer(player: avPlayer)
    }
    
    // JotViewController Display Parameters Setup
    jotViewController.state = JotViewState.text
    jotViewController.fitOriginalFontSizeToViewWidth = true
    jotViewController.view.backgroundColor = .clear
    
    // JotViewController Markup Setup
    jotViewController.delegate = self
    jotViewController.textAlignment = .center
    jotViewController.textColor = UIColor.white
    jotViewController.font = getNextFont(size: CGFloat(Constants.SizeSliderDefaultFont))
    jotViewController.fontSize = CGFloat(Constants.SizeSliderDefaultFont)
    jotViewController.drawingStrokeWidth = CGFloat(Constants.SizeSliderDefaultFont)/2
    jotViewController.drawingColor = UIColor.white
    jotViewController.whiteValue = 0.0
    jotViewController.alphaValue = 0.0
    
    addChildViewController(jotViewController)
    mediaView.addSubview(jotViewController.view)
    jotViewController.didMove(toParentViewController: self)
    
    // Initialize Sliders
    colorSlider = ColorSlider(orientation: .vertical, previewSide: .left)
    colorSlider.addTarget(self, action: #selector(colorSliderChanged(_:)), for: .valueChanged)
    colorSlider.color = .white
    
    view.addSubview(colorSlider)
    view.bringSubview(toFront: colorSlider)
    
    colorSlider.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      colorSlider.topAnchor.constraint(equalTo: mediaView.topAnchor, constant: 35.0),
      colorSlider.centerXAnchor.constraint(equalTo: mediaView.trailingAnchor, constant: -30.0),
      colorSlider.widthAnchor.constraint(equalToConstant: 15.0),
      colorSlider.heightAnchor.constraint(equalToConstant: 140.0),
    ])
    
    let initialProgress = 1 - (Constants.SizeSliderDefaultFont/(Constants.SizeSliderMaxFont - Constants.SizeSliderMinFont))
    sizeSlider = Slider(orientation: .vertical, initialProgress: initialProgress)
    sizeSlider.addTarget(self, action: #selector(sizeSliderChanged(_:)), for: .valueChanged)
    
    view.addSubview(sizeSlider)
    view.bringSubview(toFront: sizeSlider)
    
    sizeSlider.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      sizeSlider.topAnchor.constraint(equalTo: mediaView.topAnchor, constant: 233.0),
      sizeSlider.centerXAnchor.constraint(equalTo: mediaView.trailingAnchor, constant: -30.0),
      sizeSlider.widthAnchor.constraint(equalToConstant: 15.0),
      sizeSlider.heightAnchor.constraint(equalToConstant: 50.0),
    ])
  }
  
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    if isInitialLayout {
      isInitialLayout = false
      
      guard let mediaObj = mediaObj else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
          CCLog.assert("Unexpected, mediaObj == nil ")
          self.dismiss(animated: true, completion: nil)
        }
        return
      }
      
      // Update Frame for JotVC based on Autolayout results
      jotViewController.view.frame = mediaView.bounds
      jotViewController.textEditingInsets = UIEdgeInsetsMake(65, 45, 65, 45)
      jotViewController.initialTextInsets = UIEdgeInsetsMake(65, 45, 65, 45)
      jotViewController.setupRatioForAspectFit(onWindowWidth: UIScreen.main.fixedCoordinateSpace.bounds.width,
                                               andHeight: UIScreen.main.fixedCoordinateSpace.bounds.height)
      jotViewController.view.layoutIfNeeded()
      displayJotMarkups()
      
      // Setup the UI first - Assume text mode to start
      textModeMinimumUI()
      
      // Initialize the background Image or Video
      guard let mediaType = mediaObj.mediaType else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("Unexpected, mediaType == nil")
        }
        return
      }
      
      // Display the photo
      if mediaType == .photo {
        
        // Hide the Sound buttons
        soundOnButton.isHidden = true
        soundOffButton.isHidden = true
        
        guard let imageBuffer = mediaObj.imageMemoryBuffer else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
            CCLog.assert("Unexpected, mediaObj.imageMemoryBuffer == nil")
            self.dismiss(animated: true, completion: nil)
          }
          return
        }
        
        let imageView = UIImageView(frame: mediaView.bounds)
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(data: imageBuffer)
        mediaView.addSubview(imageView)
        mediaView.sendSubview(toBack: imageView)
        
      // Loop the video
      } else if mediaType == .video {
        
        // Make sure the Sound button is shown
        soundOnButton.isHidden = true
        soundOffButton.isHidden = false
        
        avPlayerLayer!.frame = mediaView.bounds
        let videoView = UIView(frame: mediaView.bounds)
        videoView.layer.addSublayer(avPlayerLayer!)
        mediaView.addSubview(videoView)
        mediaView.sendSubview(toBack: videoView)
        
        soundOn = true
        avPlayer!.volume = 1.0
        avPlayer!.play() // TODO: There is some lag with a blank white screen before video starts playing...
      
      // No Image nor Video to work on, Fatal
      } else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
          CCLog.assert("Both photoToMarkup and videoToMarkupURL are nil")
          self.dismiss(animated: true, completion: nil)
        }
        return
      }
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
    if isEditing {
      CCLog.verbose("JotViewController is Editing")
      textEditModeMinimumUI()
    } else {
      CCLog.verbose("JotViewController is not Editing")
      textModeMinimumUI()
    }
  }
  
  func drawingBegan() {
    CCLog.verbose("JotViewController began Drawing")
    undoButton.isHidden = false
  }
  
  func drawingEnded() {
    CCLog.verbose("JotViewController ended Drawing")
  }
  
  func jotViewController(_ jotViewController: JotViewController!, didSelectLabel labelInfo: [AnyHashable : Any]!) {
    if jotViewController.state == .text || jotViewController.state == .editingText {
      deleteButton.isHidden = false
//      backgroundButton.isHidden = false
//      alignButton.isHidden = false
//      fontButton.isHidden = false
    }
  }
}
