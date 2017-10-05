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

class StoryViewController: UIViewController {
  
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
  fileprivate var avPlayer: AVPlayer?
  fileprivate var avPlayerLayer: AVPlayerLayer?
  fileprivate var avPlayerItem: AVPlayerItem?
  fileprivate var photoTimer: Timer?
  fileprivate var currentMoment: FoodieMoment?
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
  @IBOutlet weak var blurView: UIVisualEffectView!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
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
  
  @IBAction func swipeDown(_ sender: UISwipeGestureRecognizer) {
    CCLog.info("User swiped Down")
    cleanUpAndDismiss()
  }
  
  @IBAction func swipeUp(_ sender: UISwipeGestureRecognizer) {
    CCLog.info("User swiped Up")
    
    guard let story = viewingStory else {
      internalErrorDialog()
      CCLog.assert("Unexpected, viewingStory = nil")
      return
    }
    
    if let storyLinkString = story.storyURL, let storyLinkUrl = URL(string: storyLinkString) {
      
      guard let moment = currentMoment else {
        internalErrorDialog()
        CCLog.assert("Unexpected currentMoment = nil")
        return
      }
      
      // Stop video if a video is playing. Remove Timers & Observers
      avPlayer!.pause()
      stopVideoTimerAndObservers(for: moment)
      
      let safariViewController = SFSafariViewController(url: storyLinkUrl)
      safariViewController.delegate = self
      
      let transition = CATransition()
      transition.duration = 0.5
      transition.type = kCATransitionPush
      transition.subtype = kCATransitionFromTop
      view.window!.layer.add(transition, forKey: kCATransition)
      
      self.present(safariViewController, animated: false, completion: nil)
    }
  }
  
