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

class StoryViewController: OverlayViewController {
  
  // MARK: - Constants
  struct Constants {
    static let MomentsViewingTimeInterval = 5.0
  }
  
  
  // MARK: - Public Instance Variables
  var draftPreview: Bool = false
  var viewingStory: FoodieStory?
  
  
  // MARK: - Private Instance Variables
  
  fileprivate let jotViewController = JotViewController()
  fileprivate var currentMoment: FoodieMoment?
  fileprivate var currentExportPlayer: AVExportPlayer?
  fileprivate var photoTimer: Timer?
  fileprivate var swipeUpGestureRecognizer: UISwipeGestureRecognizer!  // Set by ViewDidLoad
  fileprivate var avPlayerLayer: AVPlayerLayer!  // Set by ViewDidLoad
  fileprivate var activitySpinner: ActivitySpinner!  // Set by ViewDidLoad
  fileprivate var photoTimeRemaining: TimeInterval = 0.0
  fileprivate var soundOn: Bool = true
  fileprivate var isPaused: Bool = false
  
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var photoView: UIImageView!
  @IBOutlet weak var videoView: UIView!
  @IBOutlet weak var tapForwardGestureRecognizer: UIView!
  @IBOutlet weak var tapBackwardGestureRecognizer: UIView!
  @IBOutlet weak var venueButton: UIButton!
  @IBOutlet weak var authorButton: UIButton!
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
  
  
  @IBAction func venueAction(_ sender: UIButton) {
    CCLog.info("User tapped Venue")
    
    guard let story = viewingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.assert("Unexpected, viewingStory = nil")
      }
      return
    }

    if let venue = story.venue, let foursquareURLString = venue.foursquareURL, let foursquareURL = URL(string: foursquareURLString) {
      // Pause if playing
      if !isPaused {
        pausePlay()
      }

      CCLog.info("Opening Safari View for \(foursquareURLString)")
      let safariViewController = SFSafariViewController(url: foursquareURL)
      safariViewController.delegate = self
      safariViewController.modalPresentationStyle = .overFullScreen
      self.present(safariViewController, animated: true, completion: nil)
    }
  }
  
  
  @IBAction func authorAction(_ sender: UIButton) {
    CCLog.info("User tapped Author")
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
      guard let avPlayer = currentExportPlayer?.avPlayer else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
          CCLog.assert("No AVPlayer for StoryVC when trying to pause/reumse")
          self.navigationController?.popViewController(animated: true)
        }
        return
      }
      
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
  
  
  
  fileprivate func displayMoment(_ moment: FoodieMoment) {
    
    guard let media = moment.media else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("Unexpected, moment.media == nil ")
      }
      return
    }
    
    guard let mediaType = media.mediaType else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("Unexpected, mediaObject.mediaType == nil")
      }
      return
    }
    
    // Try to display the media as by type
    if mediaType == .photo {
      guard let imageBuffer = media.imageMemoryBuffer else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.assert("Unexpected, mediaObject.imageMemoryBuffer == nil")
          self.navigationController?.popViewController(animated: true)
        }
        return
      }
      
      // Display the Photo
      photoView.contentMode = .scaleAspectFill
      photoView.image = UIImage(data: imageBuffer)
      view.insertSubview(photoView, belowSubview: jotViewController.view)

      // UI Update - Really should group some of the common UI stuff into some sort of function?
      pauseResumeButton.isHidden = false
      venueButton.isHidden = false
      authorButton.isHidden = false
      activitySpinner.remove()
      
      // Create timer for advancing to the next media? // TODO: Should not be a fixed time
      photoTimer = Timer.scheduledTimer(withTimeInterval: Constants.MomentsViewingTimeInterval,
                                        repeats: false) { [weak self] timer in
        self?.displayNextMoment()
      }
      
    } else if mediaType == .video {
      guard let videoExportPlayer = media.videoExportPlayer, let avPlayer = videoExportPlayer.avPlayer else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
          CCLog.assert("MediaObject.videoExportPlayer == nil")
          self.navigationController?.popViewController(animated: true)
        }
        return
      }

      currentExportPlayer = videoExportPlayer
      videoExportPlayer.delegate = self
      avPlayerLayer.player = avPlayer
      view.insertSubview(videoView, belowSubview: jotViewController.view)
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
        
        if !markup.isRetrieved {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
            CCLog.fatal("Markup not available even tho Moment \(moment.getUniqueIdentifier()) deemed Loaded")
          }
          return
        }
        
        guard let dataType = markup.dataType else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.assert("Unexpected markup.dataType = nil")
            self.navigationController?.popViewController(animated: true)
          }
          return
        }
        
        guard let markupType = FoodieMarkup.dataTypes(rawValue: dataType) else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.assert("markup.dataType did not actually translate into valid type")
            self.navigationController?.popViewController(animated: true)
          }
          return
        }
        
        switch markupType {
          
        case .jotLabel:
          guard let labelData = markup.data else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
              CCLog.assert("Unexpected markup.data = nil when dataType == .jotLabel")
              self.navigationController?.popViewController(animated: true)
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
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
              CCLog.assert("Unexpected markup.data = nil when dataType == .jotDrawView")
              self.navigationController?.popViewController(animated: true)
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
  
  
  fileprivate func displayMomentIfLoaded(for moment: FoodieMoment) {
    guard let story = viewingStory else {
      CCLog.fatal("viewingStory = nil")
    }
    
    var shouldRetrieveMoment = false
    
    moment.execute(ifNotReady: {
      CCLog.debug("Moment \(moment.getUniqueIdentifier()) not yet loaded")
      shouldRetrieveMoment = true  // Don't execute the retrieve here. This is actually executed inside of a mutex
      
    }, whenReady: {
      CCLog.debug("Moment \(moment.getUniqueIdentifier()) ready to display")
      DispatchQueue.main.async {
        if let currentMoment = self.currentMoment, currentMoment == moment {
          self.displayMoment(moment)
        }
      }
    })
    
    if shouldRetrieveMoment {
      self.activitySpinner.apply(below: self.tapBackwardGestureRecognizer)
      if draftPreview {
        _ = moment.retrieveRecursive(from: .local, type: .draft, withCompletion: nil)
      } else {
        let momentOperation = StoryOperation(with: .moment, on: story, for: story.getIndexOf(moment), completion: nil)
        FoodieFetch.global.queue(momentOperation, at: .high)
      }
    } else {
      CCLog.info("Moment \(moment.getUniqueIdentifier()) displaying")
      self.displayMoment(moment)
    }
  }
  
  
  fileprivate func stopVideoTimerAndObservers(for moment: FoodieMoment) {
    pauseResumeButton.isHidden = true
    soundButton.isHidden = true
    venueButton.isHidden = true
    authorButton.isHidden = true
    resumeStateTrack()
    photoTimer?.invalidate()
    photoTimer = nil
    currentExportPlayer?.avPlayer?.pause()
    currentExportPlayer?.delegate = nil
    // avPlayerLayer.player = nil  // !!! Taking a risk here. So that video transitions will be a touch quicker
    currentExportPlayer?.layerDisconnected()
    currentExportPlayer = nil
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
  
  @objc private func swipeUp(_ sender: UISwipeGestureRecognizer) {
    CCLog.info("User swiped Up")
    
    guard let story = viewingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.assert("Unexpected, viewingStory = nil")
      }
      return
    }
    
    if let storyLinkString = story.storyURL, let storyLinkUrl = URL(string: URL.addHttpIfNeeded(to: storyLinkString)) {
      
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
  
  
  // Display the next Moment based on what the current Moment is
  @objc private func displayNextMoment() {
    
    guard let story = viewingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Unexpected, viewingStory = nil")
        self.navigationController?.popViewController(animated: true)
      }
      return
    }
    
    guard let moments = story.moments else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Unexpected, viewingStory.moments = nil")
        self.navigationController?.popViewController(animated: true)
      }
      return
    }
    
    guard let moment = currentMoment else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Unexpected, currentMoment = nil")
        self.navigationController?.popViewController(animated: true)
      }
      return
    }
    
    jotViewController.clearAll()
    stopVideoTimerAndObservers(for: moment)
    
    // Figure out what is the next moment and display it
    let nextIndex = story.getIndexOf(moment) + 1
    
    if nextIndex == moments.count {
      self.navigationController?.popViewController(animated: true)
    } else {
      currentMoment = moments[nextIndex]
      self.displayMomentIfLoaded(for: moments[nextIndex])
    }
  }
  
  
  // Display the previous Moment based on what the current Moment is
  func displayPreviousMoment() {
    
    guard let story = viewingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Unexpected, viewingStory = nil")
        self.navigationController?.popViewController(animated: true)
      }
      return
    }
    
    guard let moments = story.moments else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Unexpected, viewingStory.moments = nil")
        self.navigationController?.popViewController(animated: true)
      }
      return
    }
    
    guard let moment = currentMoment else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Unexpected, currentMoment = nil")
        self.navigationController?.popViewController(animated: true)
      }
      return
    }
    
    jotViewController.clearAll()
    stopVideoTimerAndObservers(for: moment)
    
    // Figure out what is the previous moment is and display it
    let index = story.getIndexOf(moment)
    
    if index == 0 {
      self.navigationController?.popViewController(animated: true)
    } else {
      currentMoment = moments[index-1]
      displayMomentIfLoaded(for: moments[index-1])
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    avPlayerLayer = AVPlayerLayer()
    avPlayerLayer.frame = videoView.bounds
    videoView.layer.addSublayer(avPlayerLayer)
    
    jotViewController.state = JotViewState.disabled
    jotViewController.setupRatioForAspectFit(onWindowWidth: UIScreen.main.fixedCoordinateSpace.bounds.width,
                                             andHeight: UIScreen.main.fixedCoordinateSpace.bounds.height)
    addChildViewController(jotViewController)
    
    view.addSubview(jotViewController.view)
    view.insertSubview(jotViewController.view, belowSubview: tapForwardGestureRecognizer)
    jotViewController.didMove(toParentViewController: self)
    
    guard let story = viewingStory else {
      CCLog.fatal("No Story when loading StoryViewController")
    }
    
    if let author = story.author, let username = author.username {
      authorButton.setTitle(username, for: .normal)
    } else {
      CCLog.warning("Cannot get at username from Story \(story.getUniqueIdentifier)")
      authorButton.isHidden = true
    }
    
    if let venue = story.venue, let venueName = venue.name {
      venueButton.setTitle(venueName, for: .normal)
    } else {
      CCLog.warning("Cannot get at venue name from Story \(story.getUniqueIdentifier)")
      venueButton.isHidden = true
    }
    
    activitySpinner = ActivitySpinner(addTo: view)
    
    swipeUpGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipeUp(_:)))
    swipeUpGestureRecognizer.direction = .up
    swipeUpGestureRecognizer.numberOfTouchesRequired = 1
    view.addGestureRecognizer(swipeUpGestureRecognizer)
    dragGestureRecognizer?.require(toFail: swipeUpGestureRecognizer)  // This is needed so that the Swipe down to dismiss from OverlayViewController will only have an effect if this is not a Swipe Up to Safari
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    jotViewController.view.frame = videoView.frame

    guard let story = viewingStory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Unexpected viewingStory = nil")
        self.navigationController?.popViewController(animated: true)
      }
      return
    }
    
    guard let moments = story.moments, !moments.isEmpty else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Unexpected viewingStory.moments = nil or empty")
        self.navigationController?.popViewController(animated: true)
      }
      return
    }
    
    // If a moment was already in play, just display that again. Otherwise try to display the first moment
    if currentMoment == nil {
      currentMoment = moments[0]
      soundButton.isHidden = true
      pauseResumeButton.isHidden = true
      venueButton.isHidden = true
      authorButton.isHidden = true
      displayMomentIfLoaded(for: currentMoment!)
    } else if isPaused {
      pausePlay()
    }
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    cleanUp()
    
    // Cancel All potential Prefetch associated with the Story before exiting
    if let story = viewingStory {
      FoodieFetch.global.cancel(for: story)
    } else {
      CCLog.assert("Expected a viewingStory even tho dismissing")
    }
  }
  
  
  override func topViewWillEnterForeground() {
    super.topViewWillEnterForeground()
    currentExportPlayer?.avPlayer?.play()
  }
  
  
  override var prefersStatusBarHidden: Bool {
    return true
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
    if let avExportPlayer = currentExportPlayer, let avPlayer = avExportPlayer.avPlayer {
      // So this is a playing video, should we turn on the sound? Sound button?
      avPlayer.volume = 0.0
      
      // Should we show the sound button?
      if currentMoment?.playSound ?? false {
        soundButton.isHidden = false
        if soundOn {
          avPlayer.volume = 1.0
        }
      } else {
        soundButton?.isHidden = true
      }
    }
    pauseResumeButton.isHidden = false
    venueButton.isHidden = false
    authorButton.isHidden = false
    activitySpinner.remove()
  }
  
  func avExportPlayer(isWaitingForData avExportPlayer: AVExportPlayer) {
    soundButton.isHidden = true
    pauseResumeButton.isHidden = true
    venueButton.isHidden = true
    authorButton.isHidden = true
    activitySpinner.apply(below: tapBackwardGestureRecognizer)
  }
  
  func avExportPlayer(completedPlaying avExportPlayer: AVExportPlayer) {
    displayNextMoment()
  }
}
