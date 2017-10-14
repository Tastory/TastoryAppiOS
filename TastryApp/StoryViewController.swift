//
//  StoryViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-04-23.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit
import AVFoundation
import SafariServices
import Jot

class StoryViewController: TransitableViewController {
  
  // MARK: - Constants
  struct Constants {
    static let MomentsToBufferAtATime = FoodieGlobal.Constants.MomentsToBufferAtATime
    static let MomentsViewingTimeInterval = 5.0
  }
  
  
  // MARK: - Public Instance Variables
  var viewingStory: FoodieStory? {
    didSet {
      fetchSomeMoment(from: 0)
    }
  }
  
  
  // MARK: - Private Instance Variables
  fileprivate let jotViewController = JotViewController()
  fileprivate var photoTimer: Timer?
  fileprivate var currentMoment: FoodieMoment?
  fileprivate var currentExportPlayer: AVExportPlayer?
  fileprivate var avPlayerLayer: AVPlayerLayer!
  fileprivate var activitySpinner: ActivitySpinner!  // Set by ViewDidLoad
  fileprivate var soundOn: Bool = true
  fileprivate var isPaused: Bool = false
  fileprivate var photoTimeRemaining: TimeInterval = 0.0
  
  
  // Generic error dialog box to the user on internal errors
  func internalErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "TastryApp",
                                              titleComment: "Alert diaglogue title when a Story View internal error occured",
                                              message: "An internal error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Story View internal error occured",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for generic StoryView errors",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  // Generic error dialog box to the user when displaying photo or video
  fileprivate func displayErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "TastryApp",
                                              titleComment: "Alert diaglogue title when Story View has problem displaying photo or video",
                                              message: "Error displaying media. Please try again",
                                              messageComment: "Alert dialog message when Story View has problem displaying photo or video",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for error when displaying photo or video in StoryView",
                                     style: .default)
      
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var photoView: UIImageView!
  @IBOutlet weak var videoView: UIView!
  @IBOutlet weak var swipeUpGestureRecognizer: UISwipeGestureRecognizer!
  @IBOutlet weak var tapGestureStackView: UIStackView!
  @IBOutlet weak var tapBackwardsWidth: NSLayoutConstraint!
  @IBOutlet weak var soundButton: UIButton!
  @IBOutlet weak var pauseResumeButton: UIButton!
  
  
  // MARK: - IBActions
  @IBAction func tapForward(_ sender: UITapGestureRecognizer) {
    CCLog.info("User tapped Forward")
    displayNextMoment()
  }

  @IBAction func tapBackward(_ sender: UITapGestureRecognizer) {
    CCLog.info("User tapped Backward")
    displayPreviousMoment()
  }
  
  @IBAction func swipeUp(_ sender: UISwipeGestureRecognizer) {
    CCLog.info("User swiped Up")
    
    guard let story = viewingStory else {
      internalErrorDialog()
      CCLog.assert("Unexpected, viewingStory = nil")
      return
    }
    
    if let storyLinkString = story.storyURL, let storyLinkUrl = URL(string: storyLinkString) {
      
      // Pause if playing
      if !isPaused {
        pausePlay()
      }
      
      CCLog.info("Opening Safari View for \(storyLinkString)")
      let safariViewController = SFSafariViewController(url: storyLinkUrl)
      safariViewController.delegate = self
      safariViewController.modalPresentationStyle = .overFullScreen
      self.present(safariViewController, animated: true, completion: nil)
    }
  }
  
  
  @IBAction func pausePlayToggle(_ sender: UIButton) {
    pausePlay()
  }
  
  
  @IBAction func soundToggle(_ sender: UIButton) {
    
    guard let playingMoment = currentMoment else {
      // Not playing any moment, Sound button should do nothing and just return
      return
    }
    
    guard let avPlayer = currentExportPlayer?.avPlayer else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Expected AVExportPlayer")
      }
      return
    }
    
    soundOn = !soundOn
    
    if playingMoment.playSound && soundOn {
      avPlayer.volume = 1.0
    } else {
      avPlayer.volume = 0.0
    }
  }
  
  
  // MARK: - Private Instance Functions
  
  fileprivate func pausePlay() {
    guard let currentMoment = currentMoment, let mediaObject = currentMoment.mediaObj, let mediaType = mediaObject.mediaType else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.assert("No Current Moment, Media Object, or Media Type for StoryVC when trying to pause/reumse")
        self.dismiss(animated: true, completion: nil)
      }
      return
    }
    
    guard let avPlayer = currentExportPlayer?.avPlayer else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Expected AVExportPlayer")
      }
      return
    }
    
    CCLog.info("User pressed Paused/Resume. isPaused = \(isPaused), photoTimer.isValid = \(photoTimer != nil ? String(photoTimer!.isValid) : "None"), avPlayer.rate = \(avPlayer.rate), mediaType = \(mediaType)")
    
    if let photoTimer = photoTimer {
      
      if photoTimer.isValid {
        // Photo is 'playing'. Pause photo timer
        photoTimeRemaining = photoTimer.fireDate.timeIntervalSinceNow
        photoTimer.invalidate()
        pauseStateTrack()
        
      } else {
        // Photo is 'paused'. Restart photo timer from where left off
        self.photoTimer = Timer.scheduledTimer(withTimeInterval: photoTimeRemaining,
                                               repeats: false) { [weak self] timer in
                                                self?.displayNextMoment()
        }
        resumeStateTrack()
      }
    } else {
      
      if avPlayer.rate != 0.0 {
        // Video is playing. Pause the video
        avPlayer.pause()
        pauseStateTrack()
        
      } else {
        // Video is paused. Restarted the video
        avPlayer.play()
        resumeStateTrack()
      }
    }
  }
  
  
  fileprivate func fetchSomeMoment(from momentNumber: Int) {
    guard let story = viewingStory else {
      CCLog.fatal("Unexpected, no Story being viewed by Story View Controller")
    }
    
    guard let moments = story.moments else {
      internalErrorDialog()
      CCLog.assert("Unexpected, storymoments = nil")
      return
    }
    
    // Start pre-fetching if Moment array is not empty
    if !moments.isEmpty {
      story.contentRetrievalRequest(fromMoment: momentNumber, forUpTo: Constants.MomentsToBufferAtATime)
    }
  }
  
  
  fileprivate func displayMoment(_ moment: FoodieMoment) {
    
    guard let mediaObject = moment.mediaObj else {
      internalErrorDialog()
      CCLog.assert("Unexpected, moment.mediaObj == nil ")
      return
    }
    
    guard let mediaType = mediaObject.mediaType else {
      internalErrorDialog()
      CCLog.assert("Unexpected, mediaObject.mediaType == nil")
      return
    }
    
    // Keep track of what moment we are displaying
    currentMoment = moment
    
    // Remove Blue Layer and Activity Indicator
    activitySpinner.remove()
    
    // Try to display the media as by type
    if mediaType == .photo {

      guard let imageBuffer = mediaObject.imageMemoryBuffer else {
        displayErrorDialog()
        CCLog.assert("Unexpected, mediaObject.imageMemoryBuffer == nil")
        return
      }
      
      photoView.contentMode = .scaleAspectFill
      photoView.image = UIImage(data: imageBuffer)
      view.insertSubview(photoView, belowSubview: jotViewController.view)

      // Hide the sound button
      soundButton?.isHidden = true
      
      // Create timer for advancing to the next media? // TODO: Should not be a fixed time
      photoTimer = Timer.scheduledTimer(withTimeInterval: Constants.MomentsViewingTimeInterval,
                                        repeats: false) { [weak self] timer in
        self?.displayNextMoment()
      }
      
    } else if mediaType == .video {
      
      guard let videoExportPlayer = mediaObject.videoExportPlayer, let avPlayer = videoExportPlayer.avPlayer else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
          CCLog.assert("MediaObject.videoExportPlayer == nil")
        }
        return
      }

      currentExportPlayer = videoExportPlayer
      videoExportPlayer.delegate = self
      avPlayerLayer.player = avPlayer
      view.insertSubview(videoView, belowSubview: jotViewController.view)
      activitySpinner.apply(below: tapGestureStackView)
      
      // Should we play sound? Should the sound button be visible?
      avPlayer.volume = 0.0
      
      // Should we show the sound button?
      if moment.playSound {
        soundButton?.isHidden = false
        
        if soundOn {
          avPlayer.volume = 1.0
        }
      } else {
        soundButton?.isHidden = true
      }
      
      // Finally, let's play the Media
      avPlayer.play()
      
      // No image nor video to work on, Fatal
    } else {
      CCLog.fatal("MediaType neither .photo nor .video")
    }
    
    // See if there are any Markups to Unserialize
    if let markups = moment.markups {
      var jotDictionary = [AnyHashable: Any]()
      var labelDictionary: [NSDictionary]?
      
      for markup in markups {
        
        if !markup.isDataAvailable {
          displayErrorDialog()
          CCLog.fatal("Markup not available even tho Moment deemed Loaded")
        }
        
        guard let dataType = markup.dataType else {
          displayErrorDialog()
          CCLog.assert("Unexpected markup.dataType = nil")
          return
        }
        
        guard let markupType = FoodieMarkup.dataTypes(rawValue: dataType) else {
          displayErrorDialog()
          CCLog.assert("markup.dataType did not actually translate into valid type")
          return
        }
        
        switch markupType {
          
        case .jotLabel:
          guard let labelData = markup.data else {
            displayErrorDialog()
            CCLog.assert("Unexpected markup.data = nil when dataType == .jotLabel")
            return
          }
          
          if labelDictionary == nil {
            labelDictionary = [labelData]
          } else {
            labelDictionary!.append(labelData)
          }
          
        case .jotDrawView:
          guard let drawViewDictionary = markup.data else {
            displayErrorDialog()
            CCLog.assert("Unexpected markup.data = nil when dataType == .jotDrawView")
            return
          }
          
          jotDictionary[kDrawView] = drawViewDictionary
        }
      }
      
      jotDictionary[kLabels] = labelDictionary
      jotViewController.unserialize(jotDictionary)
      
      pauseResumeButton.isHidden = false
    }
  }
  
  
  fileprivate func displayMomentIfLoaded(for moment: FoodieMoment) {
    
    guard let story = viewingStory else {
      CCLog.fatal("Unexpected, no Story being viewed by Story View Controller")
    }
    
    let momentIndex = story.getIndexOf(moment)
    
    // Fetch this and a few more moments regardless
    fetchSomeMoment(from: momentIndex)
    
    if moment.foodieObject.checkRetrieved(ifFalseSetDelegate: self) {
      if moment.foodieObject.retrieveState == .objectSynced {
        DispatchQueue.main.async { [weak self] in self?.displayMoment(moment) }
      } else {
        // Seems moment is not available. Move on to the next one
        CCLog.warning("displayMomentIfLoaded moment.checkRetrieved returned operationState != .objectSynced. Skipping moment index = \(momentIndex)")
        currentMoment = moment
        displayNextMoment()
      }
    } else {
      CCLog.verbose("displayMomentIfLoaded: Not yet loaded")
      activitySpinner.apply(below: tapGestureStackView)
      soundButton.isHidden = true
    }
  }
  
  
  fileprivate func stopVideoTimerAndObservers(for moment: FoodieMoment) {
    pauseResumeButton.isHidden = true
    resumeStateTrack()
    photoTimer?.invalidate()
    photoTimer = nil
    currentExportPlayer?.avPlayer?.pause()
    currentExportPlayer?.delegate = nil
    avPlayerLayer.player = nil
    currentExportPlayer?.layerDisconnected()
  }
  
  
  fileprivate func cleanUp() {
    // TODO: Clean-up before dismissing
    if let moment = currentMoment {
      stopVideoTimerAndObservers(for: moment)
    }
    jotViewController.clearAll()
  }
  
  
  fileprivate func pauseStateTrack() {
    isPaused = true
  }
  
  
  fileprivate func resumeStateTrack() {
    isPaused = false
  }
  
  
  
  // MARK: - Public Instance Functions
  
  // Display the next Moment based on what the current Moment is
  @objc func displayNextMoment() {
    
    guard let story = viewingStory else {
      internalErrorDialog()
      CCLog.assert("Unexpected, viewingStory = nil")
      return
    }
    
    guard let moments = story.moments else {
      internalErrorDialog()
      CCLog.assert("Unexpected, viewingStory.moments = nil")
      return
    }
    
    guard let moment = currentMoment else {
      internalErrorDialog()
      CCLog.assert("Unexpected, currentMoment = nil")
      return
    }
    
    jotViewController.clearAll()
    stopVideoTimerAndObservers(for: moment)
    
    // Figure out what is the next moment and display it
    let nextIndex = story.getIndexOf(moment) + 1
    
    if nextIndex == moments.count {
      dismiss(animated: true, completion: nil)
    } else {
      displayMomentIfLoaded(for: moments[nextIndex])
    }
  }
  
  
  // Display the previous Moment based on what the current Moment is
  func displayPreviousMoment() {
    
    guard let story = viewingStory else {
      internalErrorDialog()
      CCLog.assert("Unexpected, viewingStory = nil")
      return
    }
    
    guard let moments = story.moments else {
      internalErrorDialog()
      CCLog.assert("Unexpected, viewingStory.moments = nil")
      return
    }
    
    guard let moment = currentMoment else {
      internalErrorDialog()
      CCLog.assert("Unexpected, currentMoment = nil")
      return
    }
    
    jotViewController.clearAll()
    stopVideoTimerAndObservers(for: moment)
    
    // Figure out what is the previous moment is and display it
    let index = story.getIndexOf(moment)
    
    if index == 0 {
      dismiss(animated: true, completion: nil)
    } else {
      displayMomentIfLoaded(for: moments[index-1])
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    avPlayerLayer = AVPlayerLayer()
    avPlayerLayer.frame = self.view.bounds
    videoView!.layer.addSublayer(avPlayerLayer)
    
    jotViewController.state = JotViewState.disabled
    jotViewController.setupRatioForAspectFit(onWindowWidth: UIScreen.main.fixedCoordinateSpace.bounds.width,
                                             andHeight: UIScreen.main.fixedCoordinateSpace.bounds.height)
    addChildViewController(jotViewController)
    view.addSubview(jotViewController.view)
    view.insertSubview(jotViewController.view, belowSubview: tapGestureStackView)
    jotViewController.didMove(toParentViewController: self)
    jotViewController.view.frame = view.bounds
    
    activitySpinner = ActivitySpinner(addTo: view)
    
    dragGestureRecognizer?.require(toFail: swipeUpGestureRecognizer)
    tapBackwardsWidth.constant = UIScreen.main.bounds.width/3.0  // Gotta test this on a different screen size to know if this works
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard let story = viewingStory else {
      internalErrorDialog()
      CCLog.assert("Unexpected viewingStory = nil")
      return
    }
    
    guard let moments = story.moments, !moments.isEmpty else {
      internalErrorDialog()
      CCLog.assert("Unexpected viewingStory.moments = nil or empty")
      return
    }
    
    // If a moment was already in play, just display that again. Otherwise try to display the first moment
    if currentMoment == nil {
      
      // Always display activity indicator and blur layer up front
      
      activitySpinner.apply(below: tapGestureStackView)
      soundButton.isHidden = true
      pauseResumeButton.isHidden = true
      
      currentMoment = moments[0]
      displayMomentIfLoaded(for: currentMoment!)
    } else if isPaused {
      pausePlay()
    }
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    cleanUp()
  }
  
  
  override func topViewWillEnterForeground() {
    super.topViewWillEnterForeground()
    currentExportPlayer?.avPlayer?.play()
  }
}


// MARK: - Foodie Moment Wait On Content Delegate Conformance
extension StoryViewController: FoodieObjectWaitOnRetrieveDelegate {
  
  func retrieved(for object: FoodieObjectDelegate) {
    guard let moment = object as? FoodieMoment else {
      internalErrorDialog()
      CCLog.assert("JouranlViewController retrieved() for object is not FoodieMoment")
      return
    }
    DispatchQueue.main.async { [weak self] in self?.displayMoment(moment) }
  }
}


// MARK: - Safari View Controller Did Finish Delegate Conformance
extension StoryViewController: SFSafariViewControllerDelegate {
  
  func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
    if isPaused {
      pausePlay()
    }
  }
}


// MARK: - AVPlayAndExportDelegate Conformance
extension StoryViewController: AVPlayAndExportDelegate {
 
  func avExportPlayer(isLikelyToKeepUp avExportPlayer: AVExportPlayer) {
    activitySpinner.remove()
  }
  
  func avExportPlayer(isWaitingForData avExportPlayer: AVExportPlayer) {
    activitySpinner.apply(below: tapGestureStackView)
  }
  
  func avExportPlayer(completedPlaying avExportPlayer: AVExportPlayer) {
    displayNextMoment()
  }
}