  @IBAction func pausePlayToggle(_ sender: UIButton) {
    
    guard let currentMoment = currentMoment, let mediaObject = currentMoment.mediaObj, let mediaType = mediaObject.mediaType else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.assert("No Current Moment, Media Object, or Media Type for StoryVC when trying to pause/reumse")
        self.cleanUpAndDismiss()
      }
      return
    }
    
    CCLog.info("User pressed Paused/Resume. isPaused = \(isPaused), photoTimer.isValid = \(photoTimer != nil ? String(photoTimer!.isValid) : "None"), avPlayer.rate = \(avPlayer!.rate), mediaType = \(mediaType)")
    
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
      
      if avPlayer!.rate != 0.0 {
        // Video is playing. Pause the video
        avPlayer!.pause()
        pauseStateTrack()
      
      } else {
        // Video is paused. Restarted the video
        avPlayer!.play()
        resumeStateTrack()
      }
    }
    
    
  }
  
  
  @IBAction func soundToggle(_ sender: UIButton) {
    
    guard let playingMoment = currentMoment else {
      // Not playing any moment, Sound button should do nothing and just return
      return
    }
    soundOn = !soundOn
    
    if playingMoment.playSound && soundOn {
      avPlayer?.volume = 1.0
    } else {
      avPlayer?.volume = 0.0
    }
  }
  
  
  // MARK: - Private Instance Functions
  
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
    view.sendSubview(toBack: activityIndicator)
    view.sendSubview(toBack: blurView)
    activityIndicator.stopAnimating()
    
    // Try to display the media as by type
    if mediaType == .photo {

      guard let imageBuffer = mediaObject.imageMemoryBuffer else {
        displayErrorDialog()
        CCLog.assert("Unexpected, mediaObject.imageMemoryBuffer == nil")
        return
      }
      
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
      
      guard let videoURL = mediaObject.videoLocalBufferUrl else {
        displayErrorDialog()
        CCLog.assert("Unexpected, mediaObject.videoLocalBufferUrl == nil")
        return
      }
      
      CCLog.verbose("Playing Video with URL: \(videoURL)")
      
      avPlayerItem = AVPlayerItem(url: videoURL)
      
      // Put a hook in for what to do next after video completes playing
      NotificationCenter.default.addObserver(self,
                                             selector: #selector(displayNextMoment),
                                             name: .AVPlayerItemDidPlayToEndTime,
                                             object: avPlayerItem)
      
      avPlayer!.replaceCurrentItem(with: avPlayerItem)
      view.insertSubview(videoView, belowSubview: jotViewController.view)
      
      // Should we play sound? Should the sound button be visible?
      avPlayer!.volume = 0.0
      
      // Should we show the sound button?
      if moment.playSound {
        soundButton?.isHidden = false
        
        if soundOn {
          avPlayer!.volume = 1.0
        }
      } else {
        soundButton?.isHidden = true
      }
      
      // Finally, let's play the Media
      avPlayer!.play()
      
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
      
      view.insertSubview(blurView, belowSubview: tapGestureStackView)
      view.insertSubview(activityIndicator, belowSubview: tapGestureStackView)
      soundButton.isHidden = true
      activityIndicator.startAnimating()
    }
  }
  
  
  fileprivate func stopVideoTimerAndObservers(for moment: FoodieMoment) {
    pauseResumeButton.isHidden = true
    avPlayer?.pause()
    photoTimer?.invalidate()
    photoTimer = nil
    resumeStateTrack()
    NotificationCenter.default.removeObserver(self)
  }
  
  
  fileprivate func cleanUpAndDismiss() {
    // TODO: Clean-up before dismissing
    if let moment = currentMoment {
      stopVideoTimerAndObservers(for: moment)
    }
    jotViewController.clearAll()
    DispatchQueue.main.async { [weak self] in self?.dismiss(animated: true, completion: nil) }
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
      cleanUpAndDismiss()
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
      cleanUpAndDismiss()
    } else {
      displayMomentIfLoaded(for: moments[index-1])
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    avPlayer = AVPlayer()
    avPlayer?.allowsExternalPlayback = false
    avPlayerLayer = AVPlayerLayer(player: avPlayer)
    avPlayerLayer!.frame = self.view.bounds
    videoView!.layer.addSublayer(avPlayerLayer!)
    
    // This section setups the JotViewController with default initial values
    jotViewController.state = JotViewState.disabled
    jotViewController.setupRatioForAspectFit(onWindowWidth: UIScreen.main.fixedCoordinateSpace.bounds.width,
                                             andHeight: UIScreen.main.fixedCoordinateSpace.bounds.height)
//    jotViewController.delegate = self
//    jotViewController.textColor = UIColor.black
//    jotViewController.font = UIFont.boldSystemFont(ofSize: 64.0)
//    jotViewController.fontSize = 64.0
//    jotViewController.textEditingInsets = UIEdgeInsetsMake(12.0, 6.0, 0.0, 6.0)  // Constraint from JotDemo causes conflicts
//    jotViewController.initialTextInsets = UIEdgeInsetsMake(6.0, 6.0, 6.0, 6.0)  // Constraint from JotDemo causes conflicts
//    jotViewController.fitOriginalFontSizeToViewWidth = true
//    jotViewController.textAlignment = .left
//    jotViewController.drawingColor = UIColor.cyan
    
    addChildViewController(jotViewController)
    view.addSubview(jotViewController.view)
    view.insertSubview(jotViewController.view, belowSubview: tapGestureStackView)
    jotViewController.didMove(toParentViewController: self)
    jotViewController.view.frame = view.bounds
    
    tapBackwardsWidth.constant = UIScreen.main.bounds.width/3.0  // Gotta test this on a different screen size to know if this works
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    // Always display activity indicator and blur layer up front
    view.insertSubview(blurView, belowSubview: tapGestureStackView)
    view.insertSubview(activityIndicator, belowSubview: tapGestureStackView)
    soundButton.isHidden = true
    pauseResumeButton.isHidden = true
    activityIndicator.startAnimating()
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
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
      currentMoment = moments[0]
    }
    
    displayMomentIfLoaded(for: currentMoment!)
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    CCLog.verbose("StoryViewController disappearing")
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("didReceiveMemoryWarning")
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
    let transition = CATransition()
    transition.duration = 0.5
    transition.type = kCATransitionPush
    transition.subtype = kCATransitionFromBottom
    controller.view.window!.layer.add(transition, forKey: kCATransition)
  }
}
